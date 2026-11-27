-- Recovered baseline definitions from JE-schema-recovery.sql.
create table public.sources (
  id uuid default gen_random_uuid() not null,
  label text not null,
  origin_description text,
  originated_at timestamptz,
  created_at timestamptz default now() not null,
  constraint sources_pkey primary key (id)
);

create table public.provenance_links (
  id uuid default gen_random_uuid() not null,
  source_id uuid not null,
  judgment_id uuid,
  event_id uuid,
  evidence_description text,
  linked_at timestamptz default now() not null,
  constraint provenance_links_pkey primary key (id),
  constraint provenance_links_check check (
    (judgment_id is not null and event_id is null)
    or (judgment_id is null and event_id is not null)
  ),
  constraint provenance_links_event_id_fkey foreign key (event_id) references public.judgment_events(id),
  constraint provenance_links_judgment_id_fkey foreign key (judgment_id) references public.judgments(id),
  constraint provenance_links_source_id_fkey foreign key (source_id) references public.sources(id)
);
