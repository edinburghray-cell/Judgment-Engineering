create table if not exists public.judgment_draft_revisions (
  id uuid primary key default gen_random_uuid(),

  judgment_draft_id uuid not null
    references public.judgment_drafts(id)
    on delete cascade,

  actor_id uuid not null
    references auth.users(id),

  field text not null,

  original_value jsonb,
  corrected_value jsonb,

  correction_reason text not null,

  created_at timestamptz not null default now(),

  correlation_id uuid not null default gen_random_uuid()
);

create index if not exists judgment_draft_revisions_draft_idx
  on public.judgment_draft_revisions(judgment_draft_id);

create index if not exists judgment_draft_revisions_actor_idx
  on public.judgment_draft_revisions(actor_id);

create index if not exists judgment_draft_revisions_correlation_idx
  on public.judgment_draft_revisions(correlation_id);

alter table public.judgment_draft_revisions enable row level security;

revoke all on public.judgment_draft_revisions from public, anon, authenticated;

alter table public.judgment_draft_revisions
  owner to postgres;
