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

  search_query := to_tsquery(
    'english',
    array_to_string(
      tsvector_to_array(
        to_tsvector('english', target_context)
      ),
      ' | '
    )
  );

  return query
  with candidates as (
    select
      ju.id as judgment_unit_row_id,
      ju.judgment_unit_id,
      ju.title,
      ju.department,
      ju.status,
      ju.situation,
      ju.problem,
      ju.chosen_option,
      ts_rank_cd(
        setweight(to_tsvector('english', coalesce(ju.title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(ju.situation, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(ju.problem, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(ju.rationale, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(ju.assumptions, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(ju.accepted_risks, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(ju.chosen_option, '')), 'B'),
        search_query
      ) as relevance_score,
      ju.seq_num as sort_sequence,
      null::timestamptz as committed_at
    from public.judgment_units ju
    where ju.deleted = false
      and (
        nullif(trim(target_department), '') is null
        or ju.department ilike '%' || trim(target_department) || '%'
      )
      and (
        setweight(to_tsvector('english', coalesce(ju.title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(ju.situation, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(ju.problem, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(ju.rationale, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(ju.assumptions, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(ju.accepted_risks, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(ju.chosen_option, '')), 'B')
      ) @@ search_query

    union all

    select
      j.id as judgment_unit_row_id,
      j.judgment_unit_id,
      j.title,
      null::text as department,
      'canonical'::text as status,
      j.situation,
      j.problem,
      j.chosen_option,
      ts_rank_cd(
        setweight(to_tsvector('english', coalesce(j.title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(j.situation, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(j.problem, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(j.rationale, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(j.assumptions, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(j.accepted_risks, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(j.chosen_option, '')), 'B'),
        search_query
      ) as relevance_score,
      null::bigint as sort_sequence,
      j.committed_at
    from public.judgments j
    where
      (
        setweight(to_tsvector('english', coalesce(j.title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(j.situation, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(j.problem, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(j.rationale, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(j.assumptions, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(j.accepted_risks, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(j.chosen_option, '')), 'B')
      ) @@ search_query
  )
  select
    c.judgment_unit_row_id,
    c.judgment_unit_id,
    c.title,
    c.department,
    c.status,
    c.situation,
    c.problem,
    c.chosen_option,
    c.relevance_score
  from candidates c
  order by c.relevance_score desc,
           c.committed_at desc nulls last,
           c.sort_sequence desc nulls last
  limit safe_limit;
end;
$$;

revoke execute on function public.retrieve_judgment_units(text, text, integer)
from public, anon;

grant execute on function public.retrieve_judgment_units(text, text, integer)
to authenticated;

alter function public.retrieve_judgment_units(text, text, integer) owner to postgres;
