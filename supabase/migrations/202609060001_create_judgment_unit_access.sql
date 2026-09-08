create table if not exists judgment_unit_access (
  actor_id uuid not null
    references auth.users(id),

  judgment_unit_id uuid not null
    references judgment_units(id),

  can_transfer boolean not null default false,

  created_at timestamptz not null default now(),

  primary key (actor_id, judgment_unit_id)
);

create index if not exists judgment_unit_access_judgment_unit_id_idx
  on judgment_unit_access(judgment_unit_id);