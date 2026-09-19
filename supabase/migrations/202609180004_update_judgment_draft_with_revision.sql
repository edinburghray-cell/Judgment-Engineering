create or replace function public.update_judgment_draft_with_revision(
  target_judgment_draft_id uuid,
  target_field text,
  target_corrected_value jsonb,
  target_correction_reason text,
  target_correlation_id uuid default gen_random_uuid()
)
returns public.judgment_drafts
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  draft_row public.judgment_drafts%rowtype;
  current_review_cycle_id uuid;
  original_value jsonb;
  updated_draft public.judgment_drafts%rowtype;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  if target_field not in (
    'title',
    'situation',
    'problem',
    'options',
    'rationale',
    'assumptions',
    'evidence',
    'accepted_risks',
    'success_metrics',
    'chosen_option',
    'rejected_options',
    'decision_owner'
  ) then
    raise exception 'Unsupported Judgment Draft field';
  end if;

  if nullif(trim(target_correction_reason), '') is null then
    raise exception 'Correction reason is required';
  end if;

  select jd.*
  into draft_row
  from public.judgment_drafts jd
  where jd.id = target_judgment_draft_id
  for update;

  if not found then
    raise exception 'Judgment Draft not found';
  end if;

  if draft_row.status <> 'structured_unconfirmed' then
    raise exception 'Judgment Draft can only be corrected while structured_unconfirmed';
  end if;

  select rc.id
  into current_review_cycle_id
  from public.review_cycles rc
  where rc.judgment_draft_id = target_judgment_draft_id
    and rc.status = 'structured_unconfirmed'
    and rc.reviewer_actor_id = current_actor
  for update;

  if current_review_cycle_id is null then
    raise exception 'Only the assigned reviewer can correct this Judgment Draft';
  end if;

  original_value := to_jsonb(draft_row) -> target_field;

  if original_value = target_corrected_value then
    return draft_row;
  end if;

  if target_field in ('options', 'evidence', 'rejected_options') then
    execute format(
      'update public.judgment_drafts
       set %I = $1,
           updated_at = now()
       where id = $2
       returning *',
      target_field
    )
    using target_corrected_value, target_judgment_draft_id
    into updated_draft;
  else
    execute format(
      'update public.judgment_drafts
       set %I = $1,
           updated_at = now()
       where id = $2
       returning *',
      target_field
    )
    using target_corrected_value #>> '{}', target_judgment_draft_id
    into updated_draft;
  end if;

  insert into public.judgment_draft_revisions (
    judgment_draft_id,
    actor_id,
    field,
    original_value,
    corrected_value,
    correction_reason,
    correlation_id
  )
  values (
    target_judgment_draft_id,
    current_actor,
    target_field,
    original_value,
    target_corrected_value,
    target_correction_reason,
    target_correlation_id
  );

  return updated_draft;
end;
$$;

revoke execute on function public.update_judgment_draft_with_revision(
  uuid,
  text,
  jsonb,
  text,
  uuid
) from public, anon;

grant execute on function public.update_judgment_draft_with_revision(
  uuid,
  text,
  jsonb,
  text,
  uuid
) to authenticated;

alter function public.update_judgment_draft_with_revision(
  uuid,
  text,
  jsonb,
  text,
  uuid
) owner to postgres;
