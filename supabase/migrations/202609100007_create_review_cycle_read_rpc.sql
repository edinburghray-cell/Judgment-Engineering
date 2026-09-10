create or replace function public.get_review_cycle(
  target_review_cycle_id uuid
)
returns table (
  review_cycle_id uuid,
  review_cycle_status text,
  proposal_id uuid,
  proposal_version_id uuid,
  version_number integer,
  proposer_actor_id uuid,
  reviewer_actor_id uuid,
  change_id text,
  scope text,
  affected_system text,
  environment text,
  assumptions text,
  alternatives jsonb,
  evidence jsonb,
  known_risks text,
  confirmed_judgment_id uuid
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  return query
  select
    rc.id,
    rc.status,
    p.id,
    pv.id,
    pv.version_number,
    p.proposer_actor_id,
    rc.reviewer_actor_id,
    pv.change_id,
    pv.scope,
    pv.affected_system,
    pv.environment,
    pv.assumptions,
    pv.alternatives,
    pv.evidence,
    pv.known_risks,
    rc.confirmed_judgment_id
  from public.review_cycles rc
  join public.proposal_versions pv
    on pv.id = rc.proposal_version_id
  join public.proposals p
    on p.id = pv.proposal_id
  where rc.id = target_review_cycle_id
    and (
      p.proposer_actor_id = current_actor
      or rc.reviewer_actor_id = current_actor
    );
end;
$$;

revoke execute on function public.get_review_cycle(uuid)
from public, anon;

grant execute on function public.get_review_cycle(uuid)
to authenticated;

alter function public.get_review_cycle(uuid) owner to postgres;
