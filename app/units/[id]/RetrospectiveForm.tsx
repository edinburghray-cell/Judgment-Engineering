"use client";

import { useState } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useRouter } from "next/navigation";

export default function RetrospectiveForm({ id }: { id: string }) {
  const router = useRouter();
  const [outcomeStatus, setOutcomeStatus] = useState("");
  const [assumptionsConfirmed, setAssumptionsConfirmed] = useState("");
  const [assumptionsInvalidated, setAssumptionsInvalidated] = useState("");
  const [unexpectedRisks, setUnexpectedRisks] = useState("");
  const [nextTimeChanges, setNextTimeChanges] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError("");

    const { error } = await supabase
      .from("judgment_units")
      .update({
        outcome_status: outcomeStatus,
        assumptions_confirmed: assumptionsConfirmed,
        assumptions_invalidated: assumptionsInvalidated,
        unexpected_risks: unexpectedRisks,
        next_time_changes: nextTimeChanges,
        retrospective_date: new Date().toISOString().split("T")[0],
      })
      .eq("id", id);

    setSaving(false);

    if (error) {
      setError(error.message);
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
