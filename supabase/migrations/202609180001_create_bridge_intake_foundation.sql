create table if not exists public.bridge_intakes (
  id uuid primary key default gen_random_uuid(),
  source_system text not null check (source_system = 'lumos'),
  interaction_id text not null,
  source_reference text,
  source_timestamp timestamptz,
  original_transcript text not null,
  reviewed_representation text not null,
  reviewer_identity text not null,
  reviewed_at timestamptz not null,
  machine_metadata jsonb not null default '{}'::jsonb,
  idempotency_key text not null unique,
  status text not null default 'received'
    check (status in ('received', 'claimed', 'consumed', 'rejected')),
  claimed_by_actor_id uuid references auth.users(id),
  claimed_at timestamptz,
  proposal_id uuid references public.proposals(id),
  proposal_version_id uuid references public.proposal_versions(id),
  review_cycle_id uuid references public.review_cycles(id),
  consumed_by_actor_id uuid references auth.users(id),
  consumed_at timestamptz,
  created_at timestamptz not null default now(),

  check (
    (status = 'received' and claimed_by_actor_id is null and claimed_at is null)
    or
    (status in ('claimed', 'consumed', 'rejected') and claimed_by_actor_id is not null)
  ),

  check (
    (status = 'consumed' and consumed_by_actor_id is not null and consumed_at is not null)
    or status <> 'consumed'
  )
);

create index if not exists bridge_intakes_interaction_id_idx
  on public.bridge_intakes(interaction_id);

create index if not exists bridge_intakes_status_idx
  on public.bridge_intakes(status);

create index if not exists bridge_intakes_claimed_by_actor_id_idx
  on public.bridge_intakes(claimed_by_actor_id);

create index if not exists bridge_intakes_proposal_id_idx
  on public.bridge_intakes(proposal_id);

create index if not exists bridge_intakes_review_cycle_id_idx
  on public.bridge_intakes(review_cycle_id);

alter table public.bridge_intakes enable row level security;

revoke all on table public.bridge_intakes from anon, authenticated;

create or replace function public.claim_bridge_intake(
  target_bridge_intake_id uuid
)
returns public.bridge_intakes
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  claimed public.bridge_intakes;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  update public.bridge_intakes
  set
    status = 'claimed',
    claimed_by_actor_id = current_actor,
    claimed_at = now()
  where id = target_bridge_intake_id
    and status = 'received'
    and claimed_by_actor_id is null
  returning * into claimed;

  if claimed.id is null then
    raise exception 'Bridge intake unavailable for claim';
  end if;

  return claimed;
end;
$$;

revoke execute on function public.claim_bridge_intake(uuid)
from public, anon;

grant execute on function public.claim_bridge_intake(uuid)
to authenticated;

alter function public.claim_bridge_intake(uuid) owner to postgres;

create or replace function public.get_bridge_intake(
  target_bridge_intake_id uuid
)
returns public.bridge_intakes
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  intake public.bridge_intakes;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  select *
  into intake
  from public.bridge_intakes
  where id = target_bridge_intake_id
    and (
      claimed_by_actor_id = current_actor
      or consumed_by_actor_id = current_actor
    );

  if intake.id is null then
    raise exception 'Bridge intake not accessible';
  end if;

  return intake;
end;
$$;

revoke execute on function public.get_bridge_intake(uuid)
from public, anon;

grant execute on function public.get_bridge_intake(uuid)
to authenticated;

alter function public.get_bridge_intake(uuid) owner to postgres;
