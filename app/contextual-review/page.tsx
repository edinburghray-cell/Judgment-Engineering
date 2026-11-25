

import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabaseServer";

type ContextualReviewPageProps = {
  searchParams: Promise<{
    candidate_id?: string;
    recorded?: string;
  }>;
};

export default async function ContextualReviewPage({
  searchParams,
}: ContextualReviewPageProps) {
  const {
    candidate_id: candidateId,
    recorded,
  } = await searchParams;

  if (!candidateId) {
    return notFound();
  }

  const resolvedCandidateId = candidateId;

  const supabase = await createSupabaseServerClient();

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    redirect("/auth");
  }

  async function recordApplicability(formData: FormData) {
    "use server";

    const applicability = String(
      formData.get("applicability") ?? ""
    ).trim();

    const rationale = String(
      formData.get("rationale") ?? ""
    ).trim();

    const adaptationEvidence = String(
      formData.get("adaptation_evidence") ?? ""
    ).trim();

    const correlationId = String(
      formData.get("correlation_id") ?? ""
    ).trim();

    if (!applicability) {
      throw new Error("Applicability is required.");
    }

    if (!["apply", "adapt", "reject"].includes(applicability)) {
      throw new Error("Invalid applicability.");
    }

    if (!rationale) {
      throw new Error("Applicability rationale is required.");
    }

    if (!correlationId) {
      throw new Error("Correlation ID is required.");
    }

    if (applicability === "adapt" && !adaptationEvidence) {
      throw new Error("Adaptation evidence is required for Adapt.");
    }

    const serverSupabase = await createSupabaseServerClient();

    const {
      data: { user: currentUser },
      error: currentUserError,
    } = await serverSupabase.auth.getUser();

    if (currentUserError || !currentUser) {
      redirect("/auth");
    }

    let parsedAdaptationEvidence: Record<string, string> | null = null;

    if (applicability === "adapt") {
      parsedAdaptationEvidence = {
        description: adaptationEvidence,
      };
    }

    const { error: applicabilityError } = await serverSupabase.rpc(
      "record_contextual_judgment_applicability",
      {
        target_candidate_id: resolvedCandidateId,
        target_applicability: applicability,
        target_rationale: rationale,
        target_adaptation_evidence: parsedAdaptationEvidence,
        target_correlation_id: correlationId,
        target_causation_id: null,
      }
    );

    if (applicabilityError) {
      throw new Error(applicabilityError.message);
    }

    redirect(
      `/contextual-review?candidate_id=${encodeURIComponent(
        resolvedCandidateId
      )}&recorded=1`
    );
  }

  const { data, error } = await supabase.rpc(
    "get_contextual_retrieval_candidate",
    {
      target_candidate_id: candidateId,
    }
  );

  if (error) {
    throw new Error(error.message);
  }

  const candidate = Array.isArray(data) ? data[0] : data;

  if (!candidate) {
    return notFound();
  }

  return (
    <main className="max-w-3xl mx-auto px-4 py-10">
      <Link
        href="/"
        className="text-sm text-blue-700 hover:underline"
      >
        Back to Judgment Engineering
      </Link>

      <h1 className="text-2xl font-bold mt-6 mb-2">
        Contextual Judgment Review
      </h1>

      <p className="text-gray-600 mb-8">
        This historical Judgment was retrieved as potentially relevant to the
        current context. Retrieval does not determine whether it applies.
      </p>

      {recorded === "1" && (
        <div className="border border-green-300 bg-green-50 rounded p-4 mb-4">
          <p className="text-sm text-green-800 font-medium">
            Applicability decision recorded successfully.
          </p>
        </div>
      )}

      <section className="border rounded p-5 mb-4">
        <h2 className="font-semibold mb-3">Retrieved Judgment</h2>

        <dl className="space-y-3 text-sm">
          <div>
            <dt className="font-medium text-gray-500">Candidate ID</dt>
            <dd className="mt-1 font-mono">{candidate.candidate_id}</dd>
          </div>

          <div>
            <dt className="font-medium text-gray-500">Decision Class</dt>
            <dd className="mt-1">{candidate.decision_class}</dd>
          </div>

          <div>
            <dt className="font-medium text-gray-500">Historical Status</dt>
            <dd className="mt-1">{candidate.historical_status}</dd>
          </div>

          <div>
            <dt className="font-medium text-gray-500">Judgment Summary</dt>
            <dd className="mt-1 whitespace-pre-wrap">
              {candidate.judgment_summary}
            </dd>
          </div>
        </dl>
      </section>

      <section className="border rounded p-5 mb-4">
        <h2 className="font-semibold mb-3">Historical Context</h2>

        <div className="space-y-4 text-sm">
          <div>
            <h3 className="font-medium text-gray-500">Situation</h3>
            <p className="mt-1 whitespace-pre-wrap">
              {candidate.historical_context?.situation || "Not recorded."}
            </p>
          </div>

          <div>
            <h3 className="font-medium text-gray-500">Problem</h3>
            <p className="mt-1 whitespace-pre-wrap">
              {candidate.historical_context?.problem || "Not recorded."}
            </p>
          </div>

          <div>
            <h3 className="font-medium text-gray-500">Assumptions</h3>
            <p className="mt-1 whitespace-pre-wrap">
              {candidate.historical_context?.assumptions || "Not recorded."}
            </p>
          </div>

          <div>
            <h3 className="font-medium text-gray-500">Accepted Risks</h3>
            <p className="mt-1 whitespace-pre-wrap">
              {candidate.historical_context?.accepted_risks || "Not recorded."}
            </p>
          </div>
        </div>
      </section>

      <section className="border rounded p-5 mb-4">
        <h2 className="font-semibold mb-3">Why It Was Retrieved</h2>

        <pre className="text-sm whitespace-pre-wrap overflow-x-auto">
          {JSON.stringify(candidate.relevance, null, 2)}
        </pre>
      </section>

      <section className="border rounded p-5 mb-4">
        <h2 className="font-semibold mb-3">Provenance</h2>

        <pre className="text-sm whitespace-pre-wrap overflow-x-auto">
          {JSON.stringify(candidate.provenance, null, 2)}
        </pre>
      </section>

      {recorded !== "1" && (
        <section className="border rounded p-5">
          <h2 className="font-semibold mb-2">
            Human Applicability Decision
          </h2>

          <p className="text-sm text-gray-600 mb-6">
            Decide whether this historical Judgment applies to the current
            situation. The retrieval itself does not make this decision.
          </p>

          <form action={recordApplicability} className="space-y-6">
            <fieldset className="space-y-3">
              <legend className="font-medium">
                Applicability
              </legend>

              <label className="flex items-start gap-3">
                <input
                  type="radio"
                  name="applicability"
                  value="apply"
                  required
                  className="mt-1"
                />
                <span>
                  <span className="font-medium">Apply</span>
                  <span className="block text-sm text-gray-600">
                    The historical Judgment applies to the current context.
                  </span>
                </span>
              </label>

              <label className="flex items-start gap-3">
                <input
                  type="radio"
                  name="applicability"
                  value="adapt"
                  className="mt-1"
                />
                <span>
                  <span className="font-medium">Adapt</span>
                  <span className="block text-sm text-gray-600">
                    The historical Judgment is relevant, but must be modified
                    for the current context.
                  </span>
                </span>
              </label>

              <label className="flex items-start gap-3">
                <input
                  type="radio"
                  name="applicability"
                  value="reject"
                  className="mt-1"
                />
                <span>
                  <span className="font-medium">Reject</span>
                  <span className="block text-sm text-gray-600">
                    The historical Judgment does not apply to the current
                    context.
                  </span>
                </span>
              </label>
            </fieldset>

            <div>
              <label
                htmlFor="rationale"
                className="block font-medium mb-2"
              >
                Rationale
              </label>
              <textarea
                id="rationale"
                name="rationale"
                required
                rows={4}
                className="w-full border rounded p-2"
                placeholder="Why does this Judgment apply, require adaptation, or not apply?"
              />
            </div>

            <div>
              <label
                htmlFor="adaptation_evidence"
                className="block font-medium mb-2"
              >
                Adaptation Evidence
              </label>
              <textarea
                id="adaptation_evidence"
                name="adaptation_evidence"
                rows={4}
                className="w-full border rounded p-2"
                placeholder="Required when selecting Adapt. What specifically must change for the current context?"
              />
              <p className="text-xs text-gray-500 mt-1">
                Required only when Adapt is selected.
              </p>
            </div>

            <div>
              <label
                htmlFor="correlation_id"
                className="block font-medium mb-2"
              >
                Correlation ID
              </label>
              <input
                id="correlation_id"
                name="correlation_id"
                required
                defaultValue={crypto.randomUUID()}
                className="w-full border rounded p-2 font-mono text-sm"
              />
              <p className="text-xs text-gray-500 mt-1">
                Identifies this applicability decision in the evidence chain.
              </p>
            </div>

            <button
              type="submit"
              className="bg-blue-900 text-white px-6 py-2 rounded font-semibold"
            >
              Record Applicability Decision
            </button>
          </form>
        </section>
      )}
    </main>
  );
}
