-- Milestone X: contextual retrieval foundation
-- Context Query -> bounded historical Judgment candidates.
-- Retrieval relevance is not applicability or decision authority.

create table if not exists public.contextual_retrievals (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique,
  source_system text not null,
  workflow text not null,
  decision_class text not null,
  context_query jsonb not null,
  provenance jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  created_by_actor uuid not null
);

create index if not exists contextual_retrievals_created_by_actor_idx
  on public.contextual_retrievals (created_by_actor);

create index if not exists contextual_retrievals_decision_class_idx
  on public.contextual_retrievals (decision_class);

create table if not exists public.contextual_retrieval_candidates (
  id uuid primary key default gen_random_uuid(),
  retrieval_id uuid not null
    references public.contextual_retrievals(id)
    on delete cascade,
  judgment_id uuid not null
    references public.judgments(id),
  rank integer not null check (rank > 0),
  relevance_score real not null check (relevance_score >= 0),
  matched_factors jsonb not null default '[]'::jsonb,
  material_differences jsonb not null default '[]'::jsonb,
  historical_status text not null,
  created_at timestamptz not null default now(),
  unique (retrieval_id, judgment_id),
  unique (retrieval_id, rank)
);

create index if not exists contextual_retrieval_candidates_retrieval_idx
  on public.contextual_retrieval_candidates (retrieval_id, rank);

create index if not exists contextual_retrieval_candidates_judgment_idx
  on public.contextual_retrieval_candidates (judgment_id);

alter table public.contextual_retrievals enable row level security;
alter table public.contextual_retrieval_candidates enable row level security;

revoke all on public.contextual_retrievals from anon, authenticated;
revoke all on public.contextual_retrieval_candidates from anon, authenticated;

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
  target_search_text text;
  target_query tsquery;
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

  target_search_text := concat_ws(
    ' ',
    target_context ->> 'workflow',
    target_context ->> 'decision_class',
    target_context ->> 'proposed_change',
    target_context ->> 'intended_outcome',
    target_context ->> 'affected_system_scope',
    target_context ->> 'current_trigger',
    array_to_string(
      array(
        select jsonb_array_elements_text(
          coalesce(target_context -> 'constraints', '[]'::jsonb)
        )
      ),
      ' '
    ),
    array_to_string(
      array(
        select jsonb_array_elements_text(
          coalesce(target_context -> 'relevant_evidence', '[]'::jsonb)
        )
      ),
      ' '
    ),
    array_to_string(
      array(
        select jsonb_array_elements_text(
          coalesce(target_context -> 'known_risks', '[]'::jsonb)
        )
      ),
      ' '
    ),
    target_context ->> 'workflow_state'
  );

  target_query := plainto_tsquery('english', target_search_text);

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
      (
        setweight(to_tsvector('english', coalesce(j.title, '')), 'A') ||
        setweight(to_tsvector('english', concat_ws(
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
        )), 'B')
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
      ts_rank_cd(h.search_vector, target_query) +
      case
        when nullif(trim(target_context ->> 'affected_system_scope'), '') is not null
         and lower(coalesce(h.affected_system, '')) =
             lower(trim(target_context ->> 'affected_system_scope'))
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
      end as score
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
              when nullif(trim(target_context ->> 'affected_system_scope'), '') is not null
               and lower(coalesce(e.affected_system, '')) =
                   lower(trim(target_context ->> 'affected_system_scope'))
              then jsonb_build_object(
                'factor', 'affected_system_scope',
                'type', 'evidence',
                'value', e.affected_system
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
              when nullif(trim(target_context ->> 'affected_system_scope'), '') is not null
               and lower(coalesce(e.affected_system, '')) <>
                   lower(trim(target_context ->> 'affected_system_scope'))
              then jsonb_build_object(
                'factor', 'affected_system_scope',
                'type', 'difference',
                'historical', e.affected_system,
                'current', target_context ->> 'affected_system_scope'
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


