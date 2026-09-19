"use client";

import { useState } from "react";

type JudgmentDraft = {
  id: string;
  title: string;
  situation: string | null;
  problem: string | null;
  options: unknown;
  rationale: string | null;
  assumptions: string | null;
  evidence: unknown;
  accepted_risks: string | null;
  success_metrics: string | null;
  chosen_option: string | null;
  rejected_options: unknown;
  decision_owner: string | null;
};

type JudgmentDraftReviewFormProps = {
  draft: JudgmentDraft;
  action: (formData: FormData) => void | Promise<void>;
};

const textFields = [
  "title",
  "situation",
  "problem",
  "rationale",
  "assumptions",
  "accepted_risks",
  "success_metrics",
  "chosen_option",
  "decision_owner",
] as const;

const jsonFields = [
  "options",
  "evidence",
  "rejected_options",
] as const;

type TextField = (typeof textFields)[number];
type JsonField = (typeof jsonFields)[number];
type EditableField = TextField | JsonField;

function displayValue(value: unknown) {
  if (value === null || value === undefined) {
    return "";
  }

  if (typeof value === "string") {
    return value;
  }

  return JSON.stringify(value, null, 2);
}

export default function JudgmentDraftReviewForm({
  draft,
  action,
}: JudgmentDraftReviewFormProps) {
  const allFields = [...textFields, ...jsonFields];

  const [values, setValues] = useState<Record<EditableField, string>>(() =>
    Object.fromEntries(
      allFields.map((field) => [field, displayValue(draft[field])])
    ) as Record<EditableField, string>
  );

  const [reason, setReason] = useState("");
  const [submittingField, setSubmittingField] =
    useState<EditableField | null>(null);
  const [jsonErrors, setJsonErrors] = useState<
    Partial<Record<JsonField, string>>
  >({});

  async function handleSubmit(
    event: React.FormEvent<HTMLFormElement>,
    field: EditableField
  ) {
    event.preventDefault();

    if (submittingField) {
      return;
    }

    const correctionReason = reason.trim();

    if (!correctionReason) {
      return;
    }

    let correctedValue: string;

    if (jsonFields.includes(field as JsonField)) {
      try {
        const parsed = JSON.parse(values[field]);

        if (
          field === "options" ||
          field === "evidence" ||
          field === "rejected_options"
        ) {
          if (!Array.isArray(parsed)) {
            setJsonErrors((current) => ({
              ...current,
              [field]: "Value must be a JSON array.",
            }));
            return;
          }
        }

        correctedValue = JSON.stringify(parsed);
        setJsonErrors((current) => ({
          ...current,
          [field]: undefined,
        }));
      } catch {
        setJsonErrors((current) => ({
          ...current,
          [field]: "Enter valid JSON.",
        }));
        return;
      }
    } else {
      correctedValue = values[field];
    }

    setSubmittingField(field);

    const payload = new FormData();
    payload.set("field", field);
    payload.set(
      "corrected_value",
      jsonFields.includes(field as JsonField)
        ? correctedValue
        : JSON.stringify(correctedValue)
    );
    payload.set("correction_reason", correctionReason);

    try {
      await action(payload);
      setReason("");
    } finally {
      setSubmittingField(null);
    }
  }

  return (
    <div className="space-y-6">
      <div className="rounded-lg border border-blue-200 bg-blue-50 p-4">
        <p className="text-sm text-blue-900">
          Review and correct the structured Judgment Draft before confirmation.
          Corrections are preserved as human review evidence. Editing does not
          confirm the Judgment.
        </p>
      </div>

      <div className="space-y-6">
        {textFields.map((field) => (
          <div key={field}>
            <label
              htmlFor={`draft-${field}`}
              className="block text-sm font-medium mb-2 capitalize"
            >
              {field.replaceAll("_", " ")}
            </label>

            <textarea
              id={`draft-${field}`}
              rows={field === "title" || field === "decision_owner" ? 2 : 4}
              value={values[field]}
              disabled={submittingField !== null}
              onChange={(event) =>
                setValues((current) => ({
                  ...current,
                  [field]: event.target.value,
                }))
              }
              className="w-full border rounded p-3 text-sm"
            />

            <form
              onSubmit={(event) => handleSubmit(event, field)}
              className="mt-2"
            >
              <input
                type="text"
                value={reason}
                disabled={submittingField !== null}
                onChange={(event) => setReason(event.target.value)}
                placeholder="Reason for this correction"
                className="w-full border rounded p-2 text-sm mb-2"
              />

              <button
                type="submit"
                disabled={
                  submittingField !== null ||
                  !reason.trim() ||
                  values[field] === displayValue(draft[field])
                }
                className="px-3 py-2 rounded border font-medium disabled:opacity-50"
              >
                {submittingField === field
                  ? "Saving..."
                  : "Save correction"}
              </button>
            </form>
          </div>
        ))}

        {jsonFields.map((field) => (
          <div key={field}>
            <label
              htmlFor={`draft-${field}`}
              className="block text-sm font-medium mb-2 capitalize"
            >
              {field.replaceAll("_", " ")}
            </label>

            <textarea
              id={`draft-${field}`}
              rows={6}
              value={values[field]}
              disabled={submittingField !== null}
              onChange={(event) =>
                setValues((current) => ({
                  ...current,
                  [field]: event.target.value,
                }))
              }
              className="w-full border rounded p-3 text-sm font-mono"
            />

            {jsonErrors[field] ? (
              <p className="text-sm text-red-600 mt-1">
                {jsonErrors[field]}
              </p>
            ) : null}

            <form
              onSubmit={(event) => handleSubmit(event, field)}
              className="mt-2"
            >
              <input
                type="text"
                value={reason}
                disabled={submittingField !== null}
                onChange={(event) => setReason(event.target.value)}
                placeholder="Reason for this correction"
                className="w-full border rounded p-2 text-sm mb-2"
              />

              <button
                type="submit"
                disabled={
                  submittingField !== null ||
                  !reason.trim() ||
                  values[field] === displayValue(draft[field])
                }
                className="px-3 py-2 rounded border font-medium disabled:opacity-50"
              >
                {submittingField === field
                  ? "Saving..."
                  : "Save correction"}
              </button>
            </form>
          </div>
        ))}
      </div>
    </div>
  );
}

