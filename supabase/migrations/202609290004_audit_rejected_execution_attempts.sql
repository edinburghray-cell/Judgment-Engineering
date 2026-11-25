-- Milestone Z4: Durable audit of rejected execution attempts.
--
-- Successful execution remains represented by execution_evidence.
-- Rejected execution attempts are represented separately so a rejected
-- request is not confused with an executed operation.

create table if not exists public.execution_attempts (
  id uuid primary key default gen_random_uuid(),
  authority_id uuid not null references public.execution_authorities(id),
  decision_id uuid not null references public.decisions(id),
  actor_id uuid not null references auth.users(id),
  operation_id uuid not null,
  action text not null,
  scope text not null,
  target text not null,
  parameters jsonb not null,
  attempted_at timestamptz not null default now(),
  status text not null default 'rejected',
  rejection_reason text not null,
  correlation_id uuid,
  created_at timestamptz not null default now(),

  constraint execution_attempts_status_check
    check (status = 'rejected')
);

create index if not exists execution_attempts_authority_idx
  on public.execution_attempts(authority_id);

create index if not exists execution_attempts_operation_idx
  on public.execution_attempts(operation_id);

create index if not exists execution_attempts_actor_idx
  on public.execution_attempts(actor_id);

create index if not exists execution_attempts_attempted_at_idx
  on public.execution_attempts(attempted_at desc);

alter table public.execution_attempts enable row level security;

revoke all on table public.execution_attempts
from public, anon, authenticated;

drop function if exists public.execute_authorized_action(
  uuid,
  text,
  text,
  uuid
);

drop function if exists public.execute_authorized_action(
  uuid,
  text,
  text,
  uuid,
  text,
  jsonb
);

create or replace function public.execute_authorized_action(
  target_authority_id uuid,
  target_action text,
  target_scope text,
  target_operation_id uuid,
  target_target text,
  target_parameters jsonb
)
returns table (
  status text,
  authorized boolean,
  executed boolean,
  attempt_id uuid,
  evidence_id uuid,
  rejection_reason text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;

  authority_actor uuid;
  authority_decision_id uuid;
  authority_action text;
  authority_scope text;
  authority_target text;
  authority_parameters jsonb;
  authority_valid_from timestamptz;
  authority_valid_until timestamptz;
  authority_revoked_at timestamptz;
  authority_correlation_id uuid;

  existing_evidence_id uuid;
  new_attempt_id uuid;
  new_evidence_id uuid;

  rejection text;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  if target_authority_id is null then
    raise exception 'Execution authority is required';
  end if;

  if target_operation_id is null then
    raise exception 'Execution operation identity is required';
  end if;

  if nullif(trim(target_action), '') is null then
    raise exception 'Execution action is required';
  end if;

  if nullif(trim(target_scope), '') is null then
    raise exception 'Execution scope is required';
  end if;

  if target_target is null then
    raise exception 'Execution target is required';
  end if;

  if target_parameters is null then
    raise exception 'Execution parameters are required';
  end if;

  select
    ea.decision_id,
    ea.actor_id,
    ea.action,
    ea.scope,
    ea.target,
    ea.parameters,
    ea.valid_from,
    ea.valid_until,
    ea.revoked_at,
    ea.correlation_id
  into
    authority_decision_id,
    authority_actor,
    authority_action,
    authority_scope,
    authority_target,
    authority_parameters,
    authority_valid_from,
    authority_valid_until,
    authority_revoked_at,
    authority_correlation_id
  from public.execution_authorities ea
  where ea.id = target_authority_id
  for update;

  if not found then
    raise exception 'Execution authority not found';
  end if;

  rejection := null;

  if authority_actor <> current_actor then
    rejection := 'Execution actor is not authorized';

  elsif authority_action <> trim(target_action) then
    rejection := 'Execution action is outside authority';

  elsif authority_scope <> trim(target_scope) then
    rejection := 'Execution scope is outside authority';

  elsif authority_target is null then
    rejection := 'Execution authority has no target binding';

  elsif authority_target <> target_target then
    rejection := 'Execution target is outside authority';

  elsif authority_parameters is null then
    rejection := 'Execution authority has no parameter binding';

  elsif authority_parameters <> target_parameters then
    rejection := 'Execution parameters are outside authority';

  elsif authority_revoked_at is not null then
    rejection := 'Execution authority has been revoked';

  elsif now() < authority_valid_from then
    rejection := 'Execution authority is not yet valid';

  elsif now() > authority_valid_until then
    rejection := 'Execution authority has expired';
  end if;

  if rejection is not null then

    insert into public.execution_attempts (
      authority_id,
      decision_id,
      actor_id,
      operation_id,
      action,
      scope,
      target,
      parameters,
      attempted_at,
      status,
      rejection_reason,
      correlation_id
    )
    values (
      target_authority_id,
      authority_decision_id,
      current_actor,
      target_operation_id,
      trim(target_action),
      trim(target_scope),
      target_target,
      target_parameters,
      now(),
      'rejected',
      rejection,
      authority_correlation_id
    )
    returning id into new_attempt_id;

    return query
    select
      'rejected'::text,
      false,
      false,
      new_attempt_id,
      null::uuid,
      rejection;

    return;
  end if;

  select ee.id
  into existing_evidence_id
  from public.execution_evidence ee
  where ee.authority_id = target_authority_id
    and ee.operation_id = target_operation_id
  limit 1;

  if existing_evidence_id is not null then

    return query
    select
      'executed'::text,
      true,
      true,
      null::uuid,
      existing_evidence_id,
      null::text;

    return;
  end if;

  insert into public.execution_evidence (
    authority_id,
    decision_id,
    actor_id,
    operation_id,
    action,
    scope,
    target,
    parameters,
    executed_at,
    correlation_id,
    result,
    evidence
  )
  values (
    target_authority_id,
    authority_decision_id,
    current_actor,
    target_operation_id,
    authority_action,
    authority_scope,
    authority_target,
    authority_parameters,
    now(),
    authority_correlation_id,
    'executed',
    jsonb_build_object(
      'operation_id', target_operation_id,
      'target', authority_target,
      'parameters', authority_parameters
    )
  )
  on conflict (authority_id, operation_id)
  do nothing
  returning id into new_evidence_id;

  if new_evidence_id is null then

    select ee.id
    into new_evidence_id
    from public.execution_evidence ee
    where ee.authority_id = target_authority_id
      and ee.operation_id = target_operation_id
    limit 1;

  end if;

  return query
  select
    'executed'::text,
    true,
    true,
    null::uuid,
    new_evidence_id,
    null::text;
end;
$$;

revoke execute on function public.execute_authorized_action(
  uuid,
  text,
  text,
  uuid,
  text,
  jsonb
)
from public, anon;

grant execute on function public.execute_authorized_action(
  uuid,
  text,
  text,
  uuid,
  text,
  jsonb
)
to authenticated;

alter function public.execute_authorized_action(
  uuid,
  text,
  text,
  uuid,
  text,
  jsonb
)
owner to postgres;