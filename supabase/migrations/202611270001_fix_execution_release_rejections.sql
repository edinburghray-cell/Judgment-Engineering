-- Correct release validation rejections without changing execution semantics.
-- Release validation never executes an external action.
begin;

create or replace function public.release_execution_operation(
  target_operation_id uuid
)
returns table (
  status text,
  authorized boolean,
  authority_id uuid,
  decision_id uuid,
  actor_id uuid,
  operation_id uuid,
  action text,
  scope text,
  target text,
  parameters jsonb,
  valid_from timestamptz,
  valid_until timestamptz,
  attempt_id uuid,
  rejection_reason text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  operation_record public.execution_operations%rowtype;
  authority_record public.execution_authorities%rowtype;
  decision_record public.decisions%rowtype;
  rejection text;
  new_attempt_id uuid;
  wrong_actor boolean := false;
begin
  current_actor := auth.uid();
  if current_actor is null then
    raise exception 'Authentication required';
  end if;
  if target_operation_id is null then
    raise exception 'Execution operation identity is required';
  end if;

  select eo.* into operation_record
  from public.execution_operations eo
  where eo.operation_id = target_operation_id
  for update;

  if not found then
    -- There is no operation/authority/decision context to truthfully audit.
    return query select 'rejected'::text, false, null::uuid, null::uuid,
      null::uuid, null::uuid, null::text, null::text, null::text,
      null::jsonb, null::timestamptz, null::timestamptz, null::uuid,
      'Execution operation unavailable'::text;
    return;
  end if;

  rejection := null;
  if operation_record.actor_id is distinct from current_actor then
    wrong_actor := true;
    rejection := 'Only the operation actor can validate execution release';
  elsif operation_record.status is distinct from 'authorized' then
    rejection := 'Execution operation is not releasable';
  end if;

  -- Load the authority even for already-rejected operations so the audit
  -- entry and returned record retain all available bound context.
  select ea.* into authority_record
  from public.execution_authorities ea
  where ea.id = operation_record.authority_id
  for update;

  if not found then
    if rejection is null then rejection := 'Execution authority not found'; end if;
  end if;

  if rejection is null then
    select d.* into decision_record
    from public.decisions d
    where d.id = operation_record.decision_id
    for share;
    if not found then
      rejection := 'Execution decision not found';
    elsif decision_record.decision is distinct from 'approve' then
      rejection := 'Execution decision is no longer approved';
    end if;
  end if;

  if rejection is null and authority_record.decision_id is distinct from operation_record.decision_id then
    rejection := 'Execution operation decision binding is invalid';
  elsif rejection is null and authority_record.actor_id is distinct from operation_record.actor_id then
    rejection := 'Execution operation actor binding is invalid';
  elsif rejection is null and authority_record.action is distinct from operation_record.action then
    rejection := 'Execution operation action binding is invalid';
  elsif rejection is null and authority_record.scope is distinct from operation_record.scope then
    rejection := 'Execution operation scope binding is invalid';
  elsif rejection is null and authority_record.target is distinct from operation_record.target then
    rejection := 'Execution operation target binding is invalid';
  elsif rejection is null and authority_record.parameters is distinct from operation_record.parameters then
    rejection := 'Execution operation parameter binding is invalid';
  elsif rejection is null and authority_record.revoked_at is not null then
    rejection := 'Execution authority has been revoked';
  elsif rejection is null and now() < authority_record.valid_from then
    rejection := 'Execution authority is not yet valid';
  elsif rejection is null and now() >= authority_record.valid_until then
    rejection := 'Execution authority has expired';
  end if;

  if rejection is not null then
    insert into public.execution_attempts (
      authority_id, decision_id, actor_id, operation_id, action, scope,
      target, parameters, attempted_at, status, rejection_reason, correlation_id
    ) values (
      operation_record.authority_id, operation_record.decision_id, current_actor,
      operation_record.operation_id, operation_record.action, operation_record.scope,
      operation_record.target, operation_record.parameters, now(), 'rejected',
      rejection, authority_record.correlation_id
    ) returning id into new_attempt_id;

    if wrong_actor then
      -- Keep the attempt ID internal: its presence would reveal that the
      -- requested operation exists. The audit row above retains the ID.
      return query select 'rejected'::text, false, null::uuid,
        null::uuid, null::uuid,
        null::uuid, null::text, null::text,
        null::text, null::jsonb, null::timestamptz, null::timestamptz,
        null::uuid, 'Execution operation unavailable'::text;
      return;
    end if;

    return query select 'rejected'::text, false, operation_record.authority_id,
      operation_record.decision_id, operation_record.actor_id,
      operation_record.operation_id, operation_record.action, operation_record.scope,
      operation_record.target, operation_record.parameters,
      authority_record.valid_from, authority_record.valid_until, new_attempt_id, rejection;
    return;
  end if;

  return query select 'authorized'::text, true, operation_record.authority_id,
    operation_record.decision_id, operation_record.actor_id,
    operation_record.operation_id, operation_record.action, operation_record.scope,
    operation_record.target, operation_record.parameters,
    authority_record.valid_from, authority_record.valid_until, null::uuid, null::text;
end;
$$;

revoke execute on function public.release_execution_operation(uuid) from public, anon;
grant execute on function public.release_execution_operation(uuid) to authenticated;
alter function public.release_execution_operation(uuid) owner to postgres;

commit;
