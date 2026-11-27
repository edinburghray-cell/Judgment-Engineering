-- Run after migration 202611260001 against a Supabase test database.
-- Fixture rows are created inside this transaction and rolled back at the end.
begin;

do $test$
declare
  reader_a uuid;
  reader_b uuid;
  unit_a uuid := gen_random_uuid();
  unit_b uuid := gen_random_uuid();
  judgment_a uuid := gen_random_uuid();
  judgment_b uuid := gen_random_uuid();
  proposal_a uuid := gen_random_uuid();
  proposal_b uuid := gen_random_uuid();
  cycle_a uuid := gen_random_uuid();
  cycle_b uuid := gen_random_uuid();
  decision_a uuid := gen_random_uuid();
  decision_b uuid := gen_random_uuid();
  result jsonb;
begin
  select id into reader_a from auth.users order by created_at limit 1;
  select id into reader_b from auth.users where id <> reader_a order by created_at limit 1;
  if reader_a is null or reader_b is null then
    raise exception 'Test requires two auth.users fixtures';
  end if;

  -- SQL test setup runs as the database owner. Capture creates each unit and
  -- its explicit can_read grant through the existing trigger.
  perform set_config('request.jwt.claim.sub', reader_a::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', reader_a::text, 'role', 'authenticated')::text, true);
  insert into public.judgment_units (id, title, status, capture_actor)
  values (unit_a, 'Lifecycle history authorization fixture A', 'Proposed', reader_a);
  perform set_config('request.jwt.claim.sub', reader_b::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', reader_b::text, 'role', 'authenticated')::text, true);
  insert into public.judgment_units (id, title, status, capture_actor)
  values (unit_b, 'Lifecycle history authorization fixture B', 'Proposed', reader_b);

  insert into public.judgments (
    id, title, committing_actor, authority_context, committed_at
  ) values
    (judgment_a, 'Lifecycle history judgment A', reader_a,
     'Lifecycle history authorization test', clock_timestamp()),
    (judgment_b, 'Lifecycle history judgment B', reader_b,
     'Lifecycle history authorization test', clock_timestamp());

  insert into public.judgment_unit_judgments (
    judgment_unit_id, judgment_id, associated_by
  ) values
    (unit_a, judgment_a, reader_a),
    (unit_b, judgment_b, reader_b);

  insert into public.proposals (id) values (proposal_a), (proposal_b);
  insert into public.proposal_versions (
    id, proposal_id, version_number, change_id, scope, affected_system, environment
  )
  values
    (cycle_a, proposal_a, 1, 'LIFECYCLE-TEST-A', 'fixture scope A', 'judgment-engine', 'test'),
    (cycle_b, proposal_b, 1, 'LIFECYCLE-TEST-B', 'fixture scope B', 'judgment-engine', 'test');

  insert into public.review_cycles (id, proposal_version_id, status, confirmed_judgment_id)
  values
    (cycle_a, cycle_a, 'human_confirmed', judgment_a),
    (cycle_b, cycle_b, 'human_confirmed', judgment_b);

  insert into public.decisions (
    id, review_cycle_id, decision, actor_id, authority_basis,
    correlation_id, rationale
  ) values
    (decision_a, cycle_a, 'approve', reader_a, 'Test fixture authority', gen_random_uuid(), 'A only'),
    (decision_b, cycle_b, 'defer', reader_b, 'Test fixture authority', gen_random_uuid(), 'B only');

  if not private.can_read_judgment(judgment_a, reader_a)
     or private.can_read_judgment(judgment_a, reader_b)
     or not private.can_read_judgment(judgment_b, reader_b)
     or private.can_read_judgment(judgment_b, reader_a) then
    raise exception 'Fixture read grants do not match the intended Judgment mapping';
  end if;

  -- Authorized actor A receives its decision through the canonical cycle link.
  perform set_config('request.jwt.claim.sub', reader_a::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', reader_a::text, 'role', 'authenticated')::text, true);
  result := public.get_judgment_lifecycle_history(judgment_a);
  if jsonb_array_length(result->'decisions') <> 1
     or result->'decisions'->0->>'id' <> decision_a::text
     or result->'decisions'->0->>'review_cycle_id' <> cycle_a::text then
    raise exception 'Authorized reader did not receive exactly Judgment A lifecycle data';
  end if;
  if result->'decisions' @> jsonb_build_array(jsonb_build_object('id', decision_b::text))
     or result->'decisions'::text like '%' || decision_b::text || '%' then
    raise exception 'Judgment A response contains Judgment B lifecycle data';
  end if;

  -- The actor with a grant only for B cannot read A; the RPC must raise rather
  -- than return even partial protected lifecycle data.
  perform set_config('request.jwt.claim.sub', reader_b::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', reader_b::text, 'role', 'authenticated')::text, true);
  begin
    result := public.get_judgment_lifecycle_history(judgment_a);
    raise exception 'Unauthorized reader unexpectedly received lifecycle history: %', result;
  exception when others then
    if sqlerrm = 'Unauthorized reader unexpectedly received lifecycle history: ' || result::text then raise; end if;
    if sqlerrm not like 'Judgment not found or access denied%' then raise; end if;
  end;

  -- Actor A cannot obtain B's record by asking for A: only A's linked decision
  -- is returned, despite both Judgments having populated lifecycle fixtures.
  perform set_config('request.jwt.claim.sub', reader_a::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', reader_a::text, 'role', 'authenticated')::text, true);
  result := public.get_judgment_lifecycle_history(judgment_a);
  if jsonb_array_length(result->'decisions') <> 1
     or result->'decisions'->0->>'id' <> decision_a::text
     or result->'decisions'::text like '%' || decision_b::text || '%' then
    raise exception 'Cross-Judgment isolation failed for actor authorized only for A';
  end if;
  if result->'authorities' <> '[]'::jsonb
     or result->'operations' <> '[]'::jsonb
     or result->'attempts' <> '[]'::jsonb
     or result->'runs' <> '[]'::jsonb
     or result->'execution_evidence' <> '[]'::jsonb then
    raise exception 'Unexpected lifecycle records appeared without canonical fixture relationships';
  end if;

  -- No JWT subject represents an unauthenticated request and must be rejected.
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  begin
    result := public.get_judgment_lifecycle_history(judgment_a);
    raise exception 'Unauthenticated request unexpectedly received lifecycle history: %', result;
  exception when others then
    if sqlerrm like 'Unauthenticated request unexpectedly received lifecycle history:%' then raise; end if;
    if sqlerrm not like 'Authentication required%' then raise; end if;
  end;
end;
$test$;

rollback;
