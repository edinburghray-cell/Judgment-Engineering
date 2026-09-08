create or replace function public.complete_transfer_attempt(
  target_attempt_id uuid
)
returns table (
  attempt_id uuid,
  attempt_status text,
  transfer_id uuid
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  current_status text;
  source_judgment_unit uuid;
  attempt_treatment text;
  attempt_what_changed text;
  existing_transfer uuid;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  select
    ta.status,
    ta.source_judgment_unit_id,
    ta.treatment,
    ta.what_changed,
    ta.result_transfer_id
  into
    current_status,
    source_judgment_unit,
    attempt_treatment,
    attempt_what_changed,
    existing_transfer
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

  if current_status = 'completed' then
    return query
    select
      target_attempt_id,
      current_status,
      existing_transfer;

    return;
  end if;

  if current_status <> 'processing' then
    raise exception 'Transfer attempt is not ready for completion';
  end if;

  insert into public.judgment_transfers (
    source_judgment_unit_id,
    treatment,
    what_changed,
    status,
    attempt_id
  )
  values (
    source_judgment_unit::text,
    attempt_treatment,
    attempt_what_changed,
    'completed',
    target_attempt_id
  )
  returning id into existing_transfer;

  update public.transfer_attempts
  set
    status = 'completed',
    result_transfer_id = existing_transfer,
    completed_at = now(),
    updated_at = now()
  where id = target_attempt_id;

  return query
  select
    target_attempt_id,
    'completed'::text,
    existing_transfer;
end;
$$;

revoke execute on function public.complete_transfer_attempt(uuid)
from public, anon;

grant execute on function public.complete_transfer_attempt(uuid)
to authenticated;

alter function public.complete_transfer_attempt(uuid) owner to postgres;
