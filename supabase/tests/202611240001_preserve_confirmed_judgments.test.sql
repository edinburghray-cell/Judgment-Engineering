-- Run after migrations 202611240001 and 202611250001 against a Supabase test database.
-- All fixture rows are rolled back; this never changes persistent test data.
begin;

create temporary table _je_immutability_test_ids (
  actor_id uuid not null,
  judgment_id uuid not null,
  event_id uuid,
  evidence_id uuid
) on commit drop;

do $test$
declare
  actor uuid;
  original_id uuid := gen_random_uuid();
  next_id uuid := gen_random_uuid();
  second_successor_id uuid := gen_random_uuid();
  independent_id uuid := gen_random_uuid();
  event_id uuid;
  evidence_id uuid;
  available_evidence_id uuid;
  unknown_availability_id uuid;
  history_count integer;
  original_hash text;
  proposal_id uuid := gen_random_uuid();
  proposal_version_id uuid := gen_random_uuid();
  first_cycle_id uuid := gen_random_uuid();
  second_cycle_id uuid := gen_random_uuid();
  first_draft_id uuid := gen_random_uuid();
  second_draft_id uuid := gen_random_uuid();
  confirmed_id uuid;
  repeated_id uuid;
  superseding_id uuid;
  returned_actor uuid;
  returned_at timestamptz;
  rpc_count integer;
