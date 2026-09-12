alter table public.decisions
add column if not exists confirmed_judgment_id uuid
references public.judgments(id);

create index if not exists decisions_confirmed_judgment_id_idx
on public.decisions(confirmed_judgment_id);

alter table public.review_cycles
drop constraint if exists review_cycles_status_check;

alter table public.review_cycles
add constraint review_cycles_status_check
check (
  status = any (
    array[
      'draft'::text,
      'reviewable'::text,
      'structured_unconfirmed'::text,
      'human_confirmed'::text,
      'decided'::text,
      'preserved_complete'::text
    ]
  )
);
