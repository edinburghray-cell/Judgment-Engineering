begin;

create or replace function public.get_judgment_lifecycle_history(target_judgment_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if target_judgment_id is null
     or not private.can_read_judgment(target_judgment_id, auth.uid()) then
    raise exception 'Judgment not found or access denied';
  end if;

  with scoped_cycles as (
    select rc.id
    from public.review_cycles rc
    where rc.confirmed_judgment_id = target_judgment_id
  ), scoped_decisions as (
    select d.*
    from public.decisions d
    join scoped_cycles rc on rc.id = d.review_cycle_id
  ), scoped_authorities as (
    select ea.*
    from public.execution_authorities ea
    join scoped_decisions d on d.id = ea.decision_id
  ), scoped_operations as (
    select eo.*
    from public.execution_operations eo
    join scoped_authorities ea on ea.id = eo.authority_id
      and eo.decision_id = ea.decision_id
  )
  select jsonb_build_object(
    'decisions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id, 'review_cycle_id', d.review_cycle_id,
        'decision', d.decision, 'actor_id', d.actor_id,
        'authority_basis', d.authority_basis, 'decided_at', d.decided_at,
        'rationale', d.rationale, 'residual_risks', d.residual_risks,
        'correlation_id', d.correlation_id, 'causation_id', d.causation_id
      ) order by d.decided_at, d.id)
      from scoped_decisions d
    ), '[]'::jsonb),
    'authorities', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', ea.id, 'decision_id', ea.decision_id, 'actor_id', ea.actor_id,
        'action', ea.action, 'scope', ea.scope, 'target', ea.target,
        'valid_from', ea.valid_from, 'valid_until', ea.valid_until,
        'revoked_at', ea.revoked_at, 'revoked_by', ea.revoked_by,
        'correlation_id', ea.correlation_id, 'created_at', ea.created_at
      ) order by ea.created_at, ea.id)
      from scoped_authorities ea
    ), '[]'::jsonb),
    'operations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', eo.id, 'operation_id', eo.operation_id,
        'authority_id', eo.authority_id, 'decision_id', eo.decision_id,
        'actor_id', eo.actor_id, 'action', eo.action, 'scope', eo.scope,
        'target', eo.target, 'status', eo.status, 'outcome', eo.outcome,
        'created_at', eo.created_at, 'started_at', eo.started_at,
        'resolved_at', eo.resolved_at
      ) order by eo.created_at, eo.id)
      from scoped_operations eo
    ), '[]'::jsonb),
    'attempts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', ea.id, 'authority_id', ea.authority_id,
        'decision_id', ea.decision_id, 'operation_id', ea.operation_id,
        'actor_id', ea.actor_id, 'attempted_at', ea.attempted_at,
        'status', ea.status, 'rejection_reason', ea.rejection_reason,
        'correlation_id', ea.correlation_id
      ) order by ea.attempted_at, ea.id)
      from public.execution_attempts ea
      join scoped_authorities authz on authz.id = ea.authority_id
        and authz.decision_id = ea.decision_id
      left join scoped_operations op on op.operation_id = ea.operation_id
      where op.operation_id is not null
    ), '[]'::jsonb),
    'runs', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', er.id, 'operation_id', er.operation_id,
        'execution_status', er.execution_status, 'outcome', er.outcome,
        'started_at', er.started_at, 'completed_at', er.completed_at,
        'evidence_status', er.evidence_status, 'created_at', er.created_at
      ) order by er.created_at, er.id)
      from public.execution_runs er
      join scoped_operations op on op.operation_id = er.operation_id
    ), '[]'::jsonb),
    'execution_evidence', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', ee.id, 'authority_id', ee.authority_id,
        'decision_id', ee.decision_id, 'operation_id', ee.operation_id,
        'actor_id', ee.actor_id, 'action', ee.action, 'scope', ee.scope,
        'executed_at', ee.executed_at, 'correlation_id', ee.correlation_id,
        'result', ee.result
      ) order by ee.executed_at, ee.id)
      from public.execution_evidence ee
      join scoped_authorities authz on authz.id = ee.authority_id
        and authz.decision_id = ee.decision_id
      join scoped_operations op on op.operation_id = ee.operation_id
        and op.authority_id = ee.authority_id
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$function$;

revoke all on function public.get_judgment_lifecycle_history(uuid) from public, anon, service_role;
grant execute on function public.get_judgment_lifecycle_history(uuid) to authenticated;
alter function public.get_judgment_lifecycle_history(uuid) owner to postgres;

commit;
