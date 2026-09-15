drop function if exists public.confirm_review_cycle_judgment(uuid, text);
alter table public.judgments
  add column if not exists reconsideration_conditions text;

drop function if exists public.confirm_review_cycle_judgment(uuid, text);

create or replace function public.confirm_review_cycle_judgment(
  target_review_cycle_id uuid,
  target_reconsideration_conditions text,
  target_predecessor_judgment_id uuid default null
)
returns table (
  review_cycle_id uuid,
  judgment_id uuid,
  review_cycle_status text,
  judgment_draft_status text,
  confirmed_by_actor_id uuid,
  confirmed_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  cycle_status text;
  assigned_reviewer uuid;
  draft_id uuid;
  draft_status text;
  existing_judgment_id uuid;
  existing_confirmed_by_actor uuid;
  existing_confirmed_at timestamptz;
  new_judgment_id uuid;
  confirmation_time timestamptz;
  confirmation_correlation uuid;
  confirmation_causation uuid;
  draft_row public.judgment_drafts%rowtype;
  predecessor_exists boolean;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  if nullif(trim(target_reconsideration_conditions), '') is null then
    raise exception 'Reconsideration conditions are required';
  end if;

  if target_predecessor_judgment_id is not null then
    select exists (
      select 1
      from public.judgments
      where id = target_predecessor_judgment_id
    )
    into predecessor_exists;

    if not predecessor_exists then
      raise exception 'Predecessor Judgment not found';
    end if;
  end if;

  select
    rc.status,
    rc.reviewer_actor_id,
    rc.judgment_draft_id,
    rc.confirmed_judgment_id,
    rc.confirmed_by_actor_id,
    rc.confirmed_at
  into
    cycle_status,
    assigned_reviewer,
    draft_id,
    existing_judgment_id,
    existing_confirmed_by_actor,
    existing_confirmed_at
  from public.review_cycles rc
  where rc.id = target_review_cycle_id
  for update;

  if not found then
    raise exception 'Review cycle not found';
  end if;

  if assigned_reviewer is null then
    raise exception 'A reviewer must be assigned before confirmation';
  end if;

  if assigned_reviewer <> current_actor then
    raise exception 'Only the assigned reviewer can confirm the Judgment';
  end if;

  if cycle_status = 'human_confirmed'
     and existing_judgment_id is not null then
    return query
    select
      target_review_cycle_id,
      existing_judgment_id,
      'human_confirmed'::text,
      'human_confirmed'::text,
      existing_confirmed_by_actor,
      existing_confirmed_at;
    return;
  end if;

  if cycle_status <> 'structured_unconfirmed' then
    raise exception 'Judgment can only be confirmed from structured_unconfirmed';
  end if;

  if draft_id is null then
    raise exception 'A structured Judgment Draft is required before confirmation';
  end if;

  select *
  into draft_row
  from public.judgment_drafts jd
  where jd.id = draft_id
  for update;

  if not found then
    raise exception 'Judgment Draft not found';
  end if;

  draft_status := draft_row.status;

  if draft_status <> 'structured_unconfirmed' then
    raise exception 'Judgment Draft must be structured_unconfirmed before confirmation';
  end if;

  new_judgment_id := gen_random_uuid();
  confirmation_time := now();
  confirmation_correlation := gen_random_uuid();
  confirmation_causation := draft_id;

  insert into public.judgments (
    id,
    title,
    situation,
    problem,
    options,
    rationale,
    assumptions,
    evidence,
    accepted_risks,
    success_metrics,
    chosen_option,
    rejected_options,
    decision_owner,
    capture_actor,
    committing_actor,
    authority_context,
    committed_at,
    predecessor_judgment_id,
    reconsideration_conditions
  )
  values (
    new_judgment_id,
    draft_row.title,
    draft_row.situation,
    draft_row.problem,
    draft_row.options,
    draft_row.rationale,
    draft_row.assumptions,
    draft_row.evidence,
    draft_row.accepted_risks,
    draft_row.success_metrics,
    draft_row.chosen_option,
    draft_row.rejected_options,
    draft_row.decision_owner,
    draft_row.capture_actor,
    current_actor,
    'Reviewer confirmation for Review Cycle ' || target_review_cycle_id::text,
    confirmation_time,
    target_predecessor_judgment_id,
    trim(target_reconsideration_conditions)
  );

  insert into public.judgment_events (
    judgment_id,
    event_type,
    actor,
    description,
    payload
  )
  values (
    new_judgment_id,
    'human_confirmed',
    current_actor,
    'Judgment confirmed by the assigned reviewer.',
    jsonb_build_object(
      'review_cycle_id', target_review_cycle_id,
      'judgment_draft_id', draft_id,
      'correlation_id', confirmation_correlation,
      'causation_id', confirmation_causation
    )
  );

  update public.judgment_drafts
  set
    status = 'human_confirmed',
    updated_at = confirmation_time
  where id = draft_id;

  update public.review_cycles
  set
    status = 'human_confirmed',
    confirmed_judgment_id = new_judgment_id,
    confirmed_by_actor_id = current_actor,
    confirmed_at = confirmation_time,
    updated_at = confirmation_time
  where id = target_review_cycle_id;

  insert into public.workflow_audit (
    review_cycle_id,
    actor_id,
    action,
    from_state,
    to_state,
    authority_basis,
    correlation_id,
    causation_id
  )
  values (
    target_review_cycle_id,
    current_actor,
    'judgment_confirmed',
    'structured_unconfirmed',
    'human_confirmed',
    'Assigned Reviewer confirmation authority',
    confirmation_correlation,
    confirmation_causation
  );

  return query
  select
    target_review_cycle_id,
    new_judgment_id,
    'human_confirmed'::text,
    'human_confirmed'::text,
    current_actor,
    confirmation_time;
end;
$$;

revoke execute on function public.confirm_review_cycle_judgment(uuid, text, uuid)
from public, anon;

grant execute on function public.confirm_review_cycle_judgment(uuid, text, uuid)
to authenticated;

alter function public.confirm_review_cycle_judgment(uuid, text, uuid)
owner to postgres;



