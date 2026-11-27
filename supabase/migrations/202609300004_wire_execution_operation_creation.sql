-- Z6.20
-- Wire successful authorization release into execution_operations.
-- The existing Z5 authorization implementation is preserved intact.
-- Authorization remains authorization; this does not execute an external action.

begin;

alter function public.authorize_execution(
  uuid,
  text,
  text,
  uuid,
  text,
  jsonb
)
rename to authorize_execution_z5;

revoke execute on function public.authorize_execution_z5(
  uuid,
  text,
  text,
  uuid,
  text,
  jsonb
) from public, anon, authenticated;


create or replace function public.authorize_execution(
  target_authority_id uuid,
  target_action text,
  target_scope text,
  target_operation_id uuid,
  target_target text,
  target_parameters jsonb
)
returns table(
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
set search_path to public, pg_temp
as $$
declare
  z5_result record;
  existing_operation record;
begin

  select *
  into z5_result
  from public.authorize_execution_z5(
    target_authority_id,
    target_action,
    target_scope,
    target_operation_id,
    target_target,
    target_parameters
  );

  if z5_result.authorized is not true then
    return query
    select
      z5_result.status,
      z5_result.authorized,
      z5_result.authority_id,
      z5_result.decision_id,
      z5_result.actor_id,
      z5_result.operation_id,
      z5_result.action,
      z5_result.scope,
      z5_result.target,
      z5_result.parameters,
      z5_result.valid_from,
      z5_result.valid_until,
      z5_result.attempt_id,
      z5_result.rejection_reason;

    return;
  end if;

  select *
  into existing_operation
  from public.execution_operations eo
  where eo.operation_id = z5_result.operation_id
  for update;

  if found then

    if existing_operation.authority_id <> z5_result.authority_id
       or existing_operation.decision_id <> z5_result.decision_id
       or existing_operation.actor_id <> z5_result.actor_id
       or existing_operation.action <> z5_result.action
       or existing_operation.scope <> z5_result.scope
       or existing_operation.target <> z5_result.target
       or existing_operation.parameters <> z5_result.parameters
       or existing_operation.status <> 'authorized'
    then
      raise exception
        'Execution operation identity conflicts with existing operation';
    end if;

  else

    insert into public.execution_operations (
      operation_id,
      authority_id,
      decision_id,
      actor_id,
      action,
      scope,
      target,
      parameters,
      status,
      outcome
    )
    values (
      z5_result.operation_id,
      z5_result.authority_id,
      z5_result.decision_id,
      z5_result.actor_id,
      z5_result.action,
      z5_result.scope,
      z5_result.target,
      z5_result.parameters,
      'authorized',
      null
    );

  end if;

  return query
  select
    z5_result.status,
    z5_result.authorized,
    z5_result.authority_id,
    z5_result.decision_id,
    z5_result.actor_id,
    z5_result.operation_id,
    z5_result.action,
    z5_result.scope,
    z5_result.target,
    z5_result.parameters,
    z5_result.valid_from,
    z5_result.valid_until,
    z5_result.attempt_id,
    z5_result.rejection_reason;

end;
$$;


revoke execute on function public.authorize_execution(
  uuid,
  text,
  text,
  uuid,
  text,
  jsonb
) from public, anon;

grant execute on function public.authorize_execution(
  uuid,
  text,
  text,
  uuid,
  text,
  jsonb
) to authenticated;

alter function public.authorize_execution(
  uuid,
  text,
  text,
  uuid,
  text,
  jsonb
) owner to postgres;

commit;
