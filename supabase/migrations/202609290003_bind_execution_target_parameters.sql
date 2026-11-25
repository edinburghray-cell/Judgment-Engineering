alter table public.execution_authorities
  add column if not exists target text,
  add column if not exists parameters jsonb;

alter table public.execution_evidence
  add column if not exists target text,
  add column if not exists parameters jsonb;

drop function if exists public.issue_execution_authority(
  uuid,
  text,
  text,
  timestamptz,
  timestamptz
);

create or replace function public.issue_execution_authority(
  target_decision_id uuid,
  target_action text,
  target_scope text,
  target_target text,
  target_parameters jsonb,
  target_valid_from timestamptz,
  target_valid_until timestamptz
)
returns table (
  authority_id uuid,
  decision_id uuid,
  actor_id uuid,
  action text,
  scope text,
  target text,
  parameters jsonb,
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

  if nullif(trim(target_target), '') is null then
    raise exception 'Execution target is required';
  end if;

  if target_parameters is null then
    raise exception 'Execution parameters are required';
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
    target,
    parameters,
    valid_from,
    valid_until,
    correlation_id
  )
  values (
    target_decision_id,
    decision_actor,
    trim(target_action),
    trim(target_scope),
    trim(target_target),
    target_parameters,
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
    ea.target,
    ea.parameters,
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
  text,
  jsonb,
  timestamptz,
  timestamptz
) from public, anon;

grant execute on function public.issue_execution_authority(
  uuid,
  text,
  text,
  text,
  jsonb,
  timestamptz,
  timestamptz
) to authenticated;

alter function public.issue_execution_authority(
  uuid,
  text,
  text,
  text,
  jsonb,
  timestamptz,
  timestamptz
) owner to postgres;


drop function if exists public.authorize_execution(
  uuid,
  text,
  text
);

