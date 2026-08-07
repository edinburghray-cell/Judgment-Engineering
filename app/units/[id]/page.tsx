import { supabase } from '@/lib/supabaseClient';
import Link from 'next/link';
import { notFound } from 'next/navigation';

export default async function UnitDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const { data: unit, error } = await supabase
    .from('judgment_units')
    .select('*')
    .eq('id', id)
    .single();

  if (error || !unit) return notFound();

  const options: { label: string }[] = unit.options ?? [];
  const rejected: { label: string; reason_rejected?: string }[] =
    unit.rejected_options ?? [];
  const evidence: { label: string }[] = unit.evidence ?? [];

  return (
    <main className="max-w-3xl mx-auto px-4 py-10">
      <Link href="/units" className="text-sm text-blue-700 hover:underline">
        Back to Judgment Units
      </Link>

      <div className="flex items-center justify-between mt-4 mb-1">
        <span className="text-xs font-mono text-gray-400">
          {unit.judgment_unit_id}
          {unit.judgment_version > 1 && ` v${unit.judgment_version}`}
        </span>
        <span className="text-xs px-2 py-1 rounded bg-gray-100 font-medium">
          {unit.status}
        </span>
      </div>
      <h1 className="text-2xl font-bold mb-1">{unit.title}</h1>
      <p className="text-gray-500 text-sm mb-8">
        {unit.department || 'N/A'} - {unit.decision_owner || 'N/A'} -{' '}
        {unit.decision_date}
      </p>

      <div className="grid md:grid-cols-2 gap-4">
        <section className="border rounded p-4">
          <h2 className="font-semibold mb-2">Context and Situation Trigger</h2>
          <p className="text-sm text-gray-700 whitespace-pre-wrap">
            {unit.situation || 'Not recorded.'}
          </p>
          {unit.problem && (
            <>
              <h3 className="text-sm font-medium mt-3 mb-1">Problem</h3>
              <p className="text-sm text-gray-700 whitespace-pre-wrap">
                {unit.problem}
              </p>
            </>
          )}
        </section>

        <section className="border rounded p-4">
          <h2 className="font-semibold mb-2">Chosen Rationale vs Rejected</h2>
          <div className="text-sm">
            <p className="font-medium text-green-700">
              Chosen: {unit.chosen_option || 'N/A'}
            </p>
            <p className="text-gray-700 whitespace-pre-wrap mt-1">
              {unit.rationale || 'No rationale recorded.'}
            </p>
          </div>
          {rejected.length > 0 && (
            <div className="mt-3 space-y-1">
              {rejected.map((r, i) => (
                <p key={i} className="text-sm text-gray-500">
                  Rejected: {r.label}
                  {r.reason_rejected ? ` - ${r.reason_rejected}` : ''}
                </p>
              ))}
            </div>
          )}
          {options.length > 0 && (
            <p className="text-xs text-gray-400 mt-3">
              All options considered: {options.map((o) => o.label).join(', ')}
            </p>
          )}
        </section>

        <section className="border rounded p-4">
          <h2 className="font-semibold mb-2">
            Explicit Assumptions and Accepted Risks
          </h2>
          <h3 className="text-sm font-medium mb-1">Assumptions</h3>
          <p className="text-sm text-gray-700 whitespace-pre-wrap mb-3">
            {unit.assumptions || 'Not recorded.'}
          </p>
          <h3 className="text-sm font-medium mb-1">Accepted Risks</h3>
          <p className="text-sm text-gray-700 whitespace-pre-wrap">
            {unit.accepted_risks || 'Not recorded.'}
          </p>
        </section>

        <section className="border rounded p-4">
          <h2 className="font-semibold mb-2">Linked Evidence and Metrics</h2>
          {evidence.length > 0 ? (
            <ul className="text-sm text-gray-700 list-disc list-inside mb-3">
              {evidence.map((e, i) => (
                <li key={i}>{e.label}</li>
              ))}
            </ul>
          ) : (
            <p className="text-sm text-gray-500 mb-3">No evidence linked.</p>
          )}
          <h3 className="text-sm font-medium mb-1">Success Metrics</h3>
          <p className="text-sm text-gray-700 whitespace-pre-wrap">
            {unit.success_metrics || 'Not recorded.'}
          </p>
        </section>
      </div>

      <div className="mt-6 border-t pt-4">
        {unit.outcome_status ? (
          <p className="text-sm text-gray-600">
            Retrospective on file - outcome:{' '}
            <span className="font-medium">{unit.outcome_status}</span>
          </p>
        ) : (
          <p className="text-sm text-gray-400">
            No retrospective yet. (Stage 3 - coming next.)
          </p>
        )}
      </div>
    </main>
  );
}
