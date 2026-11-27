-- Recovered baseline definition from JE-schema-recovery.sql.
create table public.judgment_events (
  id uuid default gen_random_uuid() not null,
  judgment_id uuid not null,
  event_type text not null,
  created_at timestamptz default now() not null,
  actor uuid,
  description text not null,
  payload jsonb,
  constraint judgment_events_pkey primary key (id),
  constraint judgment_events_event_type_check check (event_type = any (array[
    'approval'::text, 'implementation'::text, 'evidence_added'::text,
    'assumption_failed'::text, 'challenge'::text, 'retrospective'::text,
    'context_discovered'::text, 'human_confirmed'::text, 'decision'::text,
    'supersession'::text
  ])),
  constraint judgment_events_actor_fkey foreign key (actor) references auth.users(id),
  constraint judgment_events_judgment_id_fkey foreign key (judgment_id) references public.judgments(id)
);
