import { supabase } from '@/lib/supabaseClient';
import Link from 'next/link';

const STATUS_COLORS: Record<string, string> = {
  Proposed: 'bg-gray-100 text-gray-700',
  Approved: 'bg-blue-100 text-blue-700',
  Implemented: 'bg-green-100 text-green-700',
  Rejected: 'bg-red-100 text-red-700',
};

export default async function UnitsPage({
  searchParams,
}: {
  searchParams: Promise<{ department?: string; owner?: string; keyword?: string }>;
}) {
  const { department, owner, keyword } = await searchParams;
  let query = supabase
    .from('judgment_units')
    .select(
      'id, judgment_unit_id, title, department, decision_owner, status, decision_date'
    )
    .eq('deleted', false)
    .order('created_at', { ascending: false });

  if (department) query = query.ilike('department', `%${department}%`);
  if (owner) query = query.ilike('decision_owner', `%${owner}%`);
  if (keyword) query = query.or(`title.ilike.%${keyword}%,problem.ilike.%${keyword}%`);

  const { data: units, error } = await query;

  return (
    <main className="max-w-3xl mx-auto px-4 py-10">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold">Judgment Units</h1>
          <p className="text-gray-600">
            Browse the catalog. Open a unit to reconstruct why it was made.
          </p>
        </div>
        <Link
          href="/capture"
          className="bg-blue-900 text-white px-4 py-2 rounded font-semibold whitespace-nowrap"
        >
          + Capture New
        </Link>
      </div>

      <form method="get" className="grid grid-cols-3 gap-2 mb-6">
        <input
          name="department"
          defaultValue={department}
          placeholder="Filter by department"
          className="border rounded p-2 text-sm"
        />
        <input
          name="owner"
          defaultValue={owner}
          placeholder="Filter by owner"
          className="border rounded p-2 text-sm"
        />
        <input
          name="keyword"
          defaultValue={keyword}
          placeholder="Keyword"
          className="border rounded p-2 text-sm"
        />
        <button
          type="submit"
          className="col-span-3 border rounded p-2 text-sm font-semibold hover:bg-gray-50"
        >
          Apply filters
        </button>
      </form>

      {error && <p className="text-red-600 text-sm">{error.message}</p>}

      {units && units.length === 0 && (
        <p className="text-gray-500 text-sm border rounded p-6 text-center">
          No judgment units yet. Capture your first decision to get started.
        </p>
      )}

      <div className="space-y-3">
        {units?.map((u) => (
          <Link
            key={u.id}
            href={`/units/${u.id}`}
            className="block border rounded p-4 hover:border-blue-400 transition"
          >
            <div className="flex items-center justify-between">
              <span className="text-xs font-mono text-gray-400">
                {u.judgment_unit_id}
              </span>
              <span
                className={`text-xs px-2 py-1 rounded font-medium ${
                  STATUS_COLORS[u.status] ?? 'bg-gray-100 text-gray-700'
                }`}
              >
                {u.status}
              </span>
            </div>
            <h2 className="font-semibold mt-1">{u.title}</h2>
            <p className="text-sm text-gray-500">
              {u.department || '—'} · {u.decision_owner || '—'} ·{' '}
              {u.decision_date}
            </p>
          </Link>
        ))}
      </div>
    </main>
  );
}