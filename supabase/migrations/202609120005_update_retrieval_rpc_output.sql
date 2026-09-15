drop function if exists public.retrieve_judgment_units(text, text, integer);

create or replace function public.retrieve_judgment_units(
  target_context text,
  target_department text default null,
  result_limit integer default 10
)
returns table (
  judgment_unit_row_id uuid,
  judgment_unit_id text,
  title text,
  department text,
  status text,
  situation text,
  problem text,
  chosen_option text,
  relevance_score real
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  search_query tsquery;
  safe_limit integer;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  if nullif(trim(target_context), '') is null then
    raise exception 'Retrieval context is required';
  end if;

  safe_limit := least(greatest(coalesce(result_limit, 10), 1), 25);

  search_query := plainto_tsquery('english', target_context);

  return query
  select
    ju.id,
    ju.judgment_unit_id,
    ju.title,
    ju.department,
    ju.status,
    ju.situation,
    ju.problem,
    ju.chosen_option,
    ts_rank_cd(
      to_tsvector(
        'english',
        concat_ws(
          ' ',
          ju.title,
          ju.situation,
          ju.problem,
          ju.rationale,
          ju.assumptions,
          ju.accepted_risks,
          ju.chosen_option
        )
      ),
      search_query
    ) as relevance_score
  from public.judgment_units ju
  where ju.deleted = false
    and (
      nullif(trim(target_department), '') is null
      or ju.department ilike '%' || trim(target_department) || '%'
    )
    and to_tsvector(
      'english',
      concat_ws(
        ' ',
        ju.title,
        ju.situation,
        ju.problem,
        ju.rationale,
        ju.assumptions,
        ju.accepted_risks,
        ju.chosen_option
      )
    ) @@ search_query
  order by relevance_score desc, ju.seq_num desc
  limit safe_limit;
end;
$$;

revoke execute on function public.retrieve_judgment_units(text, text, integer)
from public, anon;

grant execute on function public.retrieve_judgment_units(text, text, integer)
to authenticated;

alter function public.retrieve_judgment_units(text, text, integer) owner to postgres;
