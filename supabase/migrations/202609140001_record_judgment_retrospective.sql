create or replace function public.record_judgment_retrospective(
  target_judgment_id uuid,
  target_outcome_status text,
  target_assumptions_confirmed text,
  target_assumptions_invalidated text,
  target_unexpected_risks text,
  target_next_time_changes text,
  target_future_decision_guidance text
)
returns table (
  retrospective_event_id uuid,
  judgment_id uuid
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  target_judgment public.judgments%rowtype;
  new_event_id uuid;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  if target_outcome_status not in ('Success', 'Partial', 'Failure') then
    raise exception 'Invalid outcome status';
  end if;

  if nullif(trim(target_future_decision_guidance), '') is null then
    raise exception 'Future decision guidance is required';
  end if;

  select *
  into target_judgment
  from public.judgments
  where id = target_judgment_id
  for share;

  if not found then
    raise exception 'Judgment not found';
  end if;

  if current_actor <> target_judgment.capture_actor
     and current_actor <> target_judgment.committing_actor then
    raise exception 'Actor is not authorized to record a retrospective for this Judgment';
  end if;

  insert into public.judgment_events (
    judgment_id,
    event_type,
    actor,
    description,
    payload
  )
  values (
    target_judgment_id,
    'retrospective',
    current_actor,
    'Retrospective recorded against preserved Judgment.',
    jsonb_build_object(
      'outcome_status', target_outcome_status,
      'assumptions_confirmed', target_assumptions_confirmed,
      'assumptions_invalidated', target_assumptions_invalidated,
      'unexpected_risks', target_unexpected_risks,
      'next_time_changes', target_next_time_changes,
      'inheritance', jsonb_build_object(
        'future_decision_guidance', target_future_decision_guidance
      ),
      'judgment_unit_id', target_judgment.judgment_unit_id
    )
  )
  returning id into new_event_id;

  return query
  select
    new_event_id,
    target_judgment_id;
end;
$$;

revoke execute on function public.record_judgment_retrospective(
  uuid,
  text,
  text,
  text,
  text,
  text,
  text
)
from public, anon;

grant execute on function public.record_judgment_retrospective(
  uuid,
  text,
  text,
  text,
  text,
  text,
  text
)
to authenticated;

alter function public.record_judgment_retrospective(
  uuid,
  text,
  text,
  text,
  text,
  text,
  text
) owner to postgres;
