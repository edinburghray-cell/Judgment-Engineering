create or replace function public.initiate_transfer_attempt(
  target_attempt_id uuid,
  target_judgment_unit_id uuid,
  target_treatment text,
  target_what_changed text
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
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  if target_treatment not in ('apply', 'adapt', 'reject') then
    raise exception 'Invalid transfer treatment';
  end if;

  if not exists (
    select 1
    from public.judgment_unit_access jua
    where jua.actor_id = current_actor
      and jua.judgment_unit_id = target_judgment_unit_id
      and jua.can_transfer = true
  ) then
    raise exception 'Transfer not authorized for this Judgment Unit';
  end if;

  insert into public.transfer_attempts (
    id,
    actor_id,
    source_judgment_unit_id,
    treatment,
    what_changed,
    status
  )
  values (
    target_attempt_id,
    current_actor,
    target_judgment_unit_id,
    target_treatment,
    nullif(target_what_changed, ''),
    'initiated'
  );

  return query
  select
    target_attempt_id,
    'initiated'::text;
end;
$$;

revoke execute on function public.initiate_transfer_attempt(uuid, uuid, text, text)
from public, anon;

grant execute on function public.initiate_transfer_attempt(uuid, uuid, text, text)
to authenticated;

alter function public.initiate_transfer_attempt(uuid, uuid, text, text) owner to postgres;
