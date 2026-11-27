import { requireShowcaseTestRoutes } from "@/lib/testRouteAccess";
import { createSupabaseServerClient } from "@/lib/supabaseServer";

const authorityId = "f0223ad5-e643-439c-a5b8-4c301a586f08";

export const dynamic = "force-dynamic";

export default async function Z4RevokeTestPage() {
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
    "revoke_execution_authority",
    {
      target_authority_id: authorityId,
    }
  );

  return (
    <main className="max-w-3xl mx-auto px-4 py-16">
      <h1 className="text-2xl font-bold">
        Z4 - Authority Revocation Test
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

