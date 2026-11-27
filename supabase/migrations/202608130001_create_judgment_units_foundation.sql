-- Recovered baseline definition from JE-schema-recovery.sql.
create table public.judgment_units (
  id uuid default gen_random_uuid() not null,
  seq_num bigint not null generated always as identity,
  judgment_unit_id text generated always as (
    'JU-'::text || lpad(seq_num::text, 6, '0'::text)
  ) stored,
  judgment_version integer default 1 not null,
  parent_judgment_unit_id uuid,
  review_due_date date,
  deleted boolean default false not null,
  deleted_at timestamptz,
  title text not null,
  decision_date date default current_date not null,
  department text,
  decision_owner text,
  status text default 'Proposed'::text not null,
  situation text,
  problem text,
  options jsonb default '[]'::jsonb,
  rationale text,
  assumptions text,
  evidence jsonb default '[]'::jsonb,
  accepted_risks text,
  success_metrics text,
  chosen_option text,
  rejected_options jsonb default '[]'::jsonb,
  outcome_status text,
  assumptions_confirmed text,
  assumptions_invalidated text,
  unexpected_risks text,
  next_time_changes text,
  retrospective_date date,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  capture_actor uuid,
  constraint judgment_units_pkey primary key (id),
  constraint judgment_units_capture_actor_fkey foreign key (capture_actor) references auth.users(id),
  constraint judgment_units_parent_judgment_unit_id_fkey foreign key (parent_judgment_unit_id) references public.judgment_units(id)
);

create index idx_judgment_units_deleted on public.judgment_units using btree (deleted);
create index idx_judgment_units_department on public.judgment_units using btree (department);
create unique index idx_judgment_units_ju_id on public.judgment_units using btree (judgment_unit_id);
create index idx_judgment_units_owner on public.judgment_units using btree (decision_owner);
create index idx_judgment_units_status on public.judgment_units using btree (status);
