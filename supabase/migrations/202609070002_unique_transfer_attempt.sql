create unique index if not exists judgment_transfers_attempt_id_unique_idx
on public.judgment_transfers(attempt_id)
where attempt_id is not null;
