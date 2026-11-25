begin;

create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;

alter table public.judgments
  add column if not exists confirmed_by_actor_id uuid references auth.users(id),
  add column if not exists confirmed_at timestamptz,
  add column if not exists confirmed_content_hash text;

update public.judgments
set confirmed_by_actor_id = committing_actor,
    confirmed_at = committed_at
where confirmed_by_actor_id is null or confirmed_at is null;

create or replace function private.judgment_content_hash(target_judgment public.judgments)
returns text
language sql
immutable
set search_path = ''
as $function$
  select encode(extensions.digest(convert_to(jsonb_build_object(
    'id', (target_judgment).id,
    'judgment_unit_id', (target_judgment).judgment_unit_id,
    'judgment_version', (target_judgment).judgment_version,
    'title', (target_judgment).title,
    'situation', (target_judgment).situation,
    'problem', (target_judgment).problem,
    'options', (target_judgment).options,
    'rationale', (target_judgment).rationale,
    'assumptions', (target_judgment).assumptions,
    'evidence', (target_judgment).evidence,
    'accepted_risks', (target_judgment).accepted_risks,
    'success_metrics', (target_judgment).success_metrics,
    'chosen_option', (target_judgment).chosen_option,
    'rejected_options', (target_judgment).rejected_options,
    'decision_owner', (target_judgment).decision_owner,
    'capture_actor', (target_judgment).capture_actor,
    'committing_actor', (target_judgment).committing_actor,
    'authority_context', (target_judgment).authority_context,
    'committed_at', (target_judgment).committed_at,
    'confirmed_by_actor_id', (target_judgment).confirmed_by_actor_id,
    'confirmed_at', (target_judgment).confirmed_at,
    'predecessor_judgment_id', (target_judgment).predecessor_judgment_id,
    'reconsideration_conditions', (target_judgment).reconsideration_conditions
  )::text, 'UTF8'), 'sha256'), 'hex');
$function$;

create or replace function private.seal_confirmed_judgment()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if tg_op = 'INSERT' then
    -- Canonical judgments are created only by the confirmation RPC. Derive
    -- their confirmation identity from the existing authoritative fields.
    new.confirmed_by_actor_id := new.committing_actor;
    new.confirmed_at := new.committed_at;
    new.confirmed_content_hash := private.judgment_content_hash(new);
    return new;
  end if;

  raise exception 'Confirmed judgments are immutable; record a subsequent event or superseding judgment'
    using errcode = '55000';
end;
$function$;

alter function private.seal_confirmed_judgment() owner to postgres;
revoke all on function private.seal_confirmed_judgment() from public, anon, authenticated, service_role;
revoke all on function private.judgment_content_hash(public.judgments) from public, anon, authenticated, service_role;
grant execute on function private.judgment_content_hash(public.judgments) to authenticated;

update public.judgments j
set confirmed_content_hash = private.judgment_content_hash(j)
where confirmed_content_hash is null;

alter table public.judgments
  alter column confirmed_by_actor_id set not null,
  alter column confirmed_at set not null,
  alter column confirmed_content_hash set not null,
  add constraint judgments_confirmed_content_hash_check
    check (confirmed_content_hash ~ '^[0-9a-f]{64}$');

drop trigger if exists judgments_seal_confirmed on public.judgments;
create trigger judgments_seal_confirmed
  before insert or update or delete on public.judgments
  for each row execute function private.seal_confirmed_judgment();

revoke insert, update, delete, truncate, references, trigger
  on public.judgments from public, anon, authenticated, service_role;

-- Authenticated callers continue to use the assigned-reviewer confirmation
-- SECURITY DEFINER RPC; its table owner can perform the canonical INSERT.
revoke insert, update, delete, truncate, references, trigger
  on public.judgments from authenticated;

-- Keep confirmation available only to signed-in callers; service_role has no
-- ordinary SQL or RPC route for mutating canonical judgments.
revoke all on function public.confirm_review_cycle_judgment(uuid, text, uuid, boolean, text, text)
  from public, anon, service_role;
grant execute on function public.confirm_review_cycle_judgment(uuid, text, uuid, boolean, text, text)
  to authenticated;
alter function public.confirm_review_cycle_judgment(uuid, text, uuid, boolean, text, text)
  owner to postgres;

