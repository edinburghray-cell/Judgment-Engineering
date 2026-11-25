create or replace function public.get_contextual_retrieval_candidate(
  target_candidate_id uuid
)
returns table (
  retrieval_id uuid,
  request_id uuid,
  candidate_id uuid,
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
begin
  if current_actor is null then
    raise exception 'authentication_required';
  end if;

  return query
  select
    c.retrieval_id,
    r.request_id,
    c.id,
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
  where c.id = target_candidate_id
    and (
      p.proposer_actor_id = current_actor
      or rc.reviewer_actor_id = current_actor
      or rc.decision_maker_actor_id = current_actor
    );
end;
$$;

revoke execute on function public.get_contextual_retrieval_candidate(uuid)
  from public, anon;

grant execute on function public.get_contextual_retrieval_candidate(uuid)
  to authenticated;

alter function public.get_contextual_retrieval_candidate(uuid)
  owner to postgres;
