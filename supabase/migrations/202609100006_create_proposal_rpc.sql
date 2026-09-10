create or replace function public.create_proposal(
  target_change_id text,
  target_scope text,
  target_affected_system text,
  target_environment text,
  target_assumptions text,
  target_alternatives jsonb,
  target_evidence jsonb,
  target_known_risks text
)
returns table (
  proposal_id uuid,
  proposal_version_id uuid,
  review_cycle_id uuid
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  new_proposal_id uuid;
  new_proposal_version_id uuid;
  new_review_cycle_id uuid;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  if nullif(trim(target_change_id), '') is null then
    raise exception 'Change ID is required';
  end if;

  if nullif(trim(target_scope), '') is null then
    raise exception 'Scope is required';
  end if;

  if nullif(trim(target_affected_system), '') is null then
    raise exception 'Affected system is required';
  end if;

  if nullif(trim(target_environment), '') is null then
    raise exception 'Environment is required';
  end if;

  if nullif(trim(target_assumptions), '') is null then
    raise exception 'Assumptions are required';
  end if;

  if target_alternatives is null
     or jsonb_typeof(target_alternatives) <> 'array'
     or jsonb_array_length(target_alternatives) = 0 then
    raise exception 'At least one alternative is required';
  end if;

  if target_evidence is null
     or jsonb_typeof(target_evidence) <> 'array'
     or jsonb_array_length(target_evidence) = 0 then
    raise exception 'At least one evidence reference is required';
  end if;

  if nullif(trim(target_known_risks), '') is null then
    raise exception 'Known risks are required';
  end if;

  insert into public.proposals (
    proposer_actor_id
  )
  values (
    current_actor
  )
  returning id into new_proposal_id;

  insert into public.proposal_versions (
    proposal_id,
    version_number,
    change_id,
    scope,
    affected_system,
    environment,
    assumptions,
    alternatives,
    evidence,
    known_risks
  )
  values (
    new_proposal_id,
    1,
    trim(target_change_id),
    trim(target_scope),
    trim(target_affected_system),
    trim(target_environment),
    trim(target_assumptions),
    target_alternatives,
    target_evidence,
    trim(target_known_risks)
  )
  returning id into new_proposal_version_id;

  insert into public.review_cycles (
    proposal_version_id,
    status
  )
  values (
    new_proposal_version_id,
    'reviewable'
  )
  returning id into new_review_cycle_id;

  return query
  select
    new_proposal_id,
    new_proposal_version_id,
    new_review_cycle_id;
end;
$$;

revoke execute on function public.create_proposal(
  text,
  text,
  text,
  text,
  text,
  jsonb,
  jsonb,
  text
) from public, anon;

grant execute on function public.create_proposal(
  text,
  text,
  text,
  text,
  text,
  jsonb,
  jsonb,
  text
) to authenticated;

alter function public.create_proposal(
  text,
  text,
  text,
  text,
  text,
  jsonb,
  jsonb,
  text
) owner to postgres;
