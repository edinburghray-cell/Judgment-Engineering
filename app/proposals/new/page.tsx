import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabaseServer";

type NewProposalPageProps = {
  searchParams: Promise<{ intake_id?: string }>;
};

export default async function NewProposalPage({
  searchParams,
}: NewProposalPageProps) {
  const { intake_id: intakeId } = await searchParams;

  const supabase = await createSupabaseServerClient();

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    redirect("/auth");
  }

  let bridgeIntake:
    | {
        id: string;
        status: string;
        source_system: string;
        interaction_id: string;
        source_reference: string | null;
        source_timestamp: string | null;
        original_transcript: string;
        reviewed_representation: string;
        reviewer_identity: string;
        reviewed_at: string;
        machine_metadata: Record<string, unknown>;
      }
    | null = null;

  let intakeClaimed = false;

  if (intakeId) {
    const { data, error } = await supabase.rpc("get_bridge_intake", {
      target_bridge_intake_id: intakeId,
    });

    if (!error && data) {
      bridgeIntake = Array.isArray(data) ? data[0] : data;
      intakeClaimed = bridgeIntake?.status === "claimed";
    }
  }

  async function claimBridgeIntake() {
    "use server";

    const serverSupabase = await createSupabaseServerClient();

    const {
      data: { user: currentUser },
      error: currentUserError,
    } = await serverSupabase.auth.getUser();

    if (currentUserError || !currentUser) {
      redirect("/auth");
    }

    if (!intakeId) {
      notFound();
    }

    const { error } = await serverSupabase.rpc("claim_bridge_intake", {
      target_bridge_intake_id: intakeId,
    });

    if (error) {
      throw new Error(error.message);
    }

    redirect(`/proposals/new?intake_id=${encodeURIComponent(intakeId)}`);
  }

  async function createProposal(formData: FormData) {
    "use server";

    const changeId = String(formData.get("change_id") || "").trim();
    const scope = String(formData.get("scope") || "").trim();
    const affectedSystem = String(formData.get("affected_system") || "").trim();
    const environment = String(formData.get("environment") || "").trim();
    const assumptions = String(formData.get("assumptions") || "").trim();
    const alternativesRaw = String(formData.get("alternatives") || "").trim();
    const evidenceRaw = String(formData.get("evidence") || "").trim();
    const knownRisks = String(formData.get("known_risks") || "").trim();
    const submittedIntakeId = String(formData.get("intake_id") || "").trim();

    const alternatives = alternativesRaw
      .split("\n")
      .map((value) => value.trim())
      .filter(Boolean)
      .map((label) => ({ label }));

    const evidence = evidenceRaw
      .split("\n")
      .map((value) => value.trim())
      .filter(Boolean)
      .map((label) => ({ label }));

    const serverSupabase = await createSupabaseServerClient();

    const {
      data: { user: currentUser },
      error: currentUserError,
    } = await serverSupabase.auth.getUser();

    if (currentUserError || !currentUser) {
      redirect("/auth");
    }

    const { data, error } = await serverSupabase.rpc("create_proposal", {
      target_change_id: changeId,
      target_scope: scope,
      target_affected_system: affectedSystem,
      target_environment: environment,
      target_assumptions: assumptions,
      target_alternatives: alternatives,
      target_evidence: evidence,
      target_known_risks: knownRisks,
    });

    if (error) {
      throw new Error(error.message);
    }

    const result = Array.isArray(data) ? data[0] : data;

    if (
      !result?.proposal_id ||
      !result?.proposal_version_id ||
      !result?.review_cycle_id
    ) {
      throw new Error(
        "Proposal was created without the required workflow identifiers."
      );
    }

    if (submittedIntakeId) {
      const { error: consumeError } = await serverSupabase.rpc(
        "consume_bridge_intake",
        {
          target_bridge_intake_id: submittedIntakeId,
          target_proposal_id: result.proposal_id,
          target_proposal_version_id: result.proposal_version_id,
          target_review_cycle_id: result.review_cycle_id,
        }
      );

      if (consumeError) {
        throw new Error(consumeError.message);
      }
    }

    redirect(`/proposals/${result.review_cycle_id}`);
  }

  return (
    <main className="max-w-2xl mx-auto px-4 py-10">
      <Link
        href="/"
        className="text-sm text-blue-700 hover:underline"
      >
        Back to Judgment Engineering
      </Link>

      <h1 className="text-2xl font-bold mt-6 mb-2">
        Submit Change Proposal
      </h1>

      <p className="text-gray-600 mb-8">
        Create a versioned proposal for review. Submission creates Proposal
        Version 1 and opens a review cycle. It does not approve or implement
        the change.
      </p>

      {intakeId && !intakeClaimed && (
        <section className="border rounded p-4 mb-8 bg-gray-50">
          <h2 className="font-semibold text-lg mb-3">
            Lumos Bridge Intake
          </h2>

          <p className="text-sm text-gray-700 mb-4">
            A Lumos-reviewed intake is available for this JE workflow. Claiming
            it is an explicit human action. Claiming does not confirm a
            Judgment, approve a decision, or authorize implementation.
          </p>

          <form action={claimBridgeIntake}>
            <button
              type="submit"
              className="bg-blue-900 text-white px-6 py-3 rounded font-semibold"
            >
              Claim Intake
            </button>
          </form>
        </section>
      )}

      {bridgeIntake && intakeClaimed && (
        <section className="border rounded p-4 mb-8 bg-gray-50">
          <h2 className="font-semibold text-lg mb-3">
            Lumos Bridge Intake
          </h2>

          <dl className="space-y-2 text-sm">
            <div>
              <dt className="font-medium text-gray-700">Interaction</dt>
              <dd>{bridgeIntake.interaction_id}</dd>
            </div>

            <div>
              <dt className="font-medium text-gray-700">
                Human-reviewed representation
              </dt>
              <dd className="whitespace-pre-wrap mt-1">
                {bridgeIntake.reviewed_representation}
              </dd>
            </div>

            <div>
              <dt className="font-medium text-gray-700">
                Reviewer identity
              </dt>
              <dd>{bridgeIntake.reviewer_identity}</dd>
            </div>

            <div>
              <dt className="font-medium text-gray-700">
                Reviewed at
              </dt>
              <dd>{bridgeIntake.reviewed_at}</dd>
            </div>
          </dl>

          <p className="text-xs text-gray-600 mt-4">
            This is source context from Lumos. It does not constitute JE
            confirmation or decision authority. Complete and submit the
            Proposal fields deliberately before the existing JE review cycle
            begins.
          </p>
        </section>
      )}

      {(!intakeId || intakeClaimed) && (
      <form action={createProposal} className="space-y-6">
        {bridgeIntake && (
          <input
            type="hidden"
            name="intake_id"
            value={bridgeIntake.id}
          />
        )}

        <fieldset className="space-y-3">
          <legend className="font-semibold text-lg">
            Change
          </legend>

          <input
            name="change_id"
            required
            placeholder="Change ID"
            className="w-full border rounded p-3"
          />

          <textarea
            name="scope"
            required
            rows={3}
            placeholder="What exactly is changing? Define the reviewed scope."
            className="w-full border rounded p-3"
          />

          <input
            name="affected_system"
            required
            placeholder="Affected system"
            className="w-full border rounded p-3"
          />

          <input
            name="environment"
            required
            placeholder="Environment (for example: staging)"
            className="w-full border rounded p-3"
          />
        </fieldset>

        <fieldset className="space-y-3">
          <legend className="font-semibold text-lg">
            Judgment Context
          </legend>

          <textarea
            name="assumptions"
            required
            rows={3}
            placeholder="Assumptions"
            className="w-full border rounded p-3"
          />

          <textarea
            name="alternatives"
            required
            rows={4}
            placeholder={"Alternatives considered, one per line"}
            className="w-full border rounded p-3"
          />

          <textarea
            name="evidence"
            required
            rows={4}
            placeholder={"Evidence or source references, one per line"}
            className="w-full border rounded p-3"
          />

          <textarea
            name="known_risks"
            required
            rows={3}
            placeholder="Known risks"
            className="w-full border rounded p-3"
          />
        </fieldset>

        <div className="border rounded p-4 bg-gray-50">
          <p className="text-sm text-gray-700">
            The authenticated user submitting this form is recorded as the
            proposer. The proposal will enter reviewable state but cannot
            become an approved decision from this page.
          </p>
        </div>

        <button
          type="submit"
          className="bg-blue-900 text-white px-6 py-3 rounded font-semibold"
        >
          Submit for Review
        </button>
      </form>
      )}
    </main>
  );
}