create or replace function public.authorize_execution(
  target_authority_id uuid,
  requested_action text,
  requested_scope text,
  requested_target text,
  requested_parameters jsonb
)
returns table (
  authority_id uuid,
  decision_id uuid,
  actor_id uuid,
  action text,
  scope text,
  target text,
  parameters jsonb,
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
  authority_decision_id uuid;
  authority_actor uuid;
  authority_action text;
  authority_scope text;
  authority_target text;
  authority_parameters jsonb;
  authority_valid_from timestamptz;
  authority_valid_until timestamptz;
  authority_correlation_id uuid;
  authority_revoked_at timestamptz;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  if target_authority_id is null then
    raise exception 'Execution authority is required';
  end if;

  if nullif(trim(requested_action), '') is null then
    raise exception 'Execution action is required';
  end if;

  if nullif(trim(requested_scope), '') is null then
    raise exception 'Execution scope is required';
  end if;

  if nullif(trim(requested_target), '') is null then
    raise exception 'Execution target is required';
  end if;

  if requested_parameters is null then
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
    ea.correlation_id,
    ea.revoked_at
  into
    authority_decision_id,
    authority_actor,
    authority_action,
    authority_scope,
    authority_target,
    authority_parameters,
    authority_valid_from,
    authority_valid_until,
    authority_correlation_id,
    authority_revoked_at
  from public.execution_authorities ea
  where ea.id = target_authority_id;

  if not found then
    raise exception 'Execution authority not found';
  end if;

  if authority_actor <> current_actor then
    raise exception 'Execution actor is not authorized by this authority';
  end if;

  if authority_revoked_at is not null then
    raise exception 'Execution authority has been revoked';
  end if;

  if authority_target is null or authority_parameters is null then
    raise exception 'Execution authority has no target binding';
  end if;

  if trim(requested_action) <> authority_action then
    raise exception 'Execution action exceeds authority';
  end if;

  if trim(requested_scope) <> authority_scope then
    raise exception 'Execution scope exceeds authority';
  end if;

  if trim(requested_target) <> authority_target then
    raise exception 'Execution target exceeds authority';
  end if;

  if requested_parameters <> authority_parameters then
    raise exception 'Execution parameters exceed authority';
  end if;

  if now() < authority_valid_from then
    raise exception 'Execution authority is not yet valid';
  end if;

  if now() > authority_valid_until then
    raise exception 'Execution authority has expired';
  end if;

  return query
  select
    target_authority_id,
    authority_decision_id,
    authority_actor,
    authority_action,
    authority_scope,
    authority_target,
    authority_parameters,
    authority_valid_from,
    authority_valid_until,
    authority_correlation_id;
end;
$$;

revoke execute on function public.authorize_execution(
  uuid,
  text,
  text,
  text,
  jsonb
) from public, anon;

grant execute on function public.authorize_execution(
  uuid,
  text,
  text,
  text,
  jsonb
) to authenticated;

alter function public.authorize_execution(
  uuid,
  text,
  text,
  text,
  jsonb
) owner to postgres;


drop function if exists public.execute_authorized_action(
  uuid,
  text,
  text,
  uuid
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
  authority_id uuid,
  decision_id uuid,
  actor_id uuid,
  action text,
  scope text,
  target text,
  parameters jsonb,
  executed_at timestamptz,
  correlation_id uuid,
  operation_id uuid,
  result text,
  evidence jsonb
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  authority_decision_id uuid;
  authority_actor uuid;
  authority_action text;
  authority_scope text;
  authority_target text;
  authority_parameters jsonb;
  authority_valid_from timestamptz;
  authority_valid_until timestamptz;
  authority_correlation_id uuid;
  authority_revoked_at timestamptz;

  execution_time timestamptz;
  execution_result text;
  execution_evidence jsonb;
  persisted_evidence_id uuid;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  if target_authority_id is null then
    raise exception 'Execution authority is required';
  end if;

  if target_operation_id is null then
    raise exception 'Operation identity is required';
  end if;

  if nullif(trim(target_action), '') is null then
    raise exception 'Execution action is required';
  end if;

  if nullif(trim(target_scope), '') is null then
    raise exception 'Execution scope is required';
  end if;

  if nullif(trim(target_target), '') is null then
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
    ea.correlation_id,
    ea.revoked_at
  into
    authority_decision_id,
    authority_actor,
    authority_action,
    authority_scope,
    authority_target,
    authority_parameters,
    authority_valid_from,
    authority_valid_until,
    authority_correlation_id,
    authority_revoked_at
  from public.execution_authorities ea
  where ea.id = target_authority_id;

  if not found then
    raise exception 'Execution authority not found';
  end if;

  if authority_actor <> current_actor then
    raise exception 'Execution actor is not authorized by this authority';
  end if;

  if authority_revoked_at is not null then
    raise exception 'Execution authority has been revoked';
  end if;

  if authority_target is null or authority_parameters is null then
    raise exception 'Execution authority has no target binding';
  end if;

  if trim(target_action) <> authority_action then
    raise exception 'Execution action exceeds authority';
  end if;

  if trim(target_scope) <> authority_scope then
    raise exception 'Execution scope exceeds authority';
  end if;

  if trim(target_target) <> authority_target then
    raise exception 'Execution target exceeds authority';
  end if;

  if target_parameters <> authority_parameters then
    raise exception 'Execution parameters exceed authority';
  end if;

  if now() < authority_valid_from then
    raise exception 'Execution authority is not yet valid';
  end if;

  if now() > authority_valid_until then
    raise exception 'Execution authority has expired';
  end if;

  select ee.id
  into persisted_evidence_id
  from public.execution_evidence ee
  where ee.authority_id = target_authority_id
    and ee.operation_id = target_operation_id;

  if found then
    return query
    select
      ee.authority_id,
      ee.decision_id,
      ee.actor_id,
      ee.action,
      ee.scope,
      ee.target,
      ee.parameters,
      ee.executed_at,
      ee.correlation_id,
      ee.operation_id,
      ee.result,
      ee.evidence
    from public.execution_evidence ee
    where ee.id = persisted_evidence_id;

    return;
  end if;

  execution_time := now();
  execution_result := 'executed';

  execution_evidence := jsonb_build_object(
    'authority_id', target_authority_id,
    'decision_id', authority_decision_id,
    'action', authority_action,
    'scope', authority_scope,
    'target', authority_target,
    'parameters', authority_parameters,
    'operation_id', target_operation_id,
    'executed_at', execution_time
  );

  insert into public.execution_evidence (
    authority_id,
    decision_id,
    actor_id,
    action,
    scope,
    target,
    parameters,
    executed_at,
    correlation_id,
    operation_id,
    result,
    evidence
  )
  values (
    target_authority_id,
    authority_decision_id,
    current_actor,
    authority_action,
    authority_scope,
    authority_target,
    authority_parameters,
    execution_time,
    authority_correlation_id,
    target_operation_id,
    execution_result,
    execution_evidence
  )
  on conflict (authority_id, operation_id) do nothing
  returning id into persisted_evidence_id;

  if persisted_evidence_id is null then
    select ee.id
    into persisted_evidence_id
    from public.execution_evidence ee
    where ee.authority_id = target_authority_id
      and ee.operation_id = target_operation_id;
  end if;

  return query
  select
    ee.authority_id,
    ee.decision_id,
    ee.actor_id,
    ee.action,
    ee.scope,
    ee.target,
    ee.parameters,
    ee.executed_at,
    ee.correlation_id,
    ee.operation_id,
    ee.result,
    ee.evidence
  from public.execution_evidence ee
  where ee.id = persisted_evidence_id;
end;
$$;

revoke execute on function public.execute_authorized_action(
  uuid,
  text,
  text,
  uuid,
  text,
  jsonb
) from public, anon;

grant execute on function public.execute_authorized_action(
  uuid,
  text,
  text,
  uuid,
  text,
  jsonb
) to authenticated;

alter function public.execute_authorized_action(
  uuid,
  text,
  text,
  uuid,
  text,
  jsonb
) owner to postgres;
