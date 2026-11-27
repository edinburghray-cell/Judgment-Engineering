begin;

alter table public.judgment_units
  add column if not exists capture_actor uuid references auth.users(id);

create policy je_insert_judgment_units_capture_actor
  on public.judgment_units
  for insert
  to authenticated
  with check (capture_actor = (select auth.uid()));

revoke insert on table public.judgment_units from public, anon;
grant insert on table public.judgment_units to authenticated;

create or replace function private.grant_judgment_unit_capture_read_access()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.capture_actor is null
    or new.capture_actor is distinct from auth.uid() then
    raise exception 'capture actor must match the authenticated user'
      using errcode = '42501';
  end if;

  insert into public.judgment_unit_access (
    actor_id,
    judgment_unit_id,
    can_read
  )
  values (
    new.capture_actor,
    new.id,
    true
  )
  on conflict (actor_id, judgment_unit_id)
  do update set can_read = true;

  return new;
end;
$$;

revoke all on function private.grant_judgment_unit_capture_read_access()
  from public, anon, authenticated;

create trigger judgment_units_grant_capture_read_access
  after insert on public.judgment_units
  for each row
  execute function private.grant_judgment_unit_capture_read_access();

commit;
