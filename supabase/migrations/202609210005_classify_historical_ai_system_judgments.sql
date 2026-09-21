-- Milestone X: classify confirmed historical AI-system-change Judgments.
-- Only records whose existing proposal context establishes the decision class
-- are enriched. Other historical records remain NULL.

update public.proposal_versions
set decision_class = 'ai_system_change_approval'
where change_id in (
  'REQ1-E2E-002',
  'REQ1-E2E-004',
  'JE-AI-REVIEW-001',
  'JE-AI-REVIEW-002',
  'JE-AI-REVIEW-003',
  'Create JE-AI-REVIEW-004.',
  'M4-TEST-002-CHANGE'
)
and decision_class is null
and exists (
  select 1
  from public.review_cycles rc
  join public.judgments j
    on j.id = rc.confirmed_judgment_id
  where rc.proposal_version_id = public.proposal_versions.id
);

comment on column public.proposal_versions.decision_class is
  'Decision class for the proposal version. Historical records may remain NULL when their original workflow does not establish a reliable classification.';
