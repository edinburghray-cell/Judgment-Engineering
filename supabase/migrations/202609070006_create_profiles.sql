create table if not exists public.profiles (
  user_id uuid primary key
    references auth.users(id)
    on delete cascade,

  display_name text not null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

revoke all on table public.profiles from anon, authenticated;
grant select on table public.profiles to authenticated;

drop policy if exists "Users can view their own profile" on public.profiles;

create policy "Users can view their own profile"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = user_id);
