create or replace function public.authorize_execution(
  target_authority_id uuid,
  requested_action text,
  requested_scope text
)
returns table (
  authorized boolean,
  authority_id uuid,
  actor_id uuid,
  action text,
  scope text,
  valid_from timestamptz,
  valid_until timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_actor uuid;
  authority_actor uuid;
  authority_action text;
  authority_scope text;
  authority_valid_from timestamptz;
  authority_valid_until timestamptz;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication required';
  end if;

  if target_authority_id is null then
    raise exception 'Execution authority is required';
  end if;

  if nullif(trim(requested_action), '') is null then
    raise exception 'Execution action is required';
  end if;

  if nullif(trim(requested_scope), '') is null then
    raise exception 'Execution scope is required';
  end if;

  select
    ea.actor_id,
    ea.action,
    ea.scope,
    ea.valid_from,
    ea.valid_until
  into
    authority_actor,
    authority_action,
    authority_scope,
    authority_valid_from,
    authority_valid_until
  from public.execution_authorities ea
  where ea.id = target_authority_id;

  if not found then
    raise exception 'Execution authority not found';
  end if;

  if authority_actor <> current_actor then
    raise exception 'Execution actor is not authorized';
  end if;

  if authority_action <> trim(requested_action) then
    raise exception 'Execution action is outside authority';
  end if;

  if authority_scope <> trim(requested_scope) then
    raise exception 'Execution scope is outside authority';
  end if;

  if now() < authority_valid_from then
    raise exception 'Execution authority is not yet valid';
  end if;

  if now() > authority_valid_until then
    raise exception 'Execution authority has expired';
  end if;

  return query
  select
    true,
    target_authority_id,
    authority_actor,
    authority_action,
    authority_scope,
    authority_valid_from,
    authority_valid_until;
end;
$$;

revoke execute on function public.authorize_execution(
  uuid,
  text,
  text
) from public, anon;

grant execute on function public.authorize_execution(
  uuid,
  text,
  text
) to authenticated;

alter function public.authorize_execution(
  uuid,
  text,
  text
) owner to postgres;