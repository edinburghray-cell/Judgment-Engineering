create or replace function public.claim_transfer_attempt(
  target_attempt_id uuid
)
returns table (
  attempt_id uuid,
  attempt_status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  current_status text;
  source_judgment_unit uuid;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  select
    ta.status,
    ta.source_judgment_unit_id
  into
    current_status,
    source_judgment_unit
  from public.transfer_attempts ta
  where ta.id = target_attempt_id
    and ta.actor_id = current_actor
  for update;

  if not found then
    raise exception 'Transfer attempt not found or not owned by authenticated actor';
  end if;

  if not exists (
    select 1
    from public.judgment_unit_access jua
    where jua.actor_id = current_actor
      and jua.judgment_unit_id = source_judgment_unit
      and jua.can_transfer = true
  ) then
    raise exception 'Transfer not authorized for this Judgment Unit';
  end if;

  if current_status = 'initiated' then
    update public.transfer_attempts
    set
      status = 'processing',
      updated_at = now()
    where id = target_attempt_id;

    current_status := 'processing';
  end if;

  return query
  select
    target_attempt_id,
    current_status;
end;
$$;

revoke execute on function public.claim_transfer_attempt(uuid)
from public, anon;

grant execute on function public.claim_transfer_attempt(uuid)
to authenticated;


alter function public.claim_transfer_attempt(uuid) owner to postgres;
