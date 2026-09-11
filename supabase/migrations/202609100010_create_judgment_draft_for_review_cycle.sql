create or replace function public.create_judgment_draft_for_review_cycle(
  target_review_cycle_id uuid
)
returns table (
  review_cycle_id uuid,
  judgment_draft_id uuid,
  review_cycle_status text,
  judgment_draft_status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  proposer_actor uuid;
  current_status text;
  existing_draft_id uuid;
  new_draft_id uuid;
  proposal_title text;
  proposal_scope text;
  proposal_affected_system text;
  proposal_environment text;
  proposal_assumptions text;
  proposal_alternatives jsonb;
  proposal_evidence jsonb;
  proposal_known_risks text;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  select
    p.proposer_actor_id,
    rc.status,
    pv.change_id,
    pv.scope,
    pv.affected_system,
    pv.environment,
    pv.assumptions,
    pv.alternatives,
    pv.evidence,
    pv.known_risks
  into
    proposer_actor,
    current_status,
    proposal_title,
    proposal_scope,
    proposal_affected_system,
    proposal_environment,
    proposal_assumptions,
    proposal_alternatives,
    proposal_evidence,
    proposal_known_risks
  from public.review_cycles rc
  join public.proposal_versions pv
    on pv.id = rc.proposal_version_id
  join public.proposals p
    on p.id = pv.proposal_id
  where rc.id = target_review_cycle_id
  for update;

  if not found then
    raise exception 'Review cycle not found';
  end if;

  if proposer_actor <> current_actor
     and not exists (
       select 1
       from public.review_cycles
       where id = target_review_cycle_id
         and reviewer_actor_id = current_actor
     ) then
    raise exception 'Only the proposer or assigned reviewer can structure this review cycle';
  end if;

  if current_status <> 'reviewable' then
    raise exception 'Judgment draft can only be created from a reviewable cycle';
  end if;

  select jd.id
  into existing_draft_id
  from public.judgment_drafts jd
  where jd.authority_context = 'Review Cycle ' || target_review_cycle_id::text
  limit 1;

  if existing_draft_id is not null then
    raise exception 'Judgment draft already exists for this review cycle';
  end if;

  insert into public.judgment_drafts (
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
    authority_context,
    status
  )
  values (
    proposal_title,
    'Proposed change to ' || proposal_affected_system ||
      ' in ' || proposal_environment || ' environment.',
    proposal_scope,
    proposal_alternatives,
    null,
    proposal_assumptions,
    proposal_evidence,
    proposal_known_risks,
    null,
    null,
    '[]'::jsonb,
    null,
    current_actor,
    'Review Cycle ' || target_review_cycle_id::text,
    'structured_unconfirmed'
  )
  returning id into new_draft_id;

  update public.review_cycles
  set
    status = 'structured_unconfirmed',
    updated_at = now()
  where id = target_review_cycle_id;

  insert into public.workflow_audit (
    review_cycle_id,
    actor_id,
    action,
    from_state,
    to_state,
    authority_basis,
    correlation_id
  )
  values (
    target_review_cycle_id,
    current_actor,
    'judgment_structured',
    current_status,
    'structured_unconfirmed',
    'Authorized workflow participant',
    gen_random_uuid()
  );

  return query
  select
    target_review_cycle_id,
    new_draft_id,
    'structured_unconfirmed'::text,
    'structured_unconfirmed'::text;
end;
$$;

revoke execute on function public.create_judgment_draft_for_review_cycle(uuid)
from public, anon;

grant execute on function public.create_judgment_draft_for_review_cycle(uuid)
to authenticated;

alter function public.create_judgment_draft_for_review_cycle(uuid)
owner to postgres;
