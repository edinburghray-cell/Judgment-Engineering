import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabaseServer";

type ReviewCyclePageProps = {
  params: Promise<{ reviewCycleId: string }>;
};

export default async function ReviewCyclePage({
  params,
}: ReviewCyclePageProps) {
  const { reviewCycleId } = await params;

  const supabase = await createSupabaseServerClient();

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    redirect("/auth");
  }

  const { data, error } = await supabase.rpc("get_review_cycle", {
    target_review_cycle_id: reviewCycleId,
  });

  if (error) {
    throw new Error(error.message);
  }

  const reviewCycle = Array.isArray(data) ? data[0] : data;

  if (!reviewCycle) {
    return notFound();
  }

  const alternatives: { label: string }[] =
    reviewCycle.alternatives ?? [];

  const evidence: { label: string }[] =
    reviewCycle.evidence ?? [];

  return (
    <main className="max-w-3xl mx-auto px-4 py-10">
      <Link
        href="/"
        className="text-sm text-blue-700 hover:underline"
      >
        Back to Judgment Engineering
      </Link>

      <div className="flex items-center justify-between mt-6 mb-2">
        <div>
          <p className="text-xs font-mono text-gray-400">
            Review Cycle {reviewCycle.review_cycle_id}
          </p>
          <p className="text-xs font-mono text-gray-400 mt-1">
            Proposal Version {reviewCycle.version_number}
          </p>
        </div>

        <span className="text-xs px-3 py-1 rounded bg-blue-100 text-blue-700 font-medium">
          {reviewCycle.review_cycle_status}
        </span>
      </div>

      <h1 className="text-2xl font-bold mt-4 mb-2">
        Change Proposal
      </h1>

      <p className="text-gray-600 mb-8">
        This proposal is available for review. Reviewability does not imply
        approval, implementation, or deployment authority.
      </p>

      <div className="space-y-4">
        <section className="border rounded p-5">
          <h2 className="font-semibold mb-3">Change</h2>

          <dl className="space-y-3 text-sm">
            <div>
              <dt className="font-medium text-gray-500">Change ID</dt>
              <dd className="mt-1">{reviewCycle.change_id}</dd>
            </div>

            <div>
              <dt className="font-medium text-gray-500">Scope</dt>
              <dd className="mt-1 whitespace-pre-wrap">
                {reviewCycle.scope}
              </dd>
            </div>

            <div>
              <dt className="font-medium text-gray-500">Affected System</dt>
              <dd className="mt-1">{reviewCycle.affected_system}</dd>
            </div>

            <div>
              <dt className="font-medium text-gray-500">Environment</dt>
              <dd className="mt-1">{reviewCycle.environment}</dd>
            </div>
          </dl>
        </section>

        <section className="border rounded p-5">
          <h2 className="font-semibold mb-3">Judgment Context</h2>

          <div className="space-y-4 text-sm">
            <div>
              <h3 className="font-medium text-gray-500">Assumptions</h3>
              <p className="mt-1 whitespace-pre-wrap">
                {reviewCycle.assumptions}
              </p>
            </div>

            <div>
              <h3 className="font-medium text-gray-500">
                Alternatives Considered
              </h3>

              {alternatives.length > 0 ? (
                <ul className="list-disc list-inside mt-1 space-y-1">
                  {alternatives.map((alternative, index) => (
                    <li key={index}>{alternative.label}</li>
                  ))}
                </ul>
              ) : (
                <p className="mt-1 text-gray-500">
                  No alternatives recorded.
                </p>
              )}
            </div>

            <div>
              <h3 className="font-medium text-gray-500">
                Evidence / Sources
              </h3>

              {evidence.length > 0 ? (
                <ul className="list-disc list-inside mt-1 space-y-1">
                  {evidence.map((item, index) => (
                    <li key={index}>{item.label}</li>
                  ))}
                </ul>
              ) : (
                <p className="mt-1 text-gray-500">
                  No evidence references recorded.
                </p>
              )}
            </div>

            <div>
              <h3 className="font-medium text-gray-500">Known Risks</h3>
              <p className="mt-1 whitespace-pre-wrap">
                {reviewCycle.known_risks}
              </p>
            </div>
          </div>
        </section>

        <section className="border rounded p-5 bg-gray-50">
          <h2 className="font-semibold mb-2">Workflow Boundary</h2>
          <p className="text-sm text-gray-700">
            This page represents a reviewable proposal. A consequential
            decision requires a human-confirmed Judgment and an authorized
            decision-maker. Approval, when eventually recorded, applies only
            to the reviewed proposal version and scope.
          </p>
        </section>
      </div>
    </main>
  );
}
