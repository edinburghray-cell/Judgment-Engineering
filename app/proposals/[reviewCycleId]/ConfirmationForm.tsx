"use client";

import { useState } from "react";

type AvailableJudgment = {
  id: string;
  judgment_unit_id: string;
  title: string;
  committed_at: string;
};

type ConfirmationFormProps = {
  action: (formData: FormData) => void | Promise<void>;
  availableJudgments: AvailableJudgment[];
};

export default function ConfirmationForm({
  action,
  availableJudgments,
}: ConfirmationFormProps) {
  const [isSupersession, setIsSupersession] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (submitting) {
      return;
    }

    setSubmitting(true);

    const formData = new FormData(event.currentTarget);
    formData.set("is_supersession", isSupersession ? "true" : "false");

    try {
      await action(formData);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <div className="mb-4">
        <label
          htmlFor="predecessor_judgment_id"
          className="block text-sm font-medium mb-2"
        >
          Prior Judgment (optional)
        </label>

        <select
          id="predecessor_judgment_id"
          name="predecessor_judgment_id"
          defaultValue=""
          disabled={submitting}
          className="w-full border rounded p-3 text-sm"
        >
          <option value="">None — this is a source Judgment</option>

          {availableJudgments.map((judgment) => (
            <option key={judgment.id} value={judgment.id}>
              {judgment.judgment_unit_id} — {judgment.title}
            </option>
          ))}
        </select>

        <p className="text-xs text-gray-500 mt-2">
          Select an existing preserved Judgment only when this Judgment is
          explicitly related to its prior reasoning.
        </p>
      </div>

      <div className="mb-4">
        <label
          htmlFor="reconsideration_conditions"
          className="block text-sm font-medium mb-2"
        >
          What would make you reconsider this judgment?
        </label>

        <textarea
          id="reconsideration_conditions"
          name="reconsideration_conditions"
          required
          rows={4}
          disabled={submitting}
          className="w-full border rounded p-3 text-sm"
        />
      </div>

      <div className="mb-4 border rounded-lg p-4">
        <label className="flex items-start gap-3 cursor-pointer">
          <input
            type="checkbox"
            name="is_supersession"
            value="true"
            checked={isSupersession}
            onChange={(event) => setIsSupersession(event.target.checked)}
            disabled={submitting}
            className="mt-1"
          />

          <span>
            <span className="block text-sm font-medium">
              Supersedes Prior Judgment
            </span>
            <span className="block text-xs text-gray-500 mt-1">
              Check only when this Judgment replaces the selected prior
              Judgment because the situation has materially changed.
            </span>
          </span>
        </label>

        {isSupersession ? (
          <div className="mt-4 space-y-4">
            <div>
              <label
                htmlFor="supersession_rationale"
                className="block text-sm font-medium mb-2"
              >
                Why does the prior Judgment no longer apply?
              </label>

              <textarea
                id="supersession_rationale"
                name="supersession_rationale"
                required
                rows={4}
                disabled={submitting}
                className="w-full border rounded p-3 text-sm"
              />
            </div>

            <div>
              <label
                htmlFor="validation_basis"
                className="block text-sm font-medium mb-2"
              >
                What validation evidence supports this supersession?
              </label>

              <textarea
                id="validation_basis"
                name="validation_basis"
                required
                rows={4}
                disabled={submitting}
                className="w-full border rounded p-3 text-sm"
              />
            </div>
          </div>
        ) : null}
      </div>

      <button
        type="submit"
        disabled={submitting}
        className="px-4 py-2 rounded bg-black text-white font-medium disabled:opacity-50"
      >
        {submitting ? "Confirming..." : "Confirm Judgment"}
      </button>
    </form>
  );
}
