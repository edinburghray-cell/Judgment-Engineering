import Link from "next/link";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabaseServer";

export default async function NewProposalPage() {
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

    const supabase = await createSupabaseServerClient();

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      redirect("/auth");
    }

    const { data, error } = await supabase.rpc("create_proposal", {
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

    if (!result?.review_cycle_id) {
      throw new Error("Proposal was created without a review cycle.");
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

      <form action={createProposal} className="space-y-6">
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
    </main>
  );
}
