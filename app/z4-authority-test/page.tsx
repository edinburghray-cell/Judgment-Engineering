import { requireShowcaseTestRoutes } from "@/lib/testRouteAccess";
import { createSupabaseServerClient } from "@/lib/supabaseServer";

export const dynamic = "force-dynamic";

export default async function Z4AuthorityTestPage() {
  requireShowcaseTestRoutes();
  const supabase = await createSupabaseServerClient();

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return <pre>Not authenticated</pre>;
  }

  const { data, error } = await supabase.rpc(
    "issue_execution_authority",
    {
      target_decision_id:
        "66c2e79f-c190-472d-8b69-0550f90f60d5",
      target_action: "z4_rejected_execution_audit_test",
      target_scope: "Z4 rejected execution audit verification",
      target_target: "synthetic:z4-execution-audit",
      target_parameters: {
        test_case: "target_mismatch",
      },
      target_valid_from: new Date().toISOString(),
      target_valid_until: new Date(
        new Date().getTime() + 60 * 60 * 1000
      ).toISOString(),
    }
  );

  return (
    <main className="max-w-3xl mx-auto px-4 py-16">
      <h1 className="text-2xl font-bold">Z4 Authority Test</h1>
      <pre className="mt-6 whitespace-pre-wrap">
        {JSON.stringify(
          {
            authenticated_user_id: user.id,
            data,
            error: error?.message ?? null,
          },
          null,
          2
        )}
      </pre>
    </main>
  );
}

