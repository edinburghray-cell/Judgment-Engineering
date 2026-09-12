alter table public.judgment_events
drop constraint if exists judgment_events_event_type_check;

alter table public.judgment_events
add constraint judgment_events_event_type_check
check (
  event_type = any (
    array[
      'approval'::text,
      'implementation'::text,
      'evidence_added'::text,
      'assumption_failed'::text,
      'challenge'::text,
      'retrospective'::text,
      'context_discovered'::text,
      'human_confirmed'::text,
      'decision'::text
    ]
  )
);

create or replace function public.record_review_decision(
  target_review_cycle_id uuid,
  target_decision text,
  target_authority_basis text,
  target_rationale text,
  target_residual_risks text,
  target_correlation_id uuid,
  target_causation_id uuid default null
)
returns table (
  decision_id uuid,
  review_cycle_id uuid,
  decision text,
  decision_actor uuid,
  decision_status text,
  correlation_id uuid
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  current_status text;
  current_judgment_id uuid;
  assigned_decision_maker uuid;
  target_proposal_version_id uuid;
  existing_decision public.decisions%rowtype;
  new_decision_id uuid;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  if target_decision not in ('approve', 'reject', 'defer') then
    raise exception 'Invalid decision';
  end if;

  if nullif(trim(target_authority_basis), '') is null then
    raise exception 'Authority basis is required';
  end if;

  if target_correlation_id is null then
    raise exception 'Correlation ID is required';
  end if;

  select
    rc.status,
    rc.confirmed_judgment_id,
    rc.decision_maker_actor_id,
    rc.proposal_version_id
  into
    current_status,
    current_judgment_id,
    assigned_decision_maker,
    target_proposal_version_id
  from public.review_cycles rc
  where rc.id = target_review_cycle_id
  for update;

  if not found then
    raise exception 'Review cycle not found';
  end if;

  if current_status <> 'human_confirmed' then
    raise exception 'Review cycle is not ready for consequential decision';
  end if;

  if current_judgment_id is null then
    raise exception 'Human-confirmed Judgment is required before decision';
  end if;

  if assigned_decision_maker is null then
    raise exception 'An authorized decision-maker must be assigned before decision';
  end if;

  if assigned_decision_maker <> current_actor then
    raise exception 'Only the assigned decision-maker can record the consequential decision';
  end if;

  select *
  into existing_decision
  from public.decisions d
  where d.review_cycle_id = target_review_cycle_id;

  if found then
    if existing_decision.correlation_id = target_correlation_id then
      return query
      select
        existing_decision.id,
        existing_decision.review_cycle_id,
        existing_decision.decision,
        existing_decision.actor_id,
        'decided'::text,
        existing_decision.correlation_id;

      return;
    end if;

    raise exception 'Review cycle already has a consequential decision';
  end if;

  insert into public.decisions (
    review_cycle_id,
    decision,
    actor_id,
    authority_basis,
    decided_at,
    rationale,
    residual_risks,
    correlation_id,
    causation_id,
    confirmed_judgment_id
  )
  values (
    target_review_cycle_id,
    target_decision,
    current_actor,
    target_authority_basis,
    now(),
    target_rationale,
    target_residual_risks,
    target_correlation_id,
    target_causation_id,
    current_judgment_id
  )
  returning id into new_decision_id;

  insert into public.judgment_events (
    judgment_id,
    event_type,
    actor,
    description,
    payload
  )
  values (
    current_judgment_id,
    'decision',
    current_actor,
    'Consequential decision recorded against the confirmed Judgment.',
    jsonb_build_object(
      'decision_id', new_decision_id,
      'review_cycle_id', target_review_cycle_id,
      'proposal_version_id', target_proposal_version_id,
      'decision', target_decision,
      'authority_basis', target_authority_basis,
      'rationale', target_rationale,
      'residual_risks', target_residual_risks,
      'correlation_id', target_correlation_id,
      'causation_id', target_causation_id
    )
  );

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
    'consequential_decision_recorded',
    'human_confirmed',
    'decided',
    target_authority_basis,
    target_correlation_id,
    target_causation_id
  );

  update public.review_cycles
  set
    status = 'decided',
    updated_at = now()
  where id = target_review_cycle_id;

  return query
  select
    new_decision_id,
    target_review_cycle_id,
    target_decision,
    current_actor,
    'decided'::text,
    target_correlation_id;
end;
$$;

revoke execute on function public.record_review_decision(
  uuid,
  text,
  text,
  text,
  text,
  uuid,
  uuid
) from public, anon;

grant execute on function public.record_review_decision(
  uuid,
  text,
  text,
  text,
  text,
  uuid,
  uuid
) to authenticated;

alter function public.record_review_decision(
  uuid,
  text,
  text,
  text,
  text,
  uuid,
  uuid
) owner to postgres;
