import { createSupabaseServerClient } from "@/lib/supabaseServer";

export default async function Y4TestPage() {
  const supabase = await createSupabaseServerClient();

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return <pre>Not authenticated</pre>;
  }

  const reviewCycleId =
    "3fa405fe-56fe-48c0-818c-0195be0881d6";

  const correlationId = crypto.randomUUID();

  const { data, error } = await supabase.rpc(
    "record_review_decision",
    {
      target_review_cycle_id: reviewCycleId,
      target_decision: "approve",
      target_authority_basis:
        "Authorized decision-maker for Y4 execution evidence verification.",
      target_rationale:
        "Synthetic approval used to verify the Judgment Engineering execution evidence chain.",
      target_residual_risks:
        "Synthetic execution only. No external system action is performed.",
      target_correlation_id: correlationId,
      target_causation_id: null,
    }
  );

  return (
    <main className="max-w-4xl mx-auto px-4 py-16">
      <h1 className="text-2xl font-bold">
        Y4 Approval Test
      </h1>

      <pre className="mt-6 whitespace-pre-wrap">
        {JSON.stringify(
          {
            authenticated_user_id: user.id,
            review_cycle_id: reviewCycleId,
            correlation_id: correlationId,
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