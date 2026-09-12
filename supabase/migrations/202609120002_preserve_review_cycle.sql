create or replace function public.preserve_review_cycle(
  target_review_cycle_id uuid
)
returns table (
  review_cycle_id uuid,
  review_cycle_status text,
  confirmed_judgment_id uuid,
  decision_id uuid
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  cycle_status text;
  proposer_actor uuid;
  reviewer_actor uuid;
  decision_maker_actor uuid;
  confirmed_judgment uuid;
  target_proposal_version uuid;
  target_decision public.decisions%rowtype;
  decision_event_count integer;
  decision_audit_count integer;
  preservation_correlation uuid;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  select
    rc.status,
    p.proposer_actor_id,
    rc.reviewer_actor_id,
    rc.decision_maker_actor_id,
    rc.confirmed_judgment_id,
    rc.proposal_version_id
  into
    cycle_status,
    proposer_actor,
    reviewer_actor,
    decision_maker_actor,
    confirmed_judgment,
    target_proposal_version
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

  if current_actor <> proposer_actor
     and current_actor <> reviewer_actor
     and current_actor <> decision_maker_actor then
    raise exception 'Actor is not authorized to preserve this review cycle';
  end if;

  if cycle_status = 'preserved_complete' then
    select *
    into target_decision
    from public.decisions d
    where d.review_cycle_id = target_review_cycle_id;

    return query
    select
      target_review_cycle_id,
      'preserved_complete'::text,
      confirmed_judgment,
      target_decision.id;

    return;
  end if;

  if cycle_status <> 'decided' then
    raise exception 'Review cycle must be decided before preservation';
  end if;

  if confirmed_judgment is null then
    raise exception 'Confirmed Judgment is required for preservation';
  end if;

  if not exists (
    select 1
    from public.judgments j
    where j.id = confirmed_judgment
  ) then
    raise exception 'Confirmed Judgment record not found';
  end if;

  select *
  into target_decision
  from public.decisions d
  where d.review_cycle_id = target_review_cycle_id;

  if not found then
    raise exception 'Consequential decision is required for preservation';
  end if;

  if target_decision.confirmed_judgment_id <> confirmed_judgment then
    raise exception 'Decision is not linked to the confirmed Judgment';
  end if;

  if decision_maker_actor is null then
    raise exception 'Authorized decision-maker is required for preservation';
  end if;

  if target_decision.actor_id <> decision_maker_actor then
    raise exception 'Decision actor does not match the assigned decision-maker';
  end if;

  if not exists (
    select 1
    from public.proposal_versions pv
    where pv.id = target_proposal_version
  ) then
    raise exception 'Proposal version is required for preservation';
  end if;

  select count(*)
  into decision_event_count
  from public.judgment_events je
  where je.judgment_id = confirmed_judgment
    and je.event_type = 'decision'
    and je.actor = target_decision.actor_id
    and je.payload ->> 'decision_id' = target_decision.id::text
    and je.payload ->> 'review_cycle_id' = target_review_cycle_id::text
    and je.payload ->> 'proposal_version_id' = target_proposal_version::text
    and je.payload ->> 'correlation_id' = target_decision.correlation_id::text;

  if decision_event_count <> 1 then
    raise exception 'Exactly one matching semantic decision event is required for preservation';
  end if;

  select count(*)
  into decision_audit_count
  from public.workflow_audit wa
  where wa.review_cycle_id = target_review_cycle_id
    and wa.action = 'consequential_decision_recorded'
    and wa.actor_id = target_decision.actor_id
    and wa.from_state = 'human_confirmed'
    and wa.to_state = 'decided'
    and wa.correlation_id = target_decision.correlation_id;

  if decision_audit_count <> 1 then
    raise exception 'Exactly one matching consequential decision audit record is required for preservation';
  end if;

  preservation_correlation := gen_random_uuid();

  update public.review_cycles
  set
    status = 'preserved_complete',
    updated_at = now()
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
    'review_cycle_preserved',
    'decided',
    'preserved_complete',
    'Preservation integrity gate',
    preservation_correlation,
    target_decision.id
  );

  return query
  select
    target_review_cycle_id,
    'preserved_complete'::text,
    confirmed_judgment,
    target_decision.id;
end;
$$;

revoke execute on function public.preserve_review_cycle(uuid)
from public, anon;

grant execute on function public.preserve_review_cycle(uuid)
to authenticated;

alter function public.preserve_review_cycle(uuid)
owner to postgres;

