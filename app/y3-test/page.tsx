import { requireShowcaseTestRoutes } from "@/lib/testRouteAccess";
import { createSupabaseServerClient } from "@/lib/supabaseServer";

export const dynamic = "force-dynamic";

export default async function Y3TestPage() {
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
    "execute_authorized_action",
    {
      target_authority_id:
        "d72f2029-b969-4727-a3c6-a80463b51120",
      target_action: "test_execution",
      target_scope: "Y2 verification only",
    }
  );

  return (
    <main className="max-w-3xl mx-auto px-4 py-16">
      <h1 className="text-2xl font-bold">
        Y3 Authority Boundary Test
      </h1>

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

