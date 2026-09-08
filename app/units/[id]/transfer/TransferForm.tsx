"use client";

import { FormEvent, useRef, useState } from "react";

type TransferFormProps = {
  action: (formData: FormData) => void | Promise<void>;
};

export default function TransferForm({ action }: TransferFormProps) {
  const attemptIdRef = useRef<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    const form = event.currentTarget;
    const attemptInput = form.elements.namedItem("attempt_id") as HTMLInputElement | null;

    if (!attemptInput) {
      event.preventDefault();
      throw new Error("Missing transfer attempt field.");
    }

    if (submitting) {
      event.preventDefault();
      return;
    }

    if (!attemptIdRef.current) {
      attemptIdRef.current = crypto.randomUUID();
    }

    attemptInput.value = attemptIdRef.current;
    setSubmitting(true);
  }

  return (
    <form action={action} onSubmit={handleSubmit}>
      <input type="hidden" name="attempt_id" />

      <section className="border rounded-lg p-5 mt-6">
        <h2 className="text-xl font-semibold">
          What has changed?
        </h2>

        <p className="text-sm text-gray-600 mt-2">
          The preserved judgment is historical context. Before applying it,
          identify what is different about the situation you are facing now.
        </p>

        <textarea
          name="what_changed"
          placeholder="What is different now?"
          className="w-full border rounded p-3 mt-4 min-h-32"
          readOnly={submitting}
        />
      </section>

      <section className="border rounded-lg p-5 mt-6">
        <h2 className="text-xl font-semibold">
          Your judgment
        </h2>

        <p className="text-sm text-gray-600 mt-2">
          How should the preserved judgment be treated in the current
          situation?
        </p>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mt-5">
          <button
            type="submit"
            name="treatment"
            value="apply"
            disabled={submitting}
            className="border rounded-lg p-4 text-left hover:bg-gray-50 disabled:opacity-50"
          >
            <strong>Apply</strong>
            <span className="block text-sm text-gray-600 mt-1">
              The reasoning still applies.
            </span>
          </button>

          <button
            type="submit"
            name="treatment"
            value="adapt"
            disabled={submitting}
            className="border rounded-lg p-4 text-left hover:bg-gray-50 disabled:opacity-50"
          >
            <strong>Adapt</strong>
            <span className="block text-sm text-gray-600 mt-1">
              The reasoning is useful, but circumstances have changed.
            </span>
          </button>

          <button
            type="submit"
            name="treatment"
            value="reject"
            disabled={submitting}
            className="border rounded-lg p-4 text-left hover:bg-gray-50 disabled:opacity-50"
          >
            <strong>Reject</strong>
            <span className="block text-sm text-gray-600 mt-1">
              The original reasoning no longer applies.
            </span>
          </button>
        </div>
      </section>
    </form>
  );
}

