alter table public.judgment_events
drop constraint judgment_events_event_type_check;

alter table public.judgment_events
add constraint judgment_events_event_type_check
check (
  event_type = any (
    array[
      'approval'::text,
      'implementation'::text,
      'evidence_added'::text,
      'assumption_failed'::text,
      'challenge'::text,
      'retrospective'::text,
      'context_discovered'::text,
      'human_confirmed'::text
    ]
  )
);
