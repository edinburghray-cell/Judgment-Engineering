"use client";

import { useState } from "react";

export default function RecoverySection({
  action,
}: {
  action: (formData: FormData) => void | Promise<void>;
}) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <div className="text-right mt-6">
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="text-sm underline"
          aria-expanded={open}
          aria-controls="recovery"
        >
          Forgot password?
        </button>
      </div>
      {open && (
        <form id="recovery" action={action} className="mt-5 border-t pt-4">
          <div className="flex items-center justify-between">
            <label htmlFor="recovery-email" className="block text-sm font-medium">
              Forgot password?
            </label>
            <button
              type="button"
              onClick={() => setOpen(false)}
              className="text-sm underline"
              aria-label="Close password recovery"
            >
              Close
            </button>
          </div>
          <p className="text-sm text-gray-600 mt-1">
            Enter your registered email and we’ll send a recovery link.
          </p>
          <input
            id="recovery-email"
            name="email"
            type="email"
            required
            className="w-full border rounded p-3 mt-2"
            placeholder="Email address"
          />
          <button className="mt-3 border rounded px-4 py-2">
            Send recovery email
          </button>
        </form>
      )}
    </>
  );
}
