alter table public.proposals enable row level security;
alter table public.proposal_versions enable row level security;
alter table public.review_cycles enable row level security;
alter table public.decisions enable row level security;
alter table public.workflow_audit enable row level security;

revoke all on table public.proposals from anon, authenticated;
revoke all on table public.proposal_versions from anon, authenticated;
revoke all on table public.review_cycles from anon, authenticated;
revoke all on table public.decisions from anon, authenticated;
revoke all on table public.workflow_audit from anon, authenticated;
