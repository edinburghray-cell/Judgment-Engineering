create schema if not exists private;

create or replace function private.can_transfer_judgment_unit(target_judgment_unit_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.judgment_unit_access
    where actor_id = (select auth.uid())
      and judgment_unit_id = target_judgment_unit_id
      and can_transfer = true
  );
$$;

revoke execute on function private.can_transfer_judgment_unit(uuid) from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.can_transfer_judgment_unit(uuid) to authenticated;

alter table public.judgment_unit_access enable row level security;

revoke all on table public.judgment_unit_access from anon, authenticated;
grant select on table public.judgment_unit_access to authenticated;

drop policy if exists "Actors can view their own transfer access" on public.judgment_unit_access;

create policy "Actors can view their own transfer access"
on public.judgment_unit_access
for select
to authenticated
using ((select auth.uid()) = actor_id);

alter table public.transfer_attempts enable row level security;

revoke all on table public.transfer_attempts from anon, authenticated;
grant select, insert on table public.transfer_attempts to authenticated;

drop policy if exists "Actors can view their own transfer attempts" on public.transfer_attempts;
drop policy if exists "Authorized actors can create transfer attempts" on public.transfer_attempts;

create policy "Actors can view their own transfer attempts"
on public.transfer_attempts
for select
to authenticated
using ((select auth.uid()) = actor_id);

create policy "Authorized actors can create transfer attempts"
on public.transfer_attempts
for insert
to authenticated
with check (
  (select auth.uid()) = actor_id
  and (select private.can_transfer_judgment_unit(source_judgment_unit_id))
);

alter table public.judgment_transfers enable row level security;

revoke all on table public.judgment_transfers from anon, authenticated;
grant select on table public.judgment_transfers to anon, authenticated;

drop policy if exists "Judgment transfers remain publicly readable" on public.judgment_transfers;

create policy "Judgment transfers remain publicly readable"
on public.judgment_transfers
for select
to anon, authenticated
using (true);
