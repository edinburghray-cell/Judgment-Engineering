alter table public.judgment_drafts enable row level security;

revoke all on table public.judgment_drafts from anon, authenticated;
