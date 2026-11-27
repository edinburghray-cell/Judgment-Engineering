import { requireShowcaseTestRoutes } from "@/lib/testRouteAccess";
import { createSupabaseServerClient } from "@/lib/supabaseServer";

export const dynamic = "force-dynamic";

export default async function Y3IssueTestPage() {
  requireShowcaseTestRoutes();
  const supabase = await createSupabaseServerClient();

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return <pre>Not authenticated</pre>;
  }

  const { data, error } = await supabase.rpc("authorize_execution", {
    target_authority_id: "b85be55a-8288-4209-85b4-7576e50e84d2",
    requested_action: "test_execution",
    requested_scope: "Y3 verification only",
  });

  return (
    <main className="max-w-3xl mx-auto px-4 py-16">
      <h1 className="text-2xl font-bold">Y3 Issue Verification Test</h1>
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

