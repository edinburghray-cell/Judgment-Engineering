drop function if exists public.execute_authorized_action(
  uuid,
  text,
  text
);

create function public.execute_authorized_action(
  target_authority_id uuid,
  target_action text,
  target_scope text
)
returns table (
  authority_id uuid,
  decision_id uuid,
  actor_id uuid,
  action text,
  scope text,
  executed_at timestamptz,
  correlation_id uuid,
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
  authority_valid_from timestamptz;
  authority_valid_until timestamptz;
  authority_correlation_id uuid;

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

  if nullif(trim(target_action), '') is null then
    raise exception 'Execution action is required';
  end if;

  if nullif(trim(target_scope), '') is null then
    raise exception 'Execution scope is required';
  end if;

  select
    ea.decision_id,
    ea.actor_id,
    ea.action,
    ea.scope,
    ea.valid_from,
    ea.valid_until,
    ea.correlation_id
  into
    authority_decision_id,
    authority_actor,
    authority_action,
    authority_scope,
    authority_valid_from,
    authority_valid_until,
    authority_correlation_id
  from public.execution_authorities ea
  where ea.id = target_authority_id;

  if not found then
    raise exception 'Execution authority not found';
  end if;

  if authority_actor <> current_actor then
    raise exception 'Execution actor is not authorized by this authority';
  end if;

  if trim(target_action) <> authority_action then
    raise exception 'Execution action exceeds authority';
  end if;

  if trim(target_scope) <> authority_scope then
    raise exception 'Execution scope exceeds authority';
  end if;

  if now() < authority_valid_from then
    raise exception 'Execution authority is not yet valid';
  end if;

  if now() > authority_valid_until then
    raise exception 'Execution authority has expired';
  end if;

  execution_time := now();
  execution_result := 'executed';

  execution_evidence := jsonb_build_object(
    'authority_id', target_authority_id,
    'decision_id', authority_decision_id,
    'action', authority_action,
    'scope', authority_scope,
    'executed_at', execution_time
  );

  insert into public.execution_evidence (
    authority_id,
    decision_id,
    actor_id,
    action,
    scope,
    executed_at,
    correlation_id,
    result,
    evidence
  )
  values (
    target_authority_id,
    authority_decision_id,
    current_actor,
    authority_action,
    authority_scope,
    execution_time,
    authority_correlation_id,
    execution_result,
    execution_evidence
  )
  returning id into persisted_evidence_id;

  return query
  select
    ee.authority_id,
    ee.decision_id,
    ee.actor_id,
    ee.action,
    ee.scope,
    ee.executed_at,
    ee.correlation_id,
    ee.result,
    ee.evidence
  from public.execution_evidence ee
  where ee.id = persisted_evidence_id;
end;
$$;

revoke execute on function public.execute_authorized_action(
  uuid,
  text,
  text
) from public, anon;

grant execute on function public.execute_authorized_action(
  uuid,
  text,
  text
) to authenticated;

alter function public.execute_authorized_action(
  uuid,
  text,
  text
) owner to postgres;