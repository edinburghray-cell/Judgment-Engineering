begin;

-- This is deliberately empty on creation. Existing text identifiers are not
-- evidence that a canonical Judgment belongs to a particular Judgment Unit.
create table if not exists public.judgment_unit_judgments (
  judgment_unit_id uuid primary key
    references public.judgment_units(id) on delete cascade,
  judgment_id uuid not null unique
    references public.judgments(id) on delete cascade,
  associated_at timestamptz not null default now(),
  associated_by uuid references auth.users(id)
);
revoke all privileges on table public.judgment_unit_judgments from public, anon, authenticated;

-- Existing rows remain transfer-only unless a separate read grant is issued.
alter table public.judgment_unit_access
  add column if not exists can_read boolean not null default false;

create schema if not exists private;

create or replace function private.can_read_judgment_unit(target_unit_id uuid, target_actor_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
  select target_actor_id is not null and exists (
    select 1 from public.judgment_unit_access a
    where a.judgment_unit_id = target_unit_id
      and a.actor_id = target_actor_id and a.can_read
  );
$$;

create or replace function private.can_read_judgment(target_judgment_id uuid, target_actor_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
  select target_actor_id is not null and exists (
    select 1 from public.judgment_unit_judgments m
    join public.judgment_unit_access a on a.judgment_unit_id = m.judgment_unit_id
    where m.judgment_id = target_judgment_id
      and a.actor_id = target_actor_id and a.can_read
  );
$$;

revoke all on function private.can_read_judgment_unit(uuid, uuid) from public, anon;
revoke all on function private.can_read_judgment(uuid, uuid) from public, anon;
grant usage on schema private to authenticated, service_role;
grant execute on function private.can_read_judgment_unit(uuid, uuid) to authenticated, service_role;
grant execute on function private.can_read_judgment(uuid, uuid) to authenticated, service_role;

-- Transfer history is authorized by transfer access alone, independently of
-- Judgment Unit read grants and the Judgment Unit SELECT policy.
create or replace function private.can_transfer_judgment_unit_text(target_unit_id text)
returns boolean language sql stable security definer set search_path = '' as $$
  select target_unit_id is not null and exists (
    select 1
    from public.judgment_units u
    join public.judgment_unit_access a on a.judgment_unit_id = u.id
    where u.id::text = target_unit_id
      and a.actor_id = (select auth.uid())
      and a.can_transfer = true
  );
$$;
revoke all on function private.can_transfer_judgment_unit_text(text) from public, anon;
grant execute on function private.can_transfer_judgment_unit_text(text) to authenticated;

-- Apply an additional restrictive SELECT policy so any pre-existing broad
-- permissive policy cannot grant protected reads. No association is backfilled.
alter table public.judgment_units enable row level security;
alter table public.judgments enable row level security;
alter table public.judgment_events enable row level security;
drop policy if exists je_read_units_restricted on public.judgment_units;
drop policy if exists je_read_judgments_restricted on public.judgments;
drop policy if exists je_read_events_restricted on public.judgment_events;
drop policy if exists je_read_units_granted on public.judgment_units;
drop policy if exists je_read_judgments_granted on public.judgments;
drop policy if exists je_read_events_granted on public.judgment_events;
create policy je_read_units_granted on public.judgment_units for select to authenticated using (true);
create policy je_read_units_restricted on public.judgment_units as restrictive for select to authenticated
  using (private.can_read_judgment_unit(id));
create policy je_read_judgments_granted on public.judgments for select to authenticated using (true);
create policy je_read_judgments_restricted on public.judgments as restrictive for select to authenticated
  using (private.can_read_judgment(id));
create policy je_read_events_granted on public.judgment_events for select to authenticated using (true);
create policy je_read_events_restricted on public.judgment_events as restrictive for select to authenticated
  using (private.can_read_judgment(judgment_id));
revoke select on public.judgment_units, public.judgments, public.judgment_events from public, anon, service_role;
grant select on public.judgment_units, public.judgments, public.judgment_events to authenticated;

revoke truncate, references, trigger on table public.judgment_units, public.judgments,
  public.judgment_events, public.judgment_transfers from public, anon, authenticated;

-- A SECURITY DEFINER retrieval RPC must apply the actor's grants explicitly.
alter function public.retrieve_judgment_units(text, text, integer)
  rename to retrieve_judgment_units_unfiltered;
create function public.retrieve_judgment_units(
  target_context text, target_department text default null, result_limit integer default 10
) returns table (
  judgment_unit_row_id uuid, judgment_unit_id text, title text, department text,
  status text, situation text, problem text, chosen_option text, relevance_score real
) language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  return query select r.*
  from public.retrieve_judgment_units_unfiltered(target_context, target_department, result_limit) r
  where case when r.status = 'canonical'
    then private.can_read_judgment(r.judgment_unit_row_id, auth.uid())
    else private.can_read_judgment_unit(r.judgment_unit_row_id, auth.uid()) end;
end;
$$;
revoke execute on function public.retrieve_judgment_units_unfiltered(text, text, integer) from public, anon, authenticated;
revoke execute on function public.retrieve_judgment_units(text, text, integer) from public, anon;
grant execute on function public.retrieve_judgment_units(text, text, integer) to authenticated;
alter function public.retrieve_judgment_units(text, text, integer) owner to postgres;

-- Keep the existing matching/ranking implementation, but filter its returned
-- rows against the mapped actor. The renamed function is no longer callable by
-- API roles. Its candidate records are not directly readable by those roles.
alter function public.retrieve_contextual_judgments(jsonb, integer, uuid)
  rename to retrieve_contextual_judgments_unfiltered;
create function public.retrieve_contextual_judgments(
  target_context jsonb, result_limit integer default 5, target_actor_id uuid default null
) returns table (
  retrieval_id uuid, request_id uuid, candidate_id uuid, judgment_id uuid,
  decision_class text, historical_context jsonb, judgment_summary text,
  relevance jsonb, scope jsonb, historical_status text, provenance jsonb,
  relationships jsonb, applicability_history jsonb
) language plpgsql security definer set search_path = public, pg_temp as $$
declare
  actor uuid := auth.uid();
begin
  if auth.role() = 'service_role' and target_actor_id is not null then actor := target_actor_id; end if;
  if actor is null then raise exception 'authentication_required'; end if;
  return query select r.retrieval_id, r.request_id, r.candidate_id, r.judgment_id,
    r.decision_class, r.historical_context, r.judgment_summary, r.relevance,
    r.scope, r.historical_status, r.provenance, '{}'::jsonb, r.applicability_history
  from public.retrieve_contextual_judgments_unfiltered(target_context, result_limit, actor) r
  where private.can_read_judgment(r.judgment_id, actor);
end;
$$;
revoke execute on function public.retrieve_contextual_judgments_unfiltered(jsonb, integer, uuid) from public, anon, authenticated, service_role;
-- The original two-argument overload predates actor mapping and must not stay
-- callable as a SECURITY DEFINER bypass.
revoke execute on function public.retrieve_contextual_judgments(jsonb, integer) from public, anon, authenticated, service_role;
revoke execute on function public.retrieve_contextual_judgments(jsonb, integer, uuid) from public, anon;
grant execute on function public.retrieve_contextual_judgments(jsonb, integer, uuid) to authenticated, service_role;
alter function public.retrieve_contextual_judgments(jsonb, integer, uuid) owner to postgres;

-- Candidate review is another SECURITY DEFINER return path.
create or replace function public.get_contextual_retrieval_candidate(target_candidate_id uuid)
returns table (
  retrieval_id uuid, request_id uuid, candidate_id uuid, judgment_id uuid,
  decision_class text, historical_context jsonb, judgment_summary text,
  relevance jsonb, scope jsonb, historical_status text, provenance jsonb,
  relationships jsonb, applicability_history jsonb
) language sql security definer set search_path = public, pg_temp as $$
  select c.retrieval_id, r.request_id, c.id, j.id, r.decision_class,
    jsonb_build_object('situation', j.situation, 'problem', j.problem, 'scope', pv.scope,
      'affected_system', pv.affected_system, 'environment', pv.environment,
      'assumptions', j.assumptions, 'evidence', j.evidence, 'accepted_risks', j.accepted_risks),
    coalesce(j.chosen_option, j.rationale, j.problem),
    jsonb_build_object('score', c.relevance_score, 'matched_factors', c.matched_factors,
      'material_differences', c.material_differences),
    jsonb_build_object('scope', pv.scope, 'affected_system', pv.affected_system, 'environment', pv.environment),
    c.historical_status,
    jsonb_build_object('proposal_id', p.id, 'proposal_version_id', pv.id,
      'review_cycle_id', rc.id, 'committed_at', j.committed_at, 'committing_actor', j.committing_actor),
    '{}'::jsonb, '[]'::jsonb
  from public.contextual_retrieval_candidates c
  join public.contextual_retrievals r on r.id = c.retrieval_id
  join public.judgments j on j.id = c.judgment_id
  join public.review_cycles rc on rc.confirmed_judgment_id = j.id
  join public.proposal_versions pv on pv.id = rc.proposal_version_id
  join public.proposals p on p.id = pv.proposal_id
  where c.id = target_candidate_id and auth.uid() is not null
    and (p.proposer_actor_id = auth.uid() or rc.reviewer_actor_id = auth.uid() or rc.decision_maker_actor_id = auth.uid())
    and private.can_read_judgment(j.id, auth.uid());
$$;
revoke execute on function public.get_contextual_retrieval_candidate(uuid) from public, anon;
grant execute on function public.get_contextual_retrieval_candidate(uuid) to authenticated;
alter function public.get_contextual_retrieval_candidate(uuid) owner to postgres;

-- Transfer history stays separate from read grants and is no longer public.
alter table public.judgment_transfers enable row level security;
revoke select on public.judgment_transfers from public, anon, service_role;
grant select on public.judgment_transfers to authenticated;
drop policy if exists je_transfer_history_restricted on public.judgment_transfers;
create policy je_transfer_history_restricted on public.judgment_transfers as restrictive for select to authenticated
  using (private.can_transfer_judgment_unit_text(source_judgment_unit_id));

commit;
