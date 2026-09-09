alter table public.judgment_transfers
add column if not exists status text;

update public.judgment_transfers
set status = 'completed'
where status is null;

alter table public.judgment_transfers
alter column status set default 'completed';

alter table public.judgment_transfers
alter column status set not null;
