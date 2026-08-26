create table if not exists judgment_transfers (
  id uuid primary key default gen_random_uuid(),

  source_judgment_unit_id text not null,

  treatment text not null
    check (treatment in ('apply', 'adapt', 'reject')),

  what_changed text,

  created_at timestamptz not null default now()
);
