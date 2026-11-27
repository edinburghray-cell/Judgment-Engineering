-- Run after migration 202611270001 against a Supabase test database.
-- All fixture rows are rolled back. No external action is performed.
begin;
do $test$
<<test_block>>
declare
  actor uuid;
  other_actor uuid;
  proposal uuid := gen_random_uuid();
  version_id uuid := gen_random_uuid();
  cycle_id uuid := gen_random_uuid();
  decision_id uuid := gen_random_uuid();
  correlation uuid := gen_random_uuid();
  authority_id uuid;
  operation_id uuid;
  nonexistent_operation_id uuid;
  result record;
  nonexistent_result record;
  attempt_count integer;
  attempts_before integer;
  attempts_after integer;
  internal_attempt_id uuid;
  test_attempt_ids uuid[] := array[]::uuid[];
begin
  select au.id into actor from auth.users au order by au.created_at limit 1;
  select au.id into other_actor from auth.users au where au.id <> actor order by au.created_at limit 1;
  if actor is null or other_actor is null then
    raise exception 'Test requires two auth.users fixtures';
  end if;

  insert into public.proposals(id) values (proposal);
  insert into public.proposal_versions(id, proposal_id, version_number, change_id, scope, affected_system, environment)
  values (version_id, proposal, 1, 'release-test', 'test', 'test-system', 'test');
  insert into public.review_cycles(id, proposal_version_id, status)
  values (cycle_id, version_id, 'decided');
  insert into public.decisions(id, review_cycle_id, decision, actor_id, authority_basis, correlation_id)
  values (decision_id, cycle_id, 'approve', actor, 'test fixture', correlation);

  -- Happy path: validates only; it must not create evidence or runs.
  authority_id := gen_random_uuid(); operation_id := gen_random_uuid();
  insert into public.execution_authorities(id, decision_id, actor_id, action, scope, target, parameters, valid_from, valid_until, correlation_id)
  values (authority_id, decision_id, actor, 'notify', 'test', 'sink', '{"k":1}', now() - interval '1 hour', now() + interval '1 hour', correlation);
  insert into public.execution_operations(operation_id, authority_id, decision_id, actor_id, action, scope, target, parameters)
  values (operation_id, authority_id, decision_id, actor, 'notify', 'test', 'sink', '{"k":1}');
  perform set_config('request.jwt.claim.sub', actor::text, true);
  select * into result from public.release_execution_operation(operation_id);
  if result.status <> 'authorized' or result.authorized is not true or result.attempt_id is not null
     or result.operation_id is distinct from operation_id or result.authority_id is distinct from authority_id
     or result.actor_id is distinct from actor then raise exception 'Successful release validation returned inconsistent context'; end if;
  if exists (select 1 from public.execution_evidence ee where ee.operation_id = test_block.operation_id)
     or exists (select 1 from public.execution_runs er where er.operation_id = test_block.operation_id) then
    raise exception 'Release validation performed execution work';
  end if;

  -- Nonexistent identity has the normalized public response and no audit row.
  nonexistent_operation_id := gen_random_uuid();
  select count(*) into attempts_before from public.execution_attempts;
  select * into nonexistent_result from public.release_execution_operation(nonexistent_operation_id);
  select count(*) into attempts_after from public.execution_attempts;
  if nonexistent_result.status <> 'rejected' or nonexistent_result.authorized is not false
     or nonexistent_result.authority_id is not null or nonexistent_result.decision_id is not null
     or nonexistent_result.actor_id is not null or nonexistent_result.operation_id is not null
     or nonexistent_result.action is not null or nonexistent_result.scope is not null
     or nonexistent_result.target is not null or nonexistent_result.parameters is not null
     or nonexistent_result.valid_from is not null or nonexistent_result.valid_until is not null
     or nonexistent_result.attempt_id is not null
     or nonexistent_result.rejection_reason <> 'Execution operation unavailable'
     or attempts_after <> attempts_before
     or exists (select 1 from public.execution_attempts ea where ea.operation_id = nonexistent_operation_id) then
    raise exception 'Nonexistent operation rejection was inconsistent';
  end if;

  -- Wrong actor is rejected and its attempt captures caller and bound operation context.
  operation_id := gen_random_uuid();
  insert into public.execution_operations(operation_id, authority_id, decision_id, actor_id, action, scope, target, parameters)
  values (operation_id, authority_id, decision_id, actor, 'notify', 'test', 'sink', '{"k":1}');
  perform set_config('request.jwt.claim.sub', other_actor::text, true);
  select * into result from public.release_execution_operation(operation_id);
  if to_jsonb(result) is distinct from to_jsonb(nonexistent_result) then
    raise exception 'Wrong actor response disclosed protected operation details or was inconsistent';
  end if;
  if not exists (select 1 from public.execution_attempts ea
      join public.execution_operations eo on eo.operation_id = ea.operation_id
      where ea.operation_id = test_block.operation_id
      and ea.actor_id = test_block.other_actor and eo.actor_id = test_block.actor
      and ea.authority_id = test_block.authority_id
      and ea.decision_id = test_block.decision_id and ea.status = 'rejected'
      and ea.action = 'notify' and ea.scope = 'test' and ea.target = 'sink'
      and ea.parameters = '{"k":1}'::jsonb and ea.correlation_id = test_block.correlation
      and eo.action = ea.action and eo.scope = ea.scope and eo.target = ea.target
      and eo.parameters = ea.parameters) then
    raise exception 'Wrong actor attempt audit context was inconsistent';
  end if;
  select ea.id into internal_attempt_id from public.execution_attempts ea
  where ea.operation_id = test_block.operation_id and ea.actor_id = test_block.other_actor
    and ea.authority_id = test_block.authority_id and ea.decision_id = test_block.decision_id
    and ea.status = 'rejected' and ea.correlation_id = test_block.correlation;
  if internal_attempt_id is null then raise exception 'Wrong actor internal audit attempt was missing'; end if;
  test_attempt_ids := array_append(test_attempt_ids, internal_attempt_id);

  perform set_config('request.jwt.claim.sub', actor::text, true);
  -- An operation already past authorization is rejected with the same bound context.
  operation_id := gen_random_uuid();
  insert into public.execution_operations(operation_id, authority_id, decision_id, actor_id, action, scope, target, parameters, status)
  values (operation_id, authority_id, decision_id, actor, 'notify', 'test', 'sink', '{"k":1}', 'execution_started');
  select * into result from public.release_execution_operation(operation_id);
  test_attempt_ids := array_append(test_attempt_ids, result.attempt_id);
  if result.status <> 'rejected' or result.authorized or result.attempt_id is null
     or result.operation_id is distinct from operation_id or result.valid_until is null
     or result.rejection_reason <> 'Execution operation is not releasable' then
    raise exception 'Already released operation rejection was inconsistent';
  end if;

  -- Revoked and expired authorities each produce an auditable rejection.
  authority_id := gen_random_uuid(); operation_id := gen_random_uuid();
  insert into public.execution_authorities(id, decision_id, actor_id, action, scope, target, parameters, valid_from, valid_until, correlation_id, revoked_at)
  values (authority_id, decision_id, actor, 'notify', 'test', 'sink', '{"k":1}', now() - interval '1 hour', now() + interval '1 hour', correlation, now());
  insert into public.execution_operations(operation_id, authority_id, decision_id, actor_id, action, scope, target, parameters)
  values (operation_id, authority_id, decision_id, actor, 'notify', 'test', 'sink', '{"k":1}');
  select * into result from public.release_execution_operation(operation_id);
  test_attempt_ids := array_append(test_attempt_ids, result.attempt_id);
  if result.status <> 'rejected' or result.rejection_reason <> 'Execution authority has been revoked'
     or result.attempt_id is null or result.valid_from is null then raise exception 'Revocation rejection was inconsistent'; end if;

  authority_id := gen_random_uuid(); operation_id := gen_random_uuid();
  insert into public.execution_authorities(id, decision_id, actor_id, action, scope, target, parameters, valid_from, valid_until, correlation_id)
  values (authority_id, decision_id, actor, 'notify', 'test', 'sink', '{"k":1}', now() - interval '2 hours', now() - interval '1 hour', correlation);
  insert into public.execution_operations(operation_id, authority_id, decision_id, actor_id, action, scope, target, parameters)
  values (operation_id, authority_id, decision_id, actor, 'notify', 'test', 'sink', '{"k":1}');
  select * into result from public.release_execution_operation(operation_id);
  test_attempt_ids := array_append(test_attempt_ids, result.attempt_id);
  if result.status <> 'rejected' or result.rejection_reason <> 'Execution authority has expired'
     or result.attempt_id is null or result.valid_until is null then raise exception 'Expiry rejection was inconsistent'; end if;

  select count(*) into attempt_count from public.execution_attempts ea
  where ea.id = any (test_attempt_ids);
  if attempt_count <> 4 then raise exception 'Expected four persisted rejection attempts, got %', attempt_count; end if;
end;
$test$;
rollback;
