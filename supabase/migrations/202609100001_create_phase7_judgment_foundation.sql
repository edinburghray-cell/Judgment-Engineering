create sequence if not exists public.judgment_unit_seq;

create table if not exists public.judgment_drafts (
  id uuid primary key default gen_random_uuid(),

  title text not null,
  situation text,
  problem text,
  options jsonb not null default '[]'::jsonb,
  rationale text,
  assumptions text,
  evidence jsonb not null default '[]'::jsonb,
  accepted_risks text,
  success_metrics text,
  chosen_option text,
  rejected_options jsonb not null default '[]'::jsonb,

  decision_owner text,
  capture_actor uuid
    references auth.users(id),
  authority_context text,

  status text not null default 'draft'
    check (
      status in (
        'draft',
        'reviewable',
        'structured_unconfirmed',
        'human_confirmed'
      )
    ),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.judgments (
  id uuid primary key default gen_random_uuid(),

  judgment_unit_id text not null unique
    default (
      'JU-' ||
      lpad(nextval('public.judgment_unit_seq')::text, 6, '0')
    ),

  judgment_version integer not null default 1
    check (judgment_version > 0),

  title text not null,
  situation text,
  problem text,
  options jsonb not null default '[]'::jsonb,
  rationale text,
  assumptions text,
  evidence jsonb not null default '[]'::jsonb,
  accepted_risks text,
  success_metrics text,
  chosen_option text,
  rejected_options jsonb not null default '[]'::jsonb,

  decision_owner text,

  capture_actor uuid
    references auth.users(id),

  committing_actor uuid not null
    references auth.users(id),

  authority_context text not null,

  committed_at timestamptz not null default now(),

  predecessor_judgment_id uuid
    references public.judgments(id),

  created_at timestamptz not null default now()
);

create index if not exists judgment_drafts_capture_actor_idx
  on public.judgment_drafts(capture_actor);

create index if not exists judgments_committing_actor_idx
  on public.judgments(committing_actor);

create index if not exists judgments_decision_owner_idx
  on public.judgments(decision_owner);

create index if not exists judgments_predecessor_judgment_id_idx
  on public.judgments(predecessor_judgment_id);
