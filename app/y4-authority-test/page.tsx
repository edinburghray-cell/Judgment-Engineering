import { requireShowcaseTestRoutes } from "@/lib/testRouteAccess";
import { createSupabaseServerClient } from "@/lib/supabaseServer";

export const dynamic = "force-dynamic";

export default async function Y4AuthorityTestPage() {
  requireShowcaseTestRoutes();
  const supabase = await createSupabaseServerClient();

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return <pre>Not authenticated</pre>;
  }

  const authorityId =
    "bf9d0beb-94be-4722-8a89-d9c56b355247";

  const { data, error } = await supabase.rpc(
    "execute_authorized_action",
    {
      target_authority_id: authorityId,
      target_action: "test_execution",
      target_scope:
        "Y4 execution evidence verification only",
    }
  );

  return (
    <main className="max-w-4xl mx-auto px-4 py-16">
      <h1 className="text-2xl font-bold">
        Y4 Execution Test
      </h1>

      <pre className="mt-6 whitespace-pre-wrap">
        {JSON.stringify(
          {
            authenticated_user_id: user.id,
            authority_id: authorityId,
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
