create or replace function private.protect_judgment_unit_status()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if tg_op = 'INSERT' then
    if new.status is distinct from 'Proposed' then
      raise exception 'Judgment unit status must be Proposed when inserted';
    end if;
  elsif tg_op = 'UPDATE' then
    if new.status is distinct from old.status then
      raise exception 'Judgment unit status cannot be changed';
    end if;
  end if;

  return new;
end;
$function$;

alter function private.protect_judgment_unit_status() owner to postgres;

revoke all on function private.protect_judgment_unit_status()
  from public, anon, authenticated, service_role;

REVOKE TRIGGER ON TABLE public.judgment_units FROM service_role;

create trigger judgment_units_protect_status
  before insert or update of status on public.judgment_units
  for each row
  execute function private.protect_judgment_unit_status();
