'use client';

import { useState } from 'react';
import { supabase } from '@/lib/supabaseClient';
import { useRouter } from 'next/navigation';

export default function CapturePage() {
  const router = useRouter();
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const [form, setForm] = useState({
    title: '',
    department: '',
    decision_owner: '',
    status: 'Proposed',
    situation: '',
    problem: '',
    rationale: '',
    assumptions: '',
    accepted_risks: '',
    success_metrics: '',
    chosen_option: '',
  });

  const [optionsRaw, setOptionsRaw] = useState('');
  const [rejectedRaw, setRejectedRaw] = useState('');
  const [evidenceRaw, setEvidenceRaw] = useState('');

  function update(field: string, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError('');

    const payload = {
      ...form,
      options: optionsRaw
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean)
        .map((label) => ({ label })),
      rejected_options: rejectedRaw
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean)
        .map((label) => ({ label, reason_rejected: '' })),
      evidence: evidenceRaw
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean)
        .map((label) => ({ label })),
    };

    const { error: insertError } = await supabase
      .from('judgment_units')
      .insert(payload);

    setSaving(false);

    if (insertError) {
      setError(insertError.message);
      return;
    }

    router.push('/units');
  }

  return (
    <main className="max-w-2xl mx-auto px-4 py-10">
      <h1 className="text-2xl font-bold mb-1">Capture a Decision</h1>
      <p className="text-gray-600 mb-8">
        Convert real-time rationale into a structured Judgment Unit.
      </p>

      <form onSubmit={handleSubmit} className="space-y-8">
        <fieldset className="space-y-3">
          <legend className="font-semibold text-lg mb-2">
            1. Metadata & Ownership
          </legend>
          <input
            required
            placeholder="Title"
            className="w-full border rounded p-2"
            value={form.title}
            onChange={(e) => update('title', e.target.value)}
          />
          <div className="grid grid-cols-2 gap-3">
            <input
              placeholder="Department"
              className="border rounded p-2"
              value={form.department}
              onChange={(e) => update('department', e.target.value)}
            />
            <input
              placeholder="Decision Owner"
              className="border rounded p-2"
              value={form.decision_owner}
              onChange={(e) => update('decision_owner', e.target.value)}
            />
          </div>
          <select
            className="w-full border rounded p-2"
            value={form.status}
            onChange={(e) => update('status', e.target.value)}
          >
            <option>Proposed</option>
            <option>Approved</option>
            <option>Implemented</option>
            <option>Rejected</option>
          </select>
        </fieldset>

        <fieldset className="space-y-3">
          <legend className="font-semibold text-lg mb-2">
            2. Context & Trigger
          </legend>
          <textarea
            placeholder="What prompted this decision? Why now?"
            className="w-full border rounded p-2"
            rows={3}
            value={form.situation}
            onChange={(e) => update('situation', e.target.value)}
          />
        </fieldset>

        <fieldset className="space-y-3">
          <legend className="font-semibold text-lg mb-2">
            3. The 7 Preservation Questions
          </legend>
          <textarea
            placeholder="1. Problem — what problem is being solved?"
            className="w-full border rounded p-2"
            rows={2}
            value={form.problem}
            onChange={(e) => update('problem', e.target.value)}
          />
          <input
            placeholder="2. Options considered (comma-separated)"
            className="w-full border rounded p-2"
            value={optionsRaw}
            onChange={(e) => setOptionsRaw(e.target.value)}
          />
          <input
            placeholder="Chosen option"
            className="w-full border rounded p-2"
            value={form.chosen_option}
            onChange={(e) => update('chosen_option', e.target.value)}
          />
          <input
            placeholder="Rejected options (comma-separated)"
            className="w-full border rounded p-2"
            value={rejectedRaw}
            onChange={(e) => setRejectedRaw(e.target.value)}
          />
          <textarea
            placeholder="3. Rationale — why this option?"
            className="w-full border rounded p-2"
            rows={3}
            value={form.rationale}
            onChange={(e) => update('rationale', e.target.value)}
          />
          <textarea
            placeholder="4. Assumptions being made"
            className="w-full border rounded p-2"
            rows={2}
            value={form.assumptions}
            onChange={(e) => update('assumptions', e.target.value)}
          />
          <input
            placeholder="5. Evidence / sources (comma-separated)"
            className="w-full border rounded p-2"
            value={evidenceRaw}
            onChange={(e) => setEvidenceRaw(e.target.value)}
          />
          <textarea
            placeholder="6. Risks knowingly accepted"
            className="w-full border rounded p-2"
            rows={2}
            value={form.accepted_risks}
            onChange={(e) => update('accepted_risks', e.target.value)}
          />
          <textarea
            placeholder="7. Success metrics — how will we know this worked?"
            className="w-full border rounded p-2"
            rows={2}
            value={form.success_metrics}
            onChange={(e) => update('success_metrics', e.target.value)}
          />
        </fieldset>

        {error && <p className="text-red-600 text-sm">{error}</p>}

        <button
          type="submit"
          disabled={saving}
          className="bg-blue-900 text-white px-6 py-2 rounded font-semibold disabled:opacity-50"
        >
          {saving ? 'Saving…' : 'Commit Judgment Unit'}
        </button>
      </form>
    </main>
  );
}