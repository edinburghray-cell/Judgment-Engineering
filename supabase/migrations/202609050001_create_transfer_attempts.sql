create table if not exists transfer_attempts (
  id uuid primary key,

  actor_id uuid not null
    references auth.users(id),

  source_judgment_unit_id uuid not null
    references judgment_units(id),

  treatment text not null
    check (treatment in ('apply', 'adapt', 'reject')),

  what_changed text,

  status text not null default 'initiated'
    check (
      status in (
        'initiated',
        'processing',
        'completed',
        'failed',
        'interrupted'
      )
    ),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  completed_at timestamptz,

  result_transfer_id uuid
    references judgment_transfers(id),

  failure_reason text
);

create index if not exists transfer_attempts_source_judgment_unit_id_idx
  on transfer_attempts(source_judgment_unit_id);

create index if not exists transfer_attempts_status_idx
  on transfer_attempts(status);
