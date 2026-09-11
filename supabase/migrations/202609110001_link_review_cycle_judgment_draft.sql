alter table public.review_cycles
add column if not exists judgment_draft_id uuid
references public.judgment_drafts(id);

create unique index if not exists review_cycles_judgment_draft_id_unique
on public.review_cycles(judgment_draft_id)
where judgment_draft_id is not null;