create or replace function public.verify_judgment_content_hash(target_judgment_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = public, private, pg_temp
as $function$
  select j.confirmed_content_hash = private.judgment_content_hash(j)
  from public.judgments j
  where j.id = target_judgment_id;
$function$;
revoke all on function public.verify_judgment_content_hash(uuid) from public, anon, service_role;
grant execute on function public.verify_judgment_content_hash(uuid) to authenticated;

-- Preserve the existing append-only event model while supporting the remaining
-- subsequent-history categories in the same stream.
alter table public.judgment_events
  drop constraint if exists judgment_events_event_type_check;
alter table public.judgment_events
  add constraint judgment_events_event_type_check check (event_type = any (array[
    'approval'::text, 'implementation'::text, 'evidence_added'::text,
    'assumption_failed'::text, 'challenge'::text, 'retrospective'::text,
    'context_discovered'::text, 'human_confirmed'::text, 'decision'::text,
    'supersession'::text, 'outcome_evidence'::text, 'reassessment'::text
  ]));

create table if not exists public.judgment_evidence (
  id uuid primary key default gen_random_uuid(),
  judgment_id uuid references public.judgments(id) on delete restrict,
  judgment_event_id uuid references public.judgment_events(id) on delete restrict,
  description text not null,
  source_or_producer text,
  recorded_by uuid references auth.users(id),
  evidence_created_at timestamptz,
  obtained_at timestamptz,
  entered_at timestamptz not null default now(),
  existed_before_decision boolean,
  available_to_decision_maker boolean,
  availability_attestation text,
  availability_attested_by uuid references auth.users(id),
  availability_attested_at timestamptz,
  introduced_after_confirmation boolean,
  evidence_category text not null default 'unknown'
    check (evidence_category in ('decision_time', 'subsequent', 'execution_outcome', 'unknown')),
  reliability_assessment jsonb,
  challenged_by_event_id uuid references public.judgment_events(id) on delete restrict,
  supersedes_evidence_id uuid references public.judgment_evidence(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint judgment_evidence_single_subject_check check (
    (judgment_id is not null)::integer + (judgment_event_id is not null)::integer = 1
  ),
  constraint judgment_evidence_available_requires_decision_time check (
    available_to_decision_maker is distinct from true or evidence_category = 'decision_time'
  )
);

create index if not exists judgment_evidence_judgment_idx on public.judgment_evidence(judgment_id);
create index if not exists judgment_evidence_event_idx on public.judgment_evidence(judgment_event_id);
alter table public.judgment_evidence enable row level security;
revoke all on public.judgment_evidence from public, anon, authenticated, service_role;

create or replace function private.seal_judgment_evidence()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  decision_at timestamptz;
  parent_judgment_id uuid;
begin
  if tg_op <> 'INSERT' then
    raise exception 'Evidence provenance is append-only; add a challenge or superseding evidence record'
      using errcode = '55000';
  end if;

  -- Entry time is set by the database, never trusted from the caller.
  new.entered_at := clock_timestamp();

  if new.judgment_id is not null then
    select confirmed_at into decision_at from public.judgments where id = new.judgment_id;
  else
    select judgment_id into parent_judgment_id from public.judgment_events where id = new.judgment_event_id;
    select confirmed_at into decision_at from public.judgments where id = parent_judgment_id;
  end if;

  if decision_at is null then
    raise exception 'Evidence must reference an existing confirmed judgment or its event';
  end if;

  new.introduced_after_confirmation := new.entered_at > decision_at;
  -- Availability and prior existence are explicit claims, not conclusions
  -- drawn from creation/acquisition dates. A known later creation date is a
  -- hard veto on classifying an item as pre-decision evidence.
  if new.evidence_created_at > decision_at then
    new.existed_before_decision := false;
  end if;
  if new.available_to_decision_maker is true then
    if new.evidence_category <> 'decision_time'
       or new.existed_before_decision is distinct from true
       or nullif(trim(new.availability_attestation), '') is null
       or new.availability_attested_by is null then
      raise exception 'Available decision-time evidence requires pre-confirmation existence and an attributable attestation';
    end if;
    -- This timestamp records when the database received an attributable
    -- attestation; it is not independent evidence that availability occurred.
    new.availability_attested_at := clock_timestamp();
  elsif new.availability_attestation is not null or new.availability_attested_by is not null then
    raise exception 'Availability attestation must accompany an explicit true availability claim';
  else
    new.availability_attested_at := null;
  end if;
  if new.evidence_category = 'decision_time'
     and new.existed_before_decision is distinct from true then
    raise exception 'Evidence created after confirmation cannot be classified as decision-time evidence';
  end if;
  if new.evidence_category = 'execution_outcome' and new.judgment_event_id is null then
    raise exception 'Execution outcome evidence must attach to a subsequent event';
  end if;
  return new;
end;
$function$;
alter function private.seal_judgment_evidence() owner to postgres;
revoke all on function private.seal_judgment_evidence() from public, anon, authenticated, service_role;
create trigger judgment_evidence_seal
  before insert or update or delete on public.judgment_evidence
  for each row execute function private.seal_judgment_evidence();

grant select on public.judgment_evidence to authenticated;
create policy judgment_evidence_read_by_judgment_access
  on public.judgment_evidence for select to authenticated
  using (
    (judgment_id is not null and private.can_read_judgment(judgment_id))
    or (judgment_event_id is not null and exists (
      select 1 from public.judgment_events e
      where e.id = judgment_event_id and private.can_read_judgment(e.judgment_id)
    ))
  );

create or replace function public.record_judgment_event(
  target_judgment_id uuid,
  target_event_type text,
  target_description text,
  target_payload jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  current_actor uuid := auth.uid();
  event_id uuid;
begin
  if current_actor is null then raise exception 'Authentication required'; end if;
  if target_event_type not in (
    'approval', 'implementation', 'evidence_added', 'assumption_failed',
    'challenge', 'context_discovered', 'outcome_evidence', 'reassessment'
  ) then raise exception 'Unsupported subsequent judgment event type'; end if;
  if nullif(trim(target_description), '') is null then raise exception 'Event description is required'; end if;
  if not exists (
    select 1 from public.judgments j where j.id = target_judgment_id
      and current_actor in (j.capture_actor, j.committing_actor)
  ) then raise exception 'Actor is not authorized to record an event for this Judgment'; end if;

  insert into public.judgment_events(judgment_id, event_type, actor, description, payload)
  values (target_judgment_id, target_event_type, current_actor, trim(target_description),
    coalesce(target_payload, '{}'::jsonb))
  returning id into event_id;
  return event_id;
end;
$function$;
revoke all on function public.record_judgment_event(uuid, text, text, jsonb) from public, anon, service_role;
grant execute on function public.record_judgment_event(uuid, text, text, jsonb) to authenticated;
alter function public.record_judgment_event(uuid, text, text, jsonb) owner to postgres;

drop function if exists public.record_judgment_evidence(
  uuid, text, text, timestamptz, timestamptz, uuid, text, jsonb, uuid, uuid, boolean, text
);
create or replace function public.record_judgment_evidence(
  target_judgment_id uuid,
  target_description text,
  target_source_or_producer text default null,
  target_evidence_created_at timestamptz default null,
  target_obtained_at timestamptz default null,
  target_judgment_event_id uuid default null,
  target_evidence_category text default 'unknown',
  target_reliability_assessment jsonb default null,
  target_challenged_by_event_id uuid default null,
  target_supersedes_evidence_id uuid default null,
  target_available_to_decision_maker boolean default null,
  target_availability_attestation text default null,
  target_existed_before_decision boolean default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  current_actor uuid := auth.uid();
  evidence_id uuid;
begin
  if current_actor is null then raise exception 'Authentication required'; end if;
  if nullif(trim(target_description), '') is null then raise exception 'Evidence description is required'; end if;
  if target_evidence_category not in ('decision_time', 'subsequent', 'execution_outcome', 'unknown') then
    raise exception 'Unsupported evidence category';
  end if;
  if not exists (
    select 1 from public.judgments j where j.id = target_judgment_id
      and current_actor in (j.capture_actor, j.committing_actor)
  ) then raise exception 'Actor is not authorized to record evidence for this Judgment'; end if;
  if target_judgment_event_id is not null and not exists (
    select 1 from public.judgment_events e
    where e.id = target_judgment_event_id and e.judgment_id = target_judgment_id
  ) then raise exception 'Evidence event must belong to the referenced Judgment'; end if;
  if target_challenged_by_event_id is not null and not exists (
    select 1 from public.judgment_events e
    where e.id = target_challenged_by_event_id and e.judgment_id = target_judgment_id
  ) then raise exception 'Challenge event must belong to the referenced Judgment'; end if;
  if target_supersedes_evidence_id is not null and not exists (
    select 1 from public.judgment_evidence prior
    where prior.id = target_supersedes_evidence_id
      and coalesce(prior.judgment_id, (select judgment_id from public.judgment_events where id = prior.judgment_event_id)) = target_judgment_id
  ) then raise exception 'Superseded evidence must belong to the referenced Judgment'; end if;
  if target_available_to_decision_maker is true
     and nullif(trim(target_availability_attestation), '') is null then
    raise exception 'Availability requires an explicit attestation';
  end if;

  insert into public.judgment_evidence(
    judgment_id, judgment_event_id, description, source_or_producer,
    recorded_by, evidence_created_at, obtained_at, evidence_category,
    reliability_assessment, challenged_by_event_id, supersedes_evidence_id,
    available_to_decision_maker, availability_attestation, availability_attested_by,
    existed_before_decision
  ) values (
    case when target_judgment_event_id is null then target_judgment_id else null end,
    target_judgment_event_id, trim(target_description), target_source_or_producer,
    current_actor, target_evidence_created_at, target_obtained_at, target_evidence_category,
    target_reliability_assessment, target_challenged_by_event_id, target_supersedes_evidence_id,
    target_available_to_decision_maker,
    case when target_available_to_decision_maker is true then trim(target_availability_attestation) end,
    case when target_available_to_decision_maker is true then current_actor end,
    target_existed_before_decision
  ) returning id into evidence_id;
  return evidence_id;
end;
$function$;
revoke all on function public.record_judgment_evidence(uuid, text, text, timestamptz, timestamptz, uuid, text, jsonb, uuid, uuid, boolean, text, boolean) from public, anon, service_role;
grant execute on function public.record_judgment_evidence(uuid, text, text, timestamptz, timestamptz, uuid, text, jsonb, uuid, uuid, boolean, text, boolean) to authenticated;
alter function public.record_judgment_evidence(uuid, text, text, timestamptz, timestamptz, uuid, text, jsonb, uuid, uuid, boolean, text, boolean) owner to postgres;

commit;
