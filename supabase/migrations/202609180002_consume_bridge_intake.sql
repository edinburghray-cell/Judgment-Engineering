create or replace function public.consume_bridge_intake(
  target_bridge_intake_id uuid,
  target_proposal_id uuid,
  target_proposal_version_id uuid,
  target_review_cycle_id uuid
)
returns public.bridge_intakes
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  consumed public.bridge_intakes;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  update public.bridge_intakes
  set
    status = 'consumed',
    proposal_id = target_proposal_id,
    proposal_version_id = target_proposal_version_id,
    review_cycle_id = target_review_cycle_id,
    consumed_by_actor_id = current_actor,
    consumed_at = now()
  where id = target_bridge_intake_id
    and status = 'claimed'
    and claimed_by_actor_id = current_actor
  returning * into consumed;

  if consumed.id is null then
    raise exception 'Bridge intake unavailable for consumption';
  end if;

  return consumed;
end;
$$;

revoke execute on function public.consume_bridge_intake(uuid, uuid, uuid, uuid)
from public, anon;

grant execute on function public.consume_bridge_intake(uuid, uuid, uuid, uuid)
to authenticated;

alter function public.consume_bridge_intake(uuid, uuid, uuid, uuid)
owner to postgres;
