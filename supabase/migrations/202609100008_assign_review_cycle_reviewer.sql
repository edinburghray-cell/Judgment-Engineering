create or replace function public.assign_review_cycle_reviewer(
  target_review_cycle_id uuid,
  target_reviewer_actor_id uuid
)
returns table (
  review_cycle_id uuid,
  reviewer_actor_id uuid,
  review_cycle_status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  proposer_actor uuid;
  current_status text;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  if target_reviewer_actor_id is null then
    raise exception 'Reviewer is required';
  end if;

  select
    p.proposer_actor_id,
    rc.status
  into
    proposer_actor,
    current_status
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

  if proposer_actor <> current_actor then
    raise exception 'Only the proposer can assign the reviewer';
  end if;

  if current_status <> 'reviewable' then
    raise exception 'Reviewer can only be assigned while the review cycle is reviewable';
  end if;

  if not exists (
    select 1
    from auth.users
    where id = target_reviewer_actor_id
  ) then
    raise exception 'Reviewer actor not found';
  end if;

  update public.review_cycles
  set
    reviewer_actor_id = target_reviewer_actor_id,
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
    'reviewer_assigned',
    current_status,
    current_status,
    'Proposer assignment authority',
    gen_random_uuid()
  );

  return query
  select
    rc.id,
    rc.reviewer_actor_id,
    rc.status
  from public.review_cycles rc
  where rc.id = target_review_cycle_id;
end;
$$;

revoke execute on function public.assign_review_cycle_reviewer(uuid, uuid)
from public, anon;

grant execute on function public.assign_review_cycle_reviewer(uuid, uuid)
to authenticated;

alter function public.assign_review_cycle_reviewer(uuid, uuid)
owner to postgres;
