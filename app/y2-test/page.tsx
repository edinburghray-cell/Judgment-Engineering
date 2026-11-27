import { requireShowcaseTestRoutes } from "@/lib/testRouteAccess";
import { createSupabaseServerClient } from "@/lib/supabaseServer";

export const dynamic = "force-dynamic";

export default async function Y2TestPage() {
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
      target_decision_id: "03212c7a-9be4-4c87-b839-e857e54b5276",
      target_action: "test_execution",
      target_scope: "Y2 verification only",
      target_valid_from: new Date().toISOString(),
      target_valid_until: new Date(new Date().getTime() + 60 * 60 * 1000).toISOString(),
    }
  );

  return (
    <main className="max-w-3xl mx-auto px-4 py-16">
      <h1 className="text-2xl font-bold">Y2 Authority Test</h1>
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



