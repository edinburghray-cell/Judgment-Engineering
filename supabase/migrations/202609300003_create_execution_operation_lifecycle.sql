-- Z6.19
-- Create the execution operation/run lifecycle model.
--
-- This migration establishes the lifecycle layer only.
-- It does not modify authorize_execution().

begin;

create table if not exists public.execution_operations (
  id uuid primary key default gen_random_uuid(),

  operation_id uuid not null unique,

  authority_id uuid not null
    references public.execution_authorities(id)
    on delete restrict,

  decision_id uuid not null
    references public.decisions(id)
    on delete restrict,

  actor_id uuid not null
    references auth.users(id)
    on delete restrict,

  action text not null,
  scope text not null,
  target text not null,
  parameters jsonb not null,

  status text not null default 'authorized'
    check (
      status in (
        'authorized',
        'execution_started',
        'outcome_pending',
        'resolved'
      )
    ),

  outcome text
    check (
      outcome is null
      or outcome in (
        'success',
        'failure',
        'unknown'
      )
    ),

  created_at timestamptz not null default now(),
  started_at timestamptz,
  resolved_at timestamptz,
  updated_at timestamptz not null default now(),

  constraint execution_operations_resolved_consistency
    check (
      (status = 'resolved' and outcome is not null)
      or
      (status <> 'resolved')
    )
);

create index if not exists execution_operations_authority_idx
  on public.execution_operations(authority_id);

create index if not exists execution_operations_decision_idx
  on public.execution_operations(decision_id);

create index if not exists execution_operations_actor_idx
  on public.execution_operations(actor_id);

create index if not exists execution_operations_status_idx
  on public.execution_operations(status);


create table if not exists public.execution_runs (
  id uuid primary key default gen_random_uuid(),

  operation_id uuid not null
    references public.execution_operations(operation_id)
    on delete restrict,

  task_id text,
  grant_id text,

  execution_status text not null default 'authorized'
    check (
      execution_status in (
        'authorized',
        'execution_started',
        'outcome_pending',
        'resolved'
      )
    ),

  outcome text
    check (
      outcome is null
      or outcome in (
        'success',
        'failure',
        'unknown'
      )
    ),

  started_at timestamptz,
  completed_at timestamptz,

  evidence_reference text,

  evidence_status text not null default 'pending'
    check (
      evidence_status in (
        'pending',
        'persisted',
        'failed'
      )
    ),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint execution_runs_resolved_consistency
    check (
      (execution_status = 'resolved' and outcome is not null)
      or
      (execution_status <> 'resolved')
    )
);

create index if not exists execution_runs_operation_idx
  on public.execution_runs(operation_id);

create index if not exists execution_runs_task_idx
  on public.execution_runs(task_id);

create index if not exists execution_runs_status_idx
  on public.execution_runs(execution_status);

create index if not exists execution_runs_outcome_idx
  on public.execution_runs(outcome);

create index if not exists execution_runs_evidence_status_idx
  on public.execution_runs(evidence_status);


alter table public.execution_operations enable row level security;
alter table public.execution_runs enable row level security;

revoke all on table public.execution_operations
  from anon, authenticated;

revoke all on table public.execution_runs
  from anon, authenticated;

grant all on table public.execution_operations to postgres;
grant all on table public.execution_runs to postgres;

commit;