import { requireShowcaseTestRoutes } from "@/lib/testRouteAccess";
import { createSupabaseServerClient } from "@/lib/supabaseServer";
import { redirect } from "next/navigation";

const decisionId = "ec65142a-4974-4b1e-8665-e35a9cce2274";
const authorityId = "f1beb719-3da5-4f1d-9c78-a699631a0f93";

export const dynamic = "force-dynamic";

export default async function Z4TestPage({
  searchParams,
}: {
  searchParams: Promise<{ operation_id?: string; execution?: string }>;
}) {
  requireShowcaseTestRoutes();
  async function executeZ4RejectedAttempt(formData: FormData) {
    "use server";

    requireShowcaseTestRoutes();
    const supabase = await createSupabaseServerClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) redirect("/auth");

    const operationId = String(formData.get("operation_id") ?? "");

    const { data, error } = await supabase.rpc(
      "execute_authorized_action",
      {
        target_authority_id: authorityId,
        target_action: "z4_rejected_execution_audit_test",
        target_scope: "Z4 rejected execution audit verification",
        target_operation_id: operationId,
        target_target: "synthetic:z4-execution-audit",
        target_parameters: {
          test_case: "action_mismatch",
        },
      }
    );

    const result = JSON.stringify({
      data,
      error: error?.message ?? null,
    });

    redirect(
      `/z4-test?operation_id=${encodeURIComponent(operationId)}&execution=${encodeURIComponent(result)}`
    );
  }

  const params = await searchParams;

  let executionResult: unknown = null;

  if (params.execution) {
    try {
      executionResult = JSON.parse(params.execution);
    } catch {
      executionResult = {
        error: "Could not parse execution result.",
      };
    }
  }

  const operationId = params.operation_id ?? crypto.randomUUID();

  return (
    <main className="max-w-3xl mx-auto px-4 py-16">
      <h1 className="text-2xl font-bold">
        Z4 - Rejected Execution Audit Test
      </h1>

      <p className="mt-4 text-gray-600">
        Synthetic test surface for testing the Z4 execution authority.
        No external system action is performed.
      </p>

      <div className="mt-8 rounded border p-4">
        <h2 className="font-semibold">Authority fixture</h2>

        <pre className="mt-4 whitespace-pre-wrap text-sm">
{JSON.stringify(
  {
    decision_id: decisionId,
    authority_id: authorityId,
    action: "z4_rejected_execution_audit_test",
    scope: "Z4 rejected execution audit verification",
    target: "synthetic:z4-execution-audit",
    parameters: {
      test_case: "action_mismatch",
    },
  },
  null,
  2
)}
        </pre>
      </div>

      <div className="mt-8 rounded border p-4">
        <h2 className="font-semibold">Rejected execution case</h2>

        <pre className="mt-4 whitespace-pre-wrap text-sm">
{JSON.stringify(
  {
    operation_id: operationId,
    requested_action: "z4_rejected_execution_audit_test",
    expected_rejection_reason: "execution authority has expired",
  },
  null,
  2
)}
        </pre>
      </div>

      <form action={executeZ4RejectedAttempt} className="mt-6">
        <input
          type="hidden"
          name="operation_id"
          value={operationId}
        />

        <button
          type="submit"
          className="rounded bg-black px-4 py-2 text-white"
        >
          Execute Expired-Authority Test
        </button>
      </form>

      {executionResult !== null && (
        <div className="mt-8 rounded border p-4">
          <h2 className="font-semibold">Execution result</h2>

          <pre className="mt-4 whitespace-pre-wrap text-sm">
            {JSON.stringify(executionResult, null, 2)}
          </pre>
        </div>
      )}
    </main>
  );
}




