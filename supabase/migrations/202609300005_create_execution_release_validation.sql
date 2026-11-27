-- Z6.29
-- Create the execution-time release validation boundary.
--
-- This function validates an already-authorized execution operation
-- against the current state of its execution authority.
--
-- It does not create an operation.
-- It does not create an execution run.
-- It does not execute an external action.
-- It does not create execution evidence.
--
-- Rejected release presentations are recorded in execution_attempts.

begin;

drop function if exists public.release_execution_operation(uuid);

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
  operation_record record;
  authority_record public.execution_authorities%rowtype;
  rejection text;
  new_attempt_id uuid;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  if target_operation_id is null then
    raise exception 'Execution operation identity is required';
  end if;

  /*
   * Lock the operation while deciding whether it can be released.
   */
  select
    eo.operation_id,
    eo.authority_id,
    eo.decision_id,
    eo.actor_id,
    eo.action,
    eo.scope,
    eo.target,
    eo.parameters,
    eo.status
  into operation_record
  from public.execution_operations eo
  where eo.operation_id = target_operation_id
  for update;

  if not found then
    raise exception 'Execution operation not found';
  end if;

  if operation_record.actor_id <> current_actor then
    raise exception 'Only the operation actor can validate execution release';
  end if;

  /*
   * An operation can only cross the release boundary once it is
   * still in the authorization state.
   */
  if operation_record.status <> 'authorized' then
    rejection := 'Execution operation is not releasable';
  end if;

  /*
   * Lock the authority so the release decision is made against
   * one consistent authority state.
   */
  if rejection is null then
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
      ea.revoked_at,
      ea.correlation_id
    into authority_record
    from public.execution_authorities ea
    where ea.id = operation_record.authority_id
    for update;

    if not found then
      rejection := 'Execution authority not found';
    end if;
  end if;

  /*
   * The operation is already bound to the authority.
   * Reconfirm the binding before releasing it.
   */
  if rejection is null and authority_record.decision_id <> operation_record.decision_id then
    rejection := 'Execution operation decision binding is invalid';
  elsif rejection is null and authority_record.actor_id <> operation_record.actor_id then
    rejection := 'Execution operation actor binding is invalid';
  elsif rejection is null and authority_record.action <> operation_record.action then
    rejection := 'Execution operation action binding is invalid';
  elsif rejection is null and authority_record.scope <> operation_record.scope then
    rejection := 'Execution operation scope binding is invalid';
  elsif rejection is null and authority_record.target <> operation_record.target then
    rejection := 'Execution operation target binding is invalid';
  elsif rejection is null and authority_record.parameters <> operation_record.parameters then
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
      operation_record.authority_id,
      operation_record.decision_id,
      operation_record.actor_id,
      operation_record.operation_id,
      operation_record.action,
      operation_record.scope,
      operation_record.target,
      operation_record.parameters,
      now(),
      'rejected',
      rejection,
      case
        when authority_record.correlation_id is not null
        then authority_record.correlation_id
        else null
      end
    )
    returning id into new_attempt_id;

    return query
    select
      'rejected'::text,
      false,
      operation_record.authority_id,
      operation_record.decision_id,
      operation_record.actor_id,
      operation_record.operation_id,
      operation_record.action,
      operation_record.scope,
      operation_record.target,
      operation_record.parameters,
      authority_record.valid_from,
      authority_record.valid_until,
      new_attempt_id,
      rejection;

    return;
  end if;

  return query
  select
    'authorized'::text,
    true,
    operation_record.authority_id,
    operation_record.decision_id,
    operation_record.actor_id,
    operation_record.operation_id,
    operation_record.action,
    operation_record.scope,
    operation_record.target,
    operation_record.parameters,
    authority_record.valid_from,
    authority_record.valid_until,
    null::uuid,
    null::text;
end;
$$;

revoke execute on function public.release_execution_operation(uuid)
from public, anon;

grant execute on function public.release_execution_operation(uuid)
to authenticated;

alter function public.release_execution_operation(uuid)
owner to postgres;

commit;