begin
  select id into actor from auth.users order by created_at limit 1;
  if actor is null then raise exception 'Test requires one auth.users fixture'; end if;

  insert into public.judgments(
    id, title, situation, problem, assumptions, evidence, committing_actor,
    authority_context, committed_at, judgment_version, predecessor_judgment_id
  ) values (
    original_id, 'Immutable test judgment', 'Test situation', 'Test problem',
    'Assumption at confirmation', '[{"label":"snapshot evidence"}]'::jsonb,
    actor, 'Migration test confirmation', clock_timestamp(), 1, null
  );

  select confirmed_content_hash into original_hash
  from public.judgments where id = original_id;
  if original_hash is null or length(original_hash) <> 64
     or not public.verify_judgment_content_hash(original_id) then
    raise exception 'Confirmed judgment hash missing or invalid';
  end if;

  if has_table_privilege('authenticated', 'public.judgments', 'INSERT')
     or has_table_privilege('authenticated', 'public.judgments', 'UPDATE')
     or has_table_privilege('authenticated', 'public.judgments', 'DELETE')
     or has_table_privilege('authenticated', 'public.judgments', 'TRUNCATE')
     or has_table_privilege('authenticated', 'public.judgments', 'REFERENCES')
     or has_table_privilege('authenticated', 'public.judgments', 'TRIGGER')
     or has_table_privilege('service_role', 'public.judgments', 'INSERT')
     or has_table_privilege('service_role', 'public.judgments', 'UPDATE')
     or has_table_privilege('service_role', 'public.judgments', 'DELETE')
     or has_table_privilege('service_role', 'public.judgments', 'TRUNCATE')
     or has_table_privilege('service_role', 'public.judgments', 'REFERENCES')
     or has_table_privilege('service_role', 'public.judgments', 'TRIGGER') then
    raise exception 'Authenticated or service_role has direct judgment mutation privileges';
  end if;
  if has_table_privilege('service_role', 'public.judgment_evidence', 'INSERT')
     or has_table_privilege('service_role', 'public.judgment_evidence', 'UPDATE')
     or has_table_privilege('service_role', 'public.judgment_evidence', 'DELETE')
     or has_table_privilege('service_role', 'public.judgment_evidence', 'TRUNCATE')
     or has_table_privilege('service_role', 'public.judgment_evidence', 'REFERENCES')
     or has_table_privilege('service_role', 'public.judgment_evidence', 'TRIGGER')
     or has_function_privilege('service_role', 'public.record_judgment_evidence(uuid,text,text,timestamptz,timestamptz,uuid,text,jsonb,uuid,uuid,boolean,text,boolean)', 'EXECUTE') then
    raise exception 'service_role can mutate evidence through direct grants or its recording RPC';
  end if;
  if not has_function_privilege('authenticated', 'public.confirm_review_cycle_judgment(uuid,text,uuid,boolean,text,text,text)', 'EXECUTE')
     or has_function_privilege('service_role', 'public.confirm_review_cycle_judgment(uuid,text,uuid,boolean,text,text,text)', 'EXECUTE') then
    raise exception 'Confirmation RPC execution grants do not match the assigned-reviewer boundary';
  end if;
  if (select r.rolname <> 'postgres' or not p.prosecdef
      from pg_proc p join pg_roles r on r.oid = p.proowner
      where p.oid = 'public.confirm_review_cycle_judgment(uuid,text,uuid,boolean,text,text,text)'::regprocedure) then
    raise exception 'Confirmation RPC is not SECURITY DEFINER owned by postgres';
  end if;
  if not exists (
      select 1 from pg_trigger t
      where t.tgrelid = 'public.judgments'::regclass
        and t.tgname = 'judgments_seal_confirmed'
        and not t.tgisinternal
  ) then
    raise exception 'Expected judgments_seal_confirmed trigger is missing from public.judgments';
  end if;
  if (select r.rolname <> 'postgres'
      from pg_trigger t join pg_proc p on p.oid = t.tgfoid
      join pg_roles r on r.oid = p.proowner
      where t.tgrelid = 'public.judgments'::regclass and t.tgname = 'judgments_seal_confirmed' and not t.tgisinternal) then
    raise exception 'Judgment immutability trigger function has unexpected ownership';
  end if;
  perform set_config('request.jwt.claim.sub', actor::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', actor::text, 'role', 'authenticated')::text, true);

  begin
    update public.judgments set title = 'tampered' where id = original_id;
    raise exception 'Confirmed judgment update unexpectedly succeeded';
  exception when sqlstate '55000' then null;
  end;
  begin
    delete from public.judgments where id = original_id;
    raise exception 'Confirmed judgment delete unexpectedly succeeded';
  exception when sqlstate '55000' then null;
  end;
  begin
    update public.judgments set confirmed_by_actor_id = gen_random_uuid() where id = original_id;
    raise exception 'Confirmed judgment actor unexpectedly changed';
  exception when sqlstate '55000' then null;
  end;
  begin
    update public.judgments set confirmed_at = confirmed_at + interval '1 second' where id = original_id;
    raise exception 'Confirmed judgment timestamp unexpectedly changed';
  exception when sqlstate '55000' then null;
  end;
  begin
    update public.judgments set authority_context = 'Retrospective authority' where id = original_id;
    raise exception 'Authority Context was retrospectively changed';
  exception when sqlstate '55000' then null;
  end;
  if not exists (select 1 from public.judgments where id = original_id and title = 'Immutable test judgment') then
    raise exception 'Confirmed judgment content changed';
  end if;

  perform set_config('request.jwt.claim.sub', actor::text, true);
  event_id := public.record_judgment_event(original_id, 'reassessment', 'Changed circumstances', '{"reason":"test"}'::jsonb);
  perform public.record_judgment_retrospective(original_id, 'Partial', 'One assumption held', 'One assumption failed', null, null, 'Test guidance');
  evidence_id := public.record_judgment_evidence(
    original_id, 'Evidence entered after confirmation with an earlier creation date',
    'Test source', (select confirmed_at - interval '1 day' from public.judgments where id = original_id),
    null, event_id, 'subsequent', '{"confidence":"unverified"}'::jsonb,
    null, null, null, null, null
  );

  if not exists (
    select 1 from public.judgment_evidence
    where id = evidence_id and existed_before_decision is null
      and introduced_after_confirmation is true
      and available_to_decision_maker is null
  ) then raise exception 'Earlier evidence creation timestamp was incorrectly treated as proof of prior existence or availability'; end if;

  available_evidence_id := public.record_judgment_evidence(
    original_id, 'Known decision-time evidence', 'Test source',
    (select confirmed_at - interval '2 days' from public.judgments where id = original_id),
    (select confirmed_at - interval '1 day' from public.judgments where id = original_id),
    null, 'decision_time', '{"confidence":"corroborated"}'::jsonb,
    null, null, true, 'Reviewer attests that this source was reviewed before confirmation', true
  );
  if not exists (
    select 1 from public.judgment_evidence
    where id = available_evidence_id and existed_before_decision is true
      and available_to_decision_maker is true
      and availability_attested_by = actor
      and availability_attestation is not null
      and availability_attested_at >= entered_at
      and availability_attested_at > (select confirmed_at from public.judgments where id = original_id)
      and availability_attested_at <= clock_timestamp()
  ) then raise exception 'Attested decision-time evidence was not preserved'; end if;

  begin
    update public.judgment_evidence set description = 'tampered' where id = available_evidence_id;
    raise exception 'Evidence update unexpectedly succeeded';
  exception when sqlstate '55000' then null;
  end;
  begin
    delete from public.judgment_evidence where id = available_evidence_id;
    raise exception 'Evidence delete unexpectedly succeeded';
  exception when sqlstate '55000' then null;
  end;

  if exists (select 1 from public.judgment_evidence where id = available_evidence_id and availability_attested_at is null) then
    raise exception 'Database attestation timestamp was not recorded';
  end if;

  unknown_availability_id := public.record_judgment_evidence(
    original_id, 'Decision-time evidence with unknown availability', 'Test source',
    (select confirmed_at - interval '3 days' from public.judgments where id = original_id),
    (select confirmed_at - interval '2 days' from public.judgments where id = original_id),
    null, 'unknown', null, null, null, null, null
  );
  if not exists (
    select 1 from public.judgment_evidence
    where id = unknown_availability_id and existed_before_decision is null
      and available_to_decision_maker is null
      and availability_attestation is null and availability_attested_by is null
  ) then raise exception 'Unknown decision-time availability was not preserved as unknown'; end if;

  -- The earlier creation and acquisition timestamps are recorded, but do not
  -- establish prior existence or availability without an explicit claim.
  if not exists (
    select 1 from public.judgment_evidence
    where id = unknown_availability_id and evidence_created_at is not null
      and evidence_created_at < (select confirmed_at from public.judgments where id = original_id)
      and obtained_at < (select confirmed_at from public.judgments where id = original_id)
      and existed_before_decision is null
      and available_to_decision_maker is null
      and availability_attested_at is null
  ) then raise exception 'Evidence dates were conflated with prior existence'; end if;

  begin
    perform public.record_judgment_evidence(
      original_id, 'False availability claim', 'Test source',
      (select confirmed_at + interval '1 day' from public.judgments where id = original_id),
      null, null, 'decision_time', null, null, null, true,
      'Claimed available despite being created later'
    );
    raise exception 'False availability claim unexpectedly succeeded';
  exception when others then
    if sqlerrm = 'False availability claim unexpectedly succeeded' then raise; end if;
  end;

  begin
    perform public.record_judgment_evidence(
      original_id, 'Unattested availability claim', 'Test source',
      (select confirmed_at - interval '1 day' from public.judgments where id = original_id),
      null, null, 'decision_time', null, null, null, true, null
    );
    raise exception 'Unattested availability claim unexpectedly succeeded';
  exception when others then
    if sqlerrm = 'Unattested availability claim unexpectedly succeeded' then raise; end if;
  end;

  select count(*) into history_count from public.judgment_events where judgment_id = original_id;
  if history_count < 3 then raise exception 'Subsequent event or retrospective was not stored separately'; end if;

  insert into public.judgments(
    id, title, committing_actor, authority_context, committed_at,
    predecessor_judgment_id, judgment_version
  ) values (
    next_id, 'Superseding test judgment', actor, 'Migration test confirmation',
    clock_timestamp(), original_id, 2
  );
  if not exists (select 1 from public.judgments where id = original_id)
     or not exists (select 1 from public.judgments where id = next_id and predecessor_judgment_id = original_id) then
    raise exception 'Superseding judgment did not preserve predecessor';
  end if;
  if not public.verify_judgment_content_hash(original_id) then
    raise exception 'Supersession modified the predecessor hash';
  end if;

  -- Exercise the actual unique partial index: a second successor must fail,
  -- while a separate Judgment with no predecessor remains valid.
  begin
    insert into public.judgments(
      id, title, committing_actor, authority_context, committed_at,
      predecessor_judgment_id, judgment_version
    ) values (
      second_successor_id, 'Second successor must fail', actor,
      'Migration test confirmation', clock_timestamp(), original_id, 2
    );
    raise exception 'A second successor for one predecessor unexpectedly succeeded';
  exception when unique_violation then
    null;
  end;
  insert into public.judgments(
    id, title, committing_actor, authority_context, committed_at,
    predecessor_judgment_id, judgment_version
  ) values (
    independent_id, 'Independent test judgment', actor,
    'Migration test confirmation', clock_timestamp(), null, 1
  );
  if not exists (select 1 from public.judgments where id = independent_id and predecessor_judgment_id is null)
     or not exists (select 1 from public.judgments where id = original_id and title = 'Immutable test judgment')
     or not public.verify_judgment_content_hash(original_id) then
    raise exception 'Independent or supersession relationship altered the original judgment';
  end if;

  -- Exercise the production reviewer RPC with its actual workflow tables and
  -- structured draft state. Fixture setup is privileged; confirmation is not.
  insert into public.proposals(id, proposer_actor_id) values (proposal_id, actor);
  insert into public.proposal_versions(
    id, proposal_id, version_number, change_id, scope, affected_system,
    environment, assumptions, alternatives, evidence, known_risks, decision_class
  ) values (
    proposal_version_id, proposal_id, 1, 'CHUNK1-TEST', 'Test scope',
    'judgment-engine', 'test', 'Test assumptions', '["Option A"]'::jsonb,
    '["Reference"]'::jsonb, 'Test risks', 'ai_system_change_approval'
  );
  insert into public.judgment_drafts(
    id, title, situation, problem, options, rationale, assumptions, evidence,
    accepted_risks, success_metrics, chosen_option, rejected_options,
    decision_owner, capture_actor, authority_context, status
  ) values
    (first_draft_id, 'RPC confirmed judgment', 'Situation', 'Problem', '["A"]',
     'Rationale', 'Assumptions', '["Evidence"]', 'Risks', 'Metrics', 'A', '[]',
     'Decision Owner A', actor, 'RPC test first cycle', 'structured_unconfirmed'),
    (second_draft_id, 'RPC superseding judgment', 'Changed situation', 'Changed problem', '["B"]',
     'New rationale', 'New assumptions', '["New evidence"]', 'New risks', 'New metrics', 'B', '[]',
     'Decision Owner B', actor, 'RPC test second cycle', 'structured_unconfirmed');
  insert into public.review_cycles(id, proposal_version_id, status, judgment_draft_id, reviewer_actor_id)
  values
    (first_cycle_id, proposal_version_id, 'structured_unconfirmed', first_draft_id, actor),
    (second_cycle_id, proposal_version_id, 'structured_unconfirmed', second_draft_id, actor);

  select judgment_id, confirmed_by_actor_id, confirmed_at
  into confirmed_id, returned_actor, returned_at
  from public.confirm_review_cycle_judgment(
    first_cycle_id, 'Reconsider if assumptions fail', null, false, null, null,
    'Assigned reviewer under the documented proposal review mandate'
  );
  if confirmed_id is null or returned_actor <> actor or returned_at is null then
    raise exception 'Assigned reviewer RPC did not confirm the structured draft';
  end if;
  if not exists (
    select 1 from public.judgments
    where id = confirmed_id and title = 'RPC confirmed judgment'
      and committing_actor = actor and confirmed_by_actor_id = actor
      and capture_actor = actor and decision_owner = 'Decision Owner A'
      and authority_context = 'Assigned reviewer under the documented proposal review mandate'
      and confirmed_at = returned_at and confirmed_content_hash is not null
      and public.verify_judgment_content_hash(id)
  ) then raise exception 'RPC did not create a valid canonical judgment with confirmation provenance'; end if;

  select judgment_id into repeated_id
  from public.confirm_review_cycle_judgment(
    first_cycle_id, 'Reconsider if assumptions fail', null, false, null, null,
    'Conflicting later context must not replace the committed basis'
  );
  if repeated_id <> confirmed_id then raise exception 'Repeated confirmation did not return the canonical judgment'; end if;
  select count(*) into rpc_count from public.judgments
  where id = confirmed_id
    and authority_context = 'Assigned reviewer under the documented proposal review mandate';
  if rpc_count <> 1 then raise exception 'Repeated confirmation created a duplicate judgment or overwrote Authority Context'; end if;

  select judgment_id into superseding_id
  from public.confirm_review_cycle_judgment(
    second_cycle_id, 'Reconsider after validation', confirmed_id, true,
    'Materially changed test context', 'Validated against the updated test basis',
    'Assigned reviewer under the documented proposal review mandate'
  );
  if not exists (
    select 1 from public.judgments where id = superseding_id
      and predecessor_judgment_id = confirmed_id
      and confirmed_by_actor_id = actor and confirmed_content_hash is not null
      and public.verify_judgment_content_hash(id)
  ) or not exists (select 1 from public.judgments where id = confirmed_id) then
    raise exception 'RPC supersession failed to retain its predecessor';
  end if;
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'judgments_single_successor_idx'
  ) then raise exception 'Single-successor boundary index is missing'; end if;

  insert into _je_immutability_test_ids(actor_id, judgment_id, event_id, evidence_id)
  values (actor, original_id, event_id, evidence_id);
end;
$test$;

rollback;
