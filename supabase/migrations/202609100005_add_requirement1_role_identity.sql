alter table public.proposals
add column if not exists proposer_actor_id uuid
references auth.users(id);

alter table public.review_cycles
add column if not exists reviewer_actor_id uuid
references auth.users(id);

alter table public.review_cycles
add column if not exists confirmed_by_actor_id uuid
references auth.users(id);

alter table public.review_cycles
add column if not exists confirmed_at timestamptz;

create index if not exists proposals_proposer_actor_id_idx
on public.proposals(proposer_actor_id);

create index if not exists review_cycles_reviewer_actor_id_idx
on public.review_cycles(reviewer_actor_id);

create index if not exists review_cycles_confirmed_by_actor_id_idx
on public.review_cycles(confirmed_by_actor_id);
