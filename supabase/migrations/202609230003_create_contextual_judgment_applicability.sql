create table if not exists public.contextual_judgment_applicability (
  id uuid primary key default gen_random_uuid(),

  candidate_id uuid not null
    references public.contextual_retrieval_candidates(id)
    on delete cascade,

  applicability text not null
    check (applicability in ('apply', 'adapt', 'reject')),

  actor_id uuid not null
    references auth.users(id),

  rationale text not null,

  adaptation_evidence jsonb,

  decided_at timestamptz not null default now(),

  correlation_id uuid not null,

  causation_id uuid,

  created_at timestamptz not null default now(),

  unique (candidate_id),
  unique (correlation_id)
);

create index if not exists contextual_judgment_applicability_candidate_idx
  on public.contextual_judgment_applicability (candidate_id);

create index if not exists contextual_judgment_applicability_actor_idx
  on public.contextual_judgment_applicability (actor_id);

create or replace function public.record_contextual_judgment_applicability(
  target_candidate_id uuid,
  target_applicability text,
  target_rationale text,
  target_adaptation_evidence jsonb default null,
  target_correlation_id uuid default null,
  target_causation_id uuid default null
)
returns table (
  applicability_id uuid,
  candidate_id uuid,
  applicability text,
  applicability_actor uuid,
  correlation_id uuid
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  existing_applicability public.contextual_judgment_applicability%rowtype;
  new_applicability_id uuid;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  if target_applicability not in ('apply', 'adapt', 'reject') then
    raise exception 'Invalid applicability';
  end if;

  if nullif(trim(target_rationale), '') is null then
    raise exception 'Applicability rationale is required';
  end if;

  if target_correlation_id is null then
    raise exception 'Correlation ID is required';
  end if;

  if target_applicability = 'adapt' and target_adaptation_evidence is null then
    raise exception 'Adaptation evidence is required';
  end if;

  if not exists (
    select 1
    from public.contextual_retrieval_candidates crc
    where crc.id = target_candidate_id
  ) then
    raise exception 'Contextual retrieval candidate not found';
  end if;

  select *
  into existing_applicability
  from public.contextual_judgment_applicability cja
  where cja.candidate_id = target_candidate_id;

  if found then
    if existing_applicability.correlation_id = target_correlation_id then
      return query
      select
        existing_applicability.id,
        existing_applicability.candidate_id,
        existing_applicability.applicability,
        existing_applicability.actor_id,
        existing_applicability.correlation_id;

      return;
    end if;

    raise exception 'Applicability already recorded for this candidate';
  end if;

  insert into public.contextual_judgment_applicability (
    candidate_id,
    applicability,
    actor_id,
    rationale,
    adaptation_evidence,
    decided_at,
    correlation_id,
    causation_id
  )
  values (
    target_candidate_id,
    target_applicability,
    current_actor,
    target_rationale,
    target_adaptation_evidence,
    now(),
    target_correlation_id,
    target_causation_id
  )
  returning id into new_applicability_id;

  return query
  select
    new_applicability_id,
    target_candidate_id,
    target_applicability,
    current_actor,
    target_correlation_id;
end;
$$;

revoke execute on function public.record_contextual_judgment_applicability(
  uuid,
  text,
  text,
  jsonb,
  uuid,
  uuid
) from public, anon;

grant execute on function public.record_contextual_judgment_applicability(
  uuid,
  text,
  text,
  jsonb,
  uuid,
  uuid
) to authenticated;

alter function public.record_contextual_judgment_applicability(
  uuid,
  text,
  text,
  jsonb,
  uuid,
  uuid
) owner to postgres;
