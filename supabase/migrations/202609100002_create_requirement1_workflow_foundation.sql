create table if not exists public.proposals (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table if not exists public.proposal_versions (
  id uuid primary key default gen_random_uuid(),

  proposal_id uuid not null
    references public.proposals(id),

  version_number integer not null
    check (version_number > 0),

  change_id text not null,
  scope text not null,
  affected_system text not null,
  environment text not null,

  assumptions text,
  alternatives jsonb not null default '[]'::jsonb,
  evidence jsonb not null default '[]'::jsonb,
  known_risks text,

  created_at timestamptz not null default now(),

  unique (proposal_id, version_number)
);

create table if not exists public.review_cycles (
  id uuid primary key default gen_random_uuid(),

  proposal_version_id uuid not null
    references public.proposal_versions(id),

  status text not null default 'draft'
    check (
      status in (
        'draft',
        'reviewable',
        'structured_unconfirmed',
        'human_confirmed',
        'decided',
        'preserved_complete'
      )
    ),

  confirmed_judgment_id uuid
    references public.judgments(id),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.decisions (
  id uuid primary key default gen_random_uuid(),

  review_cycle_id uuid not null
    references public.review_cycles(id),

  decision text not null
    check (decision in ('approve', 'reject', 'defer')),

  actor_id uuid not null
    references auth.users(id),

  authority_basis text not null,

  decided_at timestamptz not null default now(),

  rationale text,
  residual_risks text,

  correlation_id uuid not null,
  causation_id uuid,

  created_at timestamptz not null default now(),

  unique (review_cycle_id)
);

create table if not exists public.workflow_audit (
  id uuid primary key default gen_random_uuid(),

  review_cycle_id uuid not null
    references public.review_cycles(id),

  actor_id uuid
    references auth.users(id),

  action text not null,

  from_state text,
  to_state text,

  authority_basis text,

  correlation_id uuid not null,
  causation_id uuid,

  created_at timestamptz not null default now()
);

create index if not exists proposal_versions_proposal_id_idx
  on public.proposal_versions(proposal_id);

create index if not exists review_cycles_proposal_version_id_idx
  on public.review_cycles(proposal_version_id);

create index if not exists review_cycles_confirmed_judgment_id_idx
  on public.review_cycles(confirmed_judgment_id);

create index if not exists decisions_actor_id_idx
  on public.decisions(actor_id);

create index if not exists decisions_correlation_id_idx
  on public.decisions(correlation_id);

create index if not exists workflow_audit_review_cycle_id_idx
  on public.workflow_audit(review_cycle_id);

create index if not exists workflow_audit_correlation_id_idx
  on public.workflow_audit(correlation_id);
