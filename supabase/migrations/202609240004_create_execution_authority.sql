create table if not exists public.execution_authorities (
  id uuid primary key default gen_random_uuid(),

  decision_id uuid not null
    references public.decisions(id),

  actor_id uuid not null
    references auth.users(id),

  action text not null,
  scope text not null,

  valid_from timestamptz not null default now(),
  valid_until timestamptz not null,

  correlation_id uuid not null,

  created_at timestamptz not null default now(),

  check (valid_until > valid_from),

  unique (decision_id)
);

create index if not exists execution_authorities_actor_id_idx
  on public.execution_authorities(actor_id);

create index if not exists execution_authorities_correlation_id_idx
  on public.execution_authorities(correlation_id);

create or replace function public.issue_execution_authority(
  target_decision_id uuid,
  target_action text,
  target_scope text,
  target_valid_from timestamptz,
  target_valid_until timestamptz
)
returns table (
  authority_id uuid,
  decision_id uuid,
  actor_id uuid,
  action text,
  scope text,
  valid_from timestamptz,
  valid_until timestamptz,
  correlation_id uuid
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  decision_actor uuid;
  decision_value text;
  decision_correlation_id uuid;
  new_authority_id uuid;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  if target_decision_id is null then
    raise exception 'Decision is required';
  end if;

  if nullif(trim(target_action), '') is null then
    raise exception 'Execution action is required';
  end if;

  if nullif(trim(target_scope), '') is null then
    raise exception 'Execution scope is required';
  end if;

  if target_valid_from is null or target_valid_until is null then
    raise exception 'Authority validity window is required';
  end if;

  if target_valid_until <= target_valid_from then
    raise exception 'Authority valid_until must be after valid_from';
  end if;

  select
    d.actor_id,
    d.decision,
    d.correlation_id
  into
    decision_actor,
    decision_value,
    decision_correlation_id
  from public.decisions d
  where d.id = target_decision_id
  for update;

  if not found then
    raise exception 'Decision not found';
  end if;

  if decision_value <> 'approve' then
    raise exception 'Execution authority can only be issued from an approved decision';
  end if;

  if decision_actor <> current_actor then
    raise exception 'Only the approved decision actor can issue execution authority';
  end if;

  if exists (
    select 1
    from public.execution_authorities ea
    where ea.decision_id = target_decision_id
  ) then
    raise exception 'Execution authority already exists for this decision';
  end if;

  insert into public.execution_authorities (
    decision_id,
    actor_id,
    action,
    scope,
    valid_from,
    valid_until,
    correlation_id
  )
  values (
    target_decision_id,
    decision_actor,
    trim(target_action),
    trim(target_scope),
    target_valid_from,
    target_valid_until,
    decision_correlation_id
  )
  returning id into new_authority_id;

  insert into public.workflow_audit (
    review_cycle_id,
    actor_id,
    action,
    from_state,
    to_state,
    authority_basis,
    correlation_id,
    causation_id
  )
  select
    d.review_cycle_id,
    current_actor,
    'execution_authority_issued',
    'decided',
    'decided',
    d.authority_basis,
    d.correlation_id,
    d.causation_id
  from public.decisions d
  where d.id = target_decision_id;

  return query
  select
    ea.id,
    ea.decision_id,
    ea.actor_id,
    ea.action,
    ea.scope,
    ea.valid_from,
    ea.valid_until,
    ea.correlation_id
  from public.execution_authorities ea
  where ea.id = new_authority_id;
end;
$$;

revoke execute on function public.issue_execution_authority(
  uuid,
  text,
  text,
  timestamptz,
  timestamptz
) from public, anon;

grant execute on function public.issue_execution_authority(
  uuid,
  text,
  text,
  timestamptz,
  timestamptz
) to authenticated;

alter function public.issue_execution_authority(
  uuid,
  text,
  text,
  timestamptz,
  timestamptz
) owner to postgres;
