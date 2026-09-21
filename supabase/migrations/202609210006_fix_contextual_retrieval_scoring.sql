-- Milestone X: contextual retrieval scoring correction.
-- Context dimensions contribute independently to relevance.
-- No single historical Judgment must contain every current-context field.

create or replace function public.retrieve_contextual_judgments(
  target_context jsonb,
  result_limit integer default 5
)
returns table (
  retrieval_id uuid,
  request_id uuid,
  judgment_id uuid,
  decision_class text,
  historical_context jsonb,
  judgment_summary text,
  relevance jsonb,
  scope jsonb,
  historical_status text,
  provenance jsonb,
  relationships jsonb,
  applicability_history jsonb
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid := auth.uid();
  safe_limit integer;
  target_request_id uuid;
  target_source_system text;
  target_workflow text;
  target_decision_class text;
  target_occurred_at timestamptz;
  target_proposed_change text;
  target_intended_outcome text;
  target_affected_system_scope text;
  target_current_trigger text;
  target_workflow_state text;
  target_query_proposed_change tsquery;
  target_query_intended_outcome tsquery;
  target_query_affected_scope tsquery;
  target_query_trigger tsquery;
  target_query_workflow tsquery;
  target_query_constraints tsquery;
  target_query_evidence tsquery;
  target_query_risks tsquery;
  new_retrieval_id uuid;
begin
  if current_actor is null then
    raise exception 'authentication_required';
  end if;

  if target_context is null
     or jsonb_typeof(target_context) <> 'object' then
    raise exception 'context_query_must_be_object';
  end if;

  target_request_id := (target_context ->> 'request_id')::uuid;
  target_source_system := coalesce(nullif(trim(target_context ->> 'source_system'), ''), 'lumos');
  target_workflow := nullif(trim(target_context ->> 'workflow'), '');
  target_decision_class := nullif(trim(target_context ->> 'decision_class'), '');
  target_occurred_at := (target_context ->> 'occurred_at')::timestamptz;
  target_proposed_change := nullif(trim(target_context ->> 'proposed_change'), '');
  target_intended_outcome := nullif(trim(target_context ->> 'intended_outcome'), '');
  target_affected_system_scope := nullif(trim(target_context ->> 'affected_system_scope'), '');
  target_current_trigger := nullif(trim(target_context ->> 'current_trigger'), '');
  target_workflow_state := nullif(trim(target_context ->> 'workflow_state'), '');

  if target_request_id is null then
    raise exception 'request_id_required';
  end if;

  if target_workflow is null then
    raise exception 'workflow_required';
  end if;

  if target_decision_class is null then
    raise exception 'decision_class_required';
  end if;

  if target_decision_class <> 'ai_system_change_approval' then
    raise exception 'unsupported_decision_class';
  end if;

  if target_occurred_at is null then
    raise exception 'occurred_at_required';
  end if;

  if jsonb_typeof(coalesce(target_context -> 'constraints', '[]'::jsonb)) <> 'array'
     or jsonb_typeof(coalesce(target_context -> 'relevant_evidence', '[]'::jsonb)) <> 'array'
     or jsonb_typeof(coalesce(target_context -> 'known_risks', '[]'::jsonb)) <> 'array' then
    raise exception 'context_arrays_required';
  end if;

  target_query_proposed_change :=
    case when target_proposed_change is not null
      then plainto_tsquery('english', target_proposed_change)
      else null end;

  target_query_intended_outcome :=
    case when target_intended_outcome is not null
      then plainto_tsquery('english', target_intended_outcome)
      else null end;

  target_query_affected_scope :=
    case when target_affected_system_scope is not null
      then plainto_tsquery('english', target_affected_system_scope)
      else null end;

  target_query_trigger :=
    case when target_current_trigger is not null
      then plainto_tsquery('english', target_current_trigger)
      else null end;

  target_query_workflow :=
    case when target_workflow is not null
      then plainto_tsquery('english', target_workflow)
      else null end;

  target_query_constraints :=
    case
      when jsonb_array_length(coalesce(target_context -> 'constraints', '[]'::jsonb)) > 0
      then plainto_tsquery(
        'english',
        array_to_string(
          array(
            select jsonb_array_elements_text(
              coalesce(target_context -> 'constraints', '[]'::jsonb)
            )
          ),
          ' '
        )
      )
      else null
    end;

  target_query_evidence :=
    case
      when jsonb_array_length(coalesce(target_context -> 'relevant_evidence', '[]'::jsonb)) > 0
      then plainto_tsquery(
        'english',
        array_to_string(
          array(
            select jsonb_array_elements_text(
              coalesce(target_context -> 'relevant_evidence', '[]'::jsonb)
            )
          ),
          ' '
        )
      )
      else null
    end;

  target_query_risks :=
    case
      when jsonb_array_length(coalesce(target_context -> 'known_risks', '[]'::jsonb)) > 0
      then plainto_tsquery(
        'english',
        array_to_string(
          array(
            select jsonb_array_elements_text(
              coalesce(target_context -> 'known_risks', '[]'::jsonb)
            )
          ),
          ' '
        )
      )
      else null
    end;

  insert into public.contextual_retrievals (
    request_id,
    source_system,
    workflow,
    decision_class,
    context_query,
    provenance,
    occurred_at,
    created_by_actor
  )
  values (
    target_request_id,
    target_source_system,
    target_workflow,
    target_decision_class,
    target_context,
    coalesce(target_context -> 'provenance', '{}'::jsonb),
    target_occurred_at,
    current_actor
  )
  returning id into new_retrieval_id;

  safe_limit := greatest(1, least(coalesce(result_limit, 5), 10));

  with historical as (
    select
      j.id as judgment_id,
      j.title,
      j.situation,
      j.problem,
      j.rationale,
      j.assumptions,
      j.evidence,
      j.accepted_risks,
      j.success_metrics,
      j.chosen_option,
      j.rejected_options,
      j.decision_owner,
      j.capture_actor,
      j.committing_actor,
      j.authority_context,
      j.committed_at,
      j.predecessor_judgment_id,
      pv.decision_class,
      pv.scope,
      pv.affected_system,
      pv.environment,
      pv.assumptions as proposal_assumptions,
      pv.evidence as proposal_evidence,
      pv.known_risks as proposal_known_risks,
      p.id as proposal_id,
      pv.id as proposal_version_id,
      rc.id as review_cycle_id,
      setweight(
        to_tsvector('english', coalesce(j.title, '')),
        'A'
      ) ||
      setweight(
        to_tsvector(
          'english',
          concat_ws(
            ' ',
            j.situation,
            j.problem,
            j.rationale,
            j.assumptions,
            j.accepted_risks,
            j.chosen_option,
            pv.scope,
            pv.affected_system,
            pv.environment,
            pv.assumptions,
            pv.known_risks
          )
        ),
        'B'
      ) as search_vector
    from public.judgments j
    join public.review_cycles rc
      on rc.confirmed_judgment_id = j.id
    join public.proposal_versions pv
      on pv.id = rc.proposal_version_id
    join public.proposals p
      on p.id = pv.proposal_id
    where rc.status in ('human_confirmed', 'decided', 'preserved_complete')
      and pv.decision_class = target_decision_class
      and (
        p.proposer_actor_id = current_actor
        or rc.reviewer_actor_id = current_actor
        or rc.decision_maker_actor_id = current_actor
      )
  ),
  scored as (
    select
      h.*,
      (
        coalesce(ts_rank_cd(h.search_vector, target_query_proposed_change), 0) * 1.00 +
        coalesce(ts_rank_cd(h.search_vector, target_query_intended_outcome), 0) * 0.60 +
        coalesce(ts_rank_cd(h.search_vector, target_query_affected_scope), 0) * 0.75 +
        coalesce(ts_rank_cd(h.search_vector, target_query_trigger), 0) * 0.50 +
        coalesce(ts_rank_cd(h.search_vector, target_query_workflow), 0) * 0.35 +
        coalesce(ts_rank_cd(h.search_vector, target_query_constraints), 0) * 0.40 +
        coalesce(ts_rank_cd(h.search_vector, target_query_evidence), 0) * 0.25 +
        coalesce(ts_rank_cd(h.search_vector, target_query_risks), 0) * 0.50 +
        case
          when target_affected_system_scope is not null
           and lower(coalesce(h.affected_system, '')) =
               lower(target_affected_system_scope)
          then 0.25
          else 0
        end +
        case
          when exists (
            select 1
            from jsonb_array_elements_text(
              coalesce(target_context -> 'known_risks', '[]'::jsonb)
            ) risk
            where lower(coalesce(h.proposal_known_risks, '')) like
              '%' || lower(risk) || '%'
          )
          then 0.10
          else 0
        end
      ) as score
    from historical h
  ),
  eligible as (
    select *
    from scored
    where score > 0
    order by score desc, committed_at desc
    limit safe_limit
  )
  insert into public.contextual_retrieval_candidates (
    retrieval_id,
    judgment_id,
    rank,
    relevance_score,
    matched_factors,
    material_differences,
    historical_status
  )
  select
    new_retrieval_id,
    e.judgment_id,
    row_number() over (order by e.score desc, e.committed_at desc),
    e.score,
    coalesce((
      select jsonb_agg(v.value)
      from (
        values
          (
            case
              when lower(coalesce(e.decision_class, '')) =
                   lower(target_decision_class)
              then jsonb_build_object(
                'factor', 'decision_class',
                'type', 'evidence',
                'value', e.decision_class
              )
            end
          ),
          (
            case
              when target_proposed_change is not null
               and target_query_proposed_change is not null
               and e.search_vector @@ target_query_proposed_change
              then jsonb_build_object(
                'factor', 'proposed_change',
                'type', 'evidence',
                'value', target_proposed_change
              )
            end
          ),
          (
            case
              when target_affected_system_scope is not null
               and lower(coalesce(e.affected_system, '')) =
                   lower(target_affected_system_scope)
              then jsonb_build_object(
                'factor', 'affected_system_scope',
                'type', 'evidence',
                'value', e.affected_system
              )
            end
          ),
          (
            case
              when target_intended_outcome is not null
               and target_query_intended_outcome is not null
               and e.search_vector @@ target_query_intended_outcome
              then jsonb_build_object(
                'factor', 'intended_outcome',
                'type', 'evidence',
                'value', target_intended_outcome
              )
            end
          ),
          (
            case
              when target_current_trigger is not null
               and target_query_trigger is not null
               and e.search_vector @@ target_query_trigger
              then jsonb_build_object(
                'factor', 'current_trigger',
                'type', 'evidence',
                'value', target_current_trigger
              )
            end
          )
      ) v(value)
      where v.value is not null
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(v.value)
      from (
        values
          (
            case
              when target_affected_system_scope is not null
               and lower(coalesce(e.affected_system, '')) <>
                   lower(target_affected_system_scope)
              then jsonb_build_object(
                'factor', 'affected_system_scope',
                'type', 'difference',
                'historical', e.affected_system,
                'current', target_affected_system_scope
              )
            end
          ),
          (
            case
              when nullif(trim(target_context ->> 'environment'), '') is not null
               and lower(coalesce(e.environment, '')) <>
                   lower(trim(target_context ->> 'environment'))
              then jsonb_build_object(
                'factor', 'environment',
                'type', 'difference',
                'historical', e.environment,
                'current', target_context ->> 'environment'
              )
            end
          )
      ) v(value)
      where v.value is not null
    ), '[]'::jsonb),
    case
      when exists (
        select 1
        from public.judgment_events je
        where je.event_type = 'supersession'
          and je.payload->>'superseded_judgment_id' = e.judgment_id::text
      )
      then 'superseded'
      else 'preserved'
    end
  from eligible e;

  return query
  select
    c.retrieval_id,
    r.request_id,
    j.id,
    r.decision_class,
    jsonb_build_object(
      'situation', j.situation,
      'problem', j.problem,
      'scope', pv.scope,
      'affected_system', pv.affected_system,
      'environment', pv.environment,
      'assumptions', j.assumptions,
      'evidence', j.evidence,
      'accepted_risks', j.accepted_risks
    ),
    coalesce(j.chosen_option, j.rationale, j.problem),
    jsonb_build_object(
      'score', c.relevance_score,
      'matched_factors', c.matched_factors,
      'material_differences', c.material_differences
    ),
    jsonb_build_object(
      'scope', pv.scope,
      'affected_system', pv.affected_system,
      'environment', pv.environment
    ),
    c.historical_status,
    jsonb_build_object(
      'proposal_id', p.id,
      'proposal_version_id', pv.id,
      'review_cycle_id', rc.id,
      'committed_at', j.committed_at,
      'committing_actor', j.committing_actor
    ),
    jsonb_build_object(
      'predecessor_judgment_id', j.predecessor_judgment_id
    ),
    '[]'::jsonb
  from public.contextual_retrieval_candidates c
  join public.contextual_retrievals r
    on r.id = c.retrieval_id
  join public.judgments j
    on j.id = c.judgment_id
  join public.review_cycles rc
    on rc.confirmed_judgment_id = j.id
  join public.proposal_versions pv
    on pv.id = rc.proposal_version_id
  join public.proposals p
    on p.id = pv.proposal_id
  where c.retrieval_id = new_retrieval_id
  order by c.rank;
end;
$$;

grant execute on function public.retrieve_contextual_judgments(jsonb, integer)
  to authenticated;

alter function public.retrieve_contextual_judgments(jsonb, integer)
  owner to postgres;
