create or replace function public.get_judgment_draft_for_review_cycle(
  target_review_cycle_id uuid
)
returns public.judgment_drafts
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  draft_row public.judgment_drafts%rowtype;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  select jd.*
  into draft_row
  from public.review_cycles rc
  join public.proposals p
    on p.id = rc.proposal_id
  join public.judgment_drafts jd
    on jd.id = rc.judgment_draft_id
  where rc.id = target_review_cycle_id
    and (
      p.proposer_actor_id = current_actor
      or rc.reviewer_actor_id = current_actor
    );

  if draft_row.id is null then
    raise exception 'Judgment Draft not found or access denied';
  end if;

  return draft_row;
end;
$$;

revoke execute on function public.get_judgment_draft_for_review_cycle(uuid)
from public, anon;

grant execute on function public.get_judgment_draft_for_review_cycle(uuid)
to authenticated;

alter function public.get_judgment_draft_for_review_cycle(uuid)
owner to postgres;
