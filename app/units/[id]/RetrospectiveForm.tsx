"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { recordJudgmentRetrospective } from "./retrospectiveAction";

export default function RetrospectiveForm({ id }: { id: string }) {
  const router = useRouter();
  const [outcomeStatus, setOutcomeStatus] = useState("");
  const [assumptionsConfirmed, setAssumptionsConfirmed] = useState("");
  const [assumptionsInvalidated, setAssumptionsInvalidated] = useState("");
  const [unexpectedRisks, setUnexpectedRisks] = useState("");
  const [nextTimeChanges, setNextTimeChanges] = useState("");
  const [futureDecisionGuidance, setFutureDecisionGuidance] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError("");

    const formData = new FormData();
    formData.set("target_judgment_id", id);
    formData.set("outcome_status", outcomeStatus);
    formData.set("assumptions_confirmed", assumptionsConfirmed);
    formData.set("assumptions_invalidated", assumptionsInvalidated);
    formData.set("unexpected_risks", unexpectedRisks);
    formData.set("next_time_changes", nextTimeChanges);
    formData.set("future_decision_guidance", futureDecisionGuidance);

    const result = await recordJudgmentRetrospective(formData);

    setSaving(false);

    if (result?.error) {
      setError(result.error);
      return;
    }

    router.refresh();
  }

  return (
    <form onSubmit={handleSubmit} className="mt-4 space-y-4 border-t pt-4">
      <h2 className="font-semibold">Add Retrospective</h2>

      <div>
        <label className="block text-sm font-medium mb-1">Outcome</label>
        <select
          value={outcomeStatus}
          onChange={(e) => setOutcomeStatus(e.target.value)}
          required
          className="border rounded px-2 py-1 text-sm w-full"
        >
          <option value="">Select outcome</option>
          <option value="Success">Success</option>
          <option value="Partial">Partial</option>
          <option value="Failure">Failure</option>
        </select>
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">
          Assumptions confirmed (which held true)
        </label>
        <textarea
          value={assumptionsConfirmed}
          onChange={(e) => setAssumptionsConfirmed(e.target.value)}
          className="border rounded px-2 py-1 text-sm w-full"
          rows={2}
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">
          Assumptions invalidated (which failed)
        </label>
        <textarea
          value={assumptionsInvalidated}
          onChange={(e) => setAssumptionsInvalidated(e.target.value)}
          className="border rounded px-2 py-1 text-sm w-full"
          rows={2}
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">
          Unexpected risks (what materialized that wasn't foreseen)
        </label>
        <textarea
          value={unexpectedRisks}
          onChange={(e) => setUnexpectedRisks(e.target.value)}
          className="border rounded px-2 py-1 text-sm w-full"
          rows={2}
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">
          What would be done differently next time
        </label>
        <textarea
          value={nextTimeChanges}
          onChange={(e) => setNextTimeChanges(e.target.value)}
          className="border rounded px-2 py-1 text-sm w-full"
          rows={2}
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">
          What should a future, related decision inherit from this?
        </label>
        <textarea
          value={futureDecisionGuidance}
          onChange={(e) => setFutureDecisionGuidance(e.target.value)}
          required
          className="border rounded px-2 py-1 text-sm w-full"
          rows={3}
        />
      </div>

      {error && <p className="text-sm text-red-600">{error}</p>}

      <button
        type="submit"
        disabled={saving}
        className="bg-black text-white text-sm px-4 py-2 rounded disabled:opacity-50"
      >
        {saving ? "Saving..." : "Save Retrospective"}
      </button>
    </form>
  );
}



