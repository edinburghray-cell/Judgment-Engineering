alter table public.review_cycles
add column if not exists decision_maker_actor_id uuid
references auth.users(id);

create index if not exists review_cycles_decision_maker_actor_id_idx
on public.review_cycles(decision_maker_actor_id);
