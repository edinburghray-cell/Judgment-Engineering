create table if not exists public.external_identity_bindings (
  id uuid primary key default gen_random_uuid(),
  source_system text not null,
  external_identity text not null,
  je_actor_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source_system, external_identity),
  unique (source_system, je_actor_id)
);

create index if not exists external_identity_bindings_actor_idx
  on public.external_identity_bindings(je_actor_id);

alter table public.external_identity_bindings enable row level security;

revoke all on public.external_identity_bindings from public, anon, authenticated;
grant select on public.external_identity_bindings to service_role;
