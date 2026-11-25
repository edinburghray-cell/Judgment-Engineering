-- Milestone Z5: Remove legacy authorization overload.
--
-- The 5-argument authorization path predates stable operation identity.
-- Keeping it would allow an authorization flow without operation_id.
-- The 6-argument Z5 contract is the sole authorization-release boundary.

drop function if exists public.authorize_execution(
  uuid,
  text,
  text,
  text,
  jsonb
);
