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

  async function structureJudgment(formData: FormData) {
    "use server";

    const serverSupabase = await createSupabaseServerClient();

    const {
      data: { user: currentUser },
      error: currentUserError,
    } = await serverSupabase.auth.getUser();

    if (currentUserError || !currentUser) {
      redirect("/auth");
    }

    const { error: structureError } = await serverSupabase.rpc(
      "create_judgment_draft_for_review_cycle",
      {
        target_review_cycle_id: reviewCycleId,
      }
    );

    if (structureError) {
      throw new Error(structureError.message);
    }

    redirect(`/proposals/${reviewCycleId}`);
  }
  async function confirmJudgment() {
    "use server";

    const serverSupabase = await createSupabaseServerClient();

    const {
      data: { user: currentUser },
      error: currentUserError,
    } = await serverSupabase.auth.getUser();

    if (currentUserError || !currentUser) {
      redirect("/auth");
    }

    const { error: confirmationError } = await serverSupabase.rpc(
      "confirm_review_cycle_judgment",
      {
        target_review_cycle_id: reviewCycleId,
      }
    );

    if (confirmationError) {
      throw new Error(confirmationError.message);
    }

    redirect(`/proposals/${reviewCycleId}`);
  }
  async function assignReviewer(formData: FormData) {
    "use server";

    const reviewerActorId = String(
      formData.get("reviewer_actor_id") ?? ""
    ).trim();

    if (!reviewerActorId) {
      throw new Error("Reviewer actor ID is required");
    }

    const serverSupabase = await createSupabaseServerClient();

    const {
      data: { user: currentUser },
      error: currentUserError,
    } = await serverSupabase.auth.getUser();

    if (currentUserError || !currentUser) {
      redirect("/auth");
    }

    const { error: assignmentError } = await serverSupabase.rpc(
      "assign_review_cycle_reviewer",
      {
        target_review_cycle_id: reviewCycleId,
        target_reviewer_actor_id: reviewerActorId,
      }
    );

    if (assignmentError) {
      throw new Error(assignmentError.message);
    }

    redirect(`/proposals/${reviewCycleId}`);
  }

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

        <section className="border rounded p-5">
          <h2 className="font-semibold mb-3">Reviewer Assignment</h2>

          {reviewCycle.reviewer_actor_id ? (
            <p className="text-sm">
              Assigned reviewer:{" "}
              <span className="font-mono">
                {reviewCycle.reviewer_actor_id}
              </span>
            </p>
          ) : reviewCycle.proposer_actor_id === user.id ? (
            <form action={assignReviewer} className="space-y-3">
              <label
                htmlFor="reviewer_actor_id"
                className="block text-sm font-medium"
              >
                Authenticated reviewer actor ID
              </label>

              <input
                id="reviewer_actor_id"
                name="reviewer_actor_id"
                required
                className="w-full border rounded px-3 py-2 font-mono text-sm"
                placeholder="Paste the authenticated reviewer UUID"
              />

              <p className="text-xs text-gray-500">
                Only the authenticated proposer can assign the reviewer.
              </p>

              <button
                type="submit"
                className="px-4 py-2 rounded bg-black text-white font-medium"
              >
                Assign Reviewer
              </button>
            </form>
          ) : (
            <p className="text-sm text-gray-600">
              No reviewer has been assigned yet.
            </p>
          )}
        </section>

        {reviewCycle.review_cycle_status === "reviewable" &&
        (reviewCycle.proposer_actor_id === user.id ||
          reviewCycle.reviewer_actor_id === user.id) ? (
          <section className="border rounded p-5">
            <h2 className="font-semibold mb-3">Judgment Structuring</h2>

            <p className="text-sm text-gray-600 mb-4">
              Create the structured Judgment Draft from this reviewable
              proposal. Structuring does not confirm the Judgment and does
              not authorize a decision, implementation, or deployment.
            </p>

            <form action={structureJudgment}>
              <button
                type="submit"
                className="px-4 py-2 rounded bg-black text-white font-medium"
              >
                Structure Judgment
              </button>
            </form>
          </section>
        ) : null}
        {reviewCycle.review_cycle_status === "structured_unconfirmed" &&
        reviewCycle.reviewer_actor_id === user.id ? (
          <section className="border rounded p-5">
            <h2 className="font-semibold mb-3">Reviewer Confirmation</h2>
            <p className="text-sm text-gray-600 mb-4">
              Confirm that the structured Judgment accurately represents the
              reviewed proposal. Confirmation creates the preserved Judgment
              record but does not create a consequential decision or authorize
              implementation or deployment.
            </p>
            <form action={confirmJudgment}>
              <button
                type="submit"
                className="px-4 py-2 rounded bg-black text-white font-medium"
              >
                Confirm Judgment
              </button>
            </form>
          </section>
        ) : null}
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
