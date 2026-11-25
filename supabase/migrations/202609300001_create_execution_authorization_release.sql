-- Milestone Z5: JE execution authorization release boundary.
--
-- JE validates and releases an exact authorized operation.
-- It does not claim that an external action has executed.
--
-- Rejected presentations remain durable in execution_attempts.
-- Successful authorization does not create execution_evidence.
-- External execution and outcome evidence remain downstream concerns.

drop function if exists public.authorize_execution(
  uuid,
  text,
  text
);

drop function if exists public.authorize_execution(
  uuid,
  text,
  text,
  uuid,
  text,
  jsonb
);

create or replace function public.authorize_execution(
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

  new_attempt_id uuid;
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
      target_authority_id,
      authority_decision_id,
      current_actor,
      target_operation_id,
      trim(target_action),
      trim(target_scope),
      target_target,
      target_parameters,
      authority_valid_from,
      authority_valid_until,
      new_attempt_id,
      rejection;

    return;
  end if;

  return query
  select
    'authorized'::text,
    true,
    target_authority_id,
    authority_decision_id,
    current_actor,
    target_operation_id,
    authority_action,
    authority_scope,
    authority_target,
    authority_parameters,
    authority_valid_from,
    authority_valid_until,
    null::uuid,
    null::text;
end;
$$;

revoke execute on function public.authorize_execution(
  uuid,
  text,
  text,
  uuid,
  text,
  jsonb
)
from public, anon;

grant execute on function public.authorize_execution(
  uuid,
  text,
  text,
  uuid,
  text,
  jsonb
)
to authenticated;

alter function public.authorize_execution(
  uuid,
  text,
  text,
  uuid,
  text,
  jsonb
)
owner to postgres;
