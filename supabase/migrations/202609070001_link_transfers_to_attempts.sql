alter table public.judgment_transfers
add column if not exists attempt_id uuid
references public.transfer_attempts(id);

create index if not exists judgment_transfers_attempt_id_idx
on public.judgment_transfers(attempt_id);
