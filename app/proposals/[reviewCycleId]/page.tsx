import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabaseServer";
import RetrospectiveForm from "../../units/[id]/RetrospectiveForm";
import ConfirmationForm from "./ConfirmationForm";

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
  const { data: committedJudgment } =
    reviewCycle.confirmed_judgment_id
      ? await supabase
          .from("judgments")
          .select(
            "id, judgment_unit_id, committing_actor, committed_at, reconsideration_conditions, predecessor_judgment_id"
          )
          .eq("id", reviewCycle.confirmed_judgment_id)
          .maybeSingle()
      : { data: null };

  const { data: availableJudgments = [] } = await supabase.from("judgments").select("id, judgment_unit_id, title, committed_at").order("committed_at", { ascending: false });

  const { data: judgmentHistory = [] } =
    committedJudgment
      ? await supabase
          .from("judgment_events")
          .select("id, event_type, created_at, actor, payload")
          .eq("judgment_id", committedJudgment.id)
          .order("created_at", { ascending: true })
      : { data: [] };

  async function signOut() {
    "use server";

    const serverSupabase = await createSupabaseServerClient();
    await serverSupabase.auth.signOut();
    redirect("/auth");
  }
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
  async function confirmJudgment(formData: FormData) {
    "use server";

    const serverSupabase = await createSupabaseServerClient();

    const {
      data: { user: currentUser },
      error: currentUserError,
    } = await serverSupabase.auth.getUser();

    if (currentUserError || !currentUser) {
      redirect("/auth");
    }

    const reconsiderationConditions = String(formData.get("reconsideration_conditions") ?? "").trim();

    const predecessorJudgmentIdRaw = String(formData.get("predecessor_judgment_id") ?? "").trim();
    const predecessorJudgmentId = predecessorJudgmentIdRaw || null;

    const isSupersession = String(formData.get("is_supersession") ?? "") === "true";

    const supersessionRationale = String(formData.get("supersession_rationale") ?? "").trim();

    const validationBasis = String(formData.get("validation_basis") ?? "").trim();

    if (!reconsiderationConditions) {
      throw new Error("Reconsideration conditions are required.");
    }

    if (isSupersession && !predecessorJudgmentId) {
      throw new Error("Supersession requires a prior Judgment.");
    }

    if (isSupersession && !supersessionRationale) {
      throw new Error("Supersession rationale is required.");
    }

    if (isSupersession && !validationBasis) {
      throw new Error("Validation basis is required.");
    }

    const { error: confirmationError } = await serverSupabase.rpc(
      "confirm_review_cycle_judgment",
      {
        target_review_cycle_id: reviewCycleId,
        target_reconsideration_conditions: reconsiderationConditions,
        target_predecessor_judgment_id: predecessorJudgmentId,
        target_is_supersession: isSupersession,
        target_supersession_rationale: isSupersession ? supersessionRationale : null,
        target_validation_basis: isSupersession ? validationBasis : null,
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

  async function assignDecisionMaker(formData: FormData) {
    "use server";

    const decisionMakerActorId = String(
      formData.get("decision_maker_actor_id") ?? ""
    ).trim();

    if (!decisionMakerActorId) {
      throw new Error("Decision-maker actor ID is required");
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
      "assign_review_cycle_decision_maker",
      {
        target_review_cycle_id: reviewCycleId,
        target_decision_maker_actor_id: decisionMakerActorId,
      }
    );

    if (assignmentError) {
      throw new Error(assignmentError.message);
    }

    redirect(`/proposals/${reviewCycleId}`);
  }

  async function recordDecision(formData: FormData) {
    "use server";

    const decision = String(
      formData.get("decision") ?? ""
    ).trim();

    const authorityBasis = String(
      formData.get("authority_basis") ?? ""
    ).trim();

    const rationale = String(
      formData.get("rationale") ?? ""
    ).trim();

    const residualRisks = String(
      formData.get("residual_risks") ?? ""
    ).trim();

    const correlationId = String(
      formData.get("correlation_id") ?? ""
    ).trim();

    if (!decision) {
      throw new Error("Decision is required");
    }

    if (!authorityBasis) {
      throw new Error("Authority basis is required");
    }

    if (!correlationId) {
      throw new Error("Correlation ID is required");
    }

    const serverSupabase = await createSupabaseServerClient();

    const {
      data: { user: currentUser },
      error: currentUserError,
    } = await serverSupabase.auth.getUser();

    if (currentUserError || !currentUser) {
      redirect("/auth");
    }

    const { error: decisionError } = await serverSupabase.rpc(
      "record_review_decision",
      {
        target_review_cycle_id: reviewCycleId,
        target_decision: decision,
        target_authority_basis: authorityBasis,
        target_rationale: rationale || null,
        target_residual_risks: residualRisks || null,
        target_correlation_id: correlationId,
        target_causation_id: null,
      }
    );

    if (decisionError) {
      throw new Error(decisionError.message);
    }

    redirect(`/proposals/${reviewCycleId}`);
  }
  async function preserveReviewCycle() {
    "use server";

    const serverSupabase = await createSupabaseServerClient();

    const {
      data: { user: currentUser },
      error: currentUserError,
    } = await serverSupabase.auth.getUser();

    if (currentUserError || !currentUser) {
      redirect("/auth");
    }

    const { error: preservationError } = await serverSupabase.rpc(
      "preserve_review_cycle",
      {
        target_review_cycle_id: reviewCycleId,
      }
    );

    if (preservationError) {
      throw new Error(preservationError.message);
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

        <form action={signOut}>
          <button
            type="submit"
            className="text-xs px-3 py-1 rounded border border-gray-300 text-gray-700 hover:bg-gray-50"
          >
            Sign out
          </button>
        </form>

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

        {committedJudgment ? (
          <section className="border rounded p-5">
            <h2 className="font-semibold mb-3">Judgment Durability</h2>

            <dl className="grid gap-3 text-sm sm:grid-cols-2">
              <div>
                <dt className="font-medium text-gray-500">Committed by</dt>
                <dd className="mt-1 font-mono break-all">
                  {committedJudgment.committing_actor}
                </dd>
              </div>

              <div>
                <dt className="font-medium text-gray-500">Commit date</dt>
                <dd className="mt-1">
                  {new Date(committedJudgment.committed_at).toLocaleString()}
                </dd>
              </div>

              <div>
                <dt className="font-medium text-gray-500">Sources</dt>
                <dd className="mt-1">
                  {evidence.length > 0
                    ? `${evidence.length} recorded source reference${evidence.length === 1 ? "" : "s"}`
                    : "No source references recorded."}
                </dd>
              </div>

              <div>
                <dt className="font-medium text-gray-500">History</dt>
                <dd className="mt-1">
                  {(judgmentHistory ?? []).length} event{(judgmentHistory ?? []).length === 1 ? "" : "s"} recorded
                </dd>
              </div>

              <div className="sm:col-span-2">
                <dt className="font-medium text-gray-500">Retrospective</dt>
                <dd className="mt-1">
                  {(judgmentHistory ?? []).some(
                    (event) => event.event_type === "retrospective"
                  )
                    ? "Recorded"
                    : "Not yet recorded"}
                </dd>
              </div>

              <div className="sm:col-span-2">
                <dt className="font-medium text-gray-500">
                  Reconsideration condition
                </dt>
                <dd className="mt-1 whitespace-pre-wrap">
                  {committedJudgment.reconsideration_conditions}
                </dd>
              </div>
            </dl>
          </section>
        ) : null}
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

        <section className="border rounded p-5">
          <h2 className="font-semibold mb-3">Decision-Maker Assignment</h2>

          {reviewCycle.decision_maker_actor_id ? (
            <p className="text-sm">
              Assigned decision-maker:{" "}
              <span className="font-mono">
                {reviewCycle.decision_maker_actor_id}
              </span>
            </p>
          ) : reviewCycle.proposer_actor_id === user.id &&
            reviewCycle.review_cycle_status === "reviewable" ? (
            <form action={assignDecisionMaker} className="space-y-3">
              <label
                htmlFor="decision_maker_actor_id"
                className="block text-sm font-medium"
              >
                Authenticated decision-maker actor ID
              </label>

              <input
                id="decision_maker_actor_id"
                name="decision_maker_actor_id"
                required
                className="w-full border rounded px-3 py-2 font-mono text-sm"
                placeholder="Paste the authenticated decision-maker UUID"
              />

              <p className="text-xs text-gray-500">
                Only the authenticated proposer can assign the decision-maker.
              </p>

              <button
                type="submit"
                className="px-4 py-2 rounded bg-black text-white font-medium"
              >
                Assign Decision-Maker
              </button>
            </form>
          ) : (
            <p className="text-sm text-gray-600">
              No decision-maker has been assigned yet.
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
        {reviewCycle.review_cycle_status === "human_confirmed" &&
        reviewCycle.decision_maker_actor_id === user.id ? (
          <section className="border rounded p-5">
            <h2 className="font-semibold mb-3">Consequential Decision</h2>

            <p className="text-sm text-gray-600 mb-4">
              Record the authorized decision for this review cycle. The
              decision applies only to the reviewed proposal version and scope.
              It does not authorize implementation, deployment, or expansion.
            </p>

            <form action={recordDecision} className="space-y-4">
              <div>
                <label
                  htmlFor="decision"
                  className="block text-sm font-medium mb-1"
                >
                  Decision
                </label>
                <select
                  id="decision"
                  name="decision"
                  required
                  className="w-full border rounded px-3 py-2"
                  defaultValue=""
                >
                  <option value="" disabled>
                    Select decision
                  </option>
                  <option value="approve">Approve</option>
                  <option value="reject">Reject</option>
                  <option value="defer">Defer</option>
                </select>
              </div>

              <div>
                <label
                  htmlFor="authority_basis"
                  className="block text-sm font-medium mb-1"
                >
                  Authority Basis
                </label>
                <input
                  id="authority_basis"
                  name="authority_basis"
                  required
                  className="w-full border rounded px-3 py-2"
                  placeholder="Why you are authorized to make this decision"
                />
              </div>

              <div>
                <label
                  htmlFor="rationale"
                  className="block text-sm font-medium mb-1"
                >
                  Rationale
                </label>
                <textarea
                  id="rationale"
                  name="rationale"
                  rows={4}
                  className="w-full border rounded px-3 py-2"
                  placeholder="Reasoning behind the decision"
                />
              </div>

              <div>
                <label
                  htmlFor="residual_risks"
                  className="block text-sm font-medium mb-1"
                >
                  Residual Risks
                </label>
                <textarea
                  id="residual_risks"
                  name="residual_risks"
                  rows={3}
                  className="w-full border rounded px-3 py-2"
                  placeholder="Risks that remain accepted or unresolved"
                />
              </div>

              <div>
                <label
                  htmlFor="correlation_id"
                  className="block text-sm font-medium mb-1"
                >
                  Correlation ID
                </label>
                <input
                  id="correlation_id"
                  name="correlation_id"
                  required
                  className="w-full border rounded px-3 py-2 font-mono text-sm"
                  defaultValue={crypto.randomUUID()}
                />
                <p className="text-xs text-gray-500 mt-1">
                  Identifies this decision operation for replay-safe recording
                  and audit correlation.
                </p>
              </div>

              <button
                type="submit"
                className="px-4 py-2 rounded bg-black text-white font-medium"
              >
                Record Consequential Decision
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
            <ConfirmationForm
              action={confirmJudgment}
              availableJudgments={availableJudgments ?? []}
            />
          </section>
        ) : null}
        {reviewCycle.review_cycle_status === "decided" &&
        (reviewCycle.proposer_actor_id === user.id ||
          reviewCycle.reviewer_actor_id === user.id ||
          reviewCycle.decision_maker_actor_id === user.id) ? (
          <section className="border rounded p-5">
            <h2 className="font-semibold mb-3">Preservation</h2>
            <p className="text-sm text-gray-600 mb-4">
              Complete the review cycle only after the confirmed Judgment,
              consequential decision, semantic Judgment event, and workflow
              audit are all intact. Preservation does not create or change the
              decision.
            </p>
            <form action={preserveReviewCycle}>
              <button
                type="submit"
                className="px-4 py-2 rounded bg-black text-white font-medium"
              >
                Preserve / Complete Review Cycle
              </button>
            </form>
          </section>
        ) : null}
        {reviewCycle.review_cycle_status === "preserved_complete" &&
        reviewCycle.confirmed_judgment_id &&
        (reviewCycle.proposer_actor_id === user.id ||
          reviewCycle.reviewer_actor_id === user.id ||
          reviewCycle.decision_maker_actor_id === user.id) ? (
          <section className="border rounded p-5">
            <h2 className="font-semibold mb-3">Retrospective</h2>
            <p className="text-sm text-gray-600 mb-4">
              Record what was learned from the preserved Judgment without
              modifying the original Judgment.
            </p>
            <RetrospectiveForm id={reviewCycle.confirmed_judgment_id} />
          </section>
        ) : null}        <section className="border rounded p-5 bg-gray-50">
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
