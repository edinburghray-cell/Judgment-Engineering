create table if not exists public.execution_evidence (
  id uuid primary key default gen_random_uuid(),

  authority_id uuid not null
    references public.execution_authorities(id),

  decision_id uuid not null
    references public.decisions(id),

  actor_id uuid not null
    references auth.users(id),

  action text not null,
  scope text not null,

  executed_at timestamptz not null default now(),

  correlation_id uuid not null,

  result text not null,

  evidence jsonb,

  created_at timestamptz not null default now()
);