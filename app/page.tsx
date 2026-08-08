import { supabase } from "@/lib/supabaseClient";
import Link from "next/link";

export default async function Home() {
  const { data: units } = await supabase
    .from("judgment_units")
    .select("judgment_unit_id, title, department, status, outcome_status")
    .order("seq_num", { ascending: true });

  return (
    <main className="max-w-3xl mx-auto px-4 py-16 space-y-16">
      <section>
        <h1 className="text-3xl font-bold mb-3">Judgment Engineering</h1>
        <p className="text-gray-700 text-base leading-relaxed">
          Organizations preserve decisions. They often lose the reasoning
          behind them. This prototype captures, preserves, retrieves, and
          retrospectively evaluates that reasoning - as structured Judgment
          Units.
        </p>
        <div className="flex gap-4 mt-6">
          <Link
            href="/units"
            className="bg-black text-white text-sm px-4 py-2 rounded"
          >
            Browse Judgment Units
          </Link>
          
            <a
            href="https://github.com/edinburghray-cell/Judgment-Engineering"
            target="_blank"
            rel="noopener noreferrer"
            className="border text-sm px-4 py-2 rounded hover:bg-gray-50"
          >
            View on GitHub
          </a>
        </div>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-4">The Gap</h2>
        <div className="grid md:grid-cols-2 gap-4">
          <div className="border rounded p-4">
            <h3 className="font-medium mb-2">What gets kept</h3>
            <p className="text-sm text-gray-700">
              The decision itself. What was approved, what was built, what
              changed. The outcome, stripped of the thinking that produced it.
            </p>
          </div>
          <div className="border rounded p-4">
            <h3 className="font-medium mb-2">What gets lost</h3>
            <p className="text-sm text-gray-700">
              The options considered and rejected. The assumptions made. The
              risks accepted knowingly. The reasoning that would let someone
              else, or a future you, understand why, not just what.
            </p>
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-4">How It Works</h2>
        <div className="grid md:grid-cols-2 gap-4">
          <div className="border rounded p-4">
            <h3 className="font-medium mb-1">1. Capture</h3>
            <p className="text-sm text-gray-700">
              Record a decision while the reasoning is still fresh: the
              problem, the options, the choice, the assumptions, the risks.
            </p>
          </div>
          <div className="border rounded p-4">
            <h3 className="font-medium mb-1">2. Preserve</h3>
            <p className="text-sm text-gray-700">
              The judgment is stored as a structured, permanent record - not
              buried in a chat thread or a meeting no one wrote down.
            </p>
          </div>
          <div className="border rounded p-4">
            <h3 className="font-medium mb-1">3. Retrieve</h3>
            <p className="text-sm text-gray-700">
              Anyone can later reconstruct exactly why a decision was made,
              side by side with what was rejected and why.
            </p>
          </div>
          <div className="border rounded p-4">
            <h3 className="font-medium mb-1">4. Retrospective</h3>
            <p className="text-sm text-gray-700">
              After the outcome is known, the judgment is evaluated: what
              held true, what did not, and what would change next time.
            </p>
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-4">
          Five Canonical Judgment Units
        </h2>
        <div className="space-y-3">
          {units?.map((u) => (
            <Link
              key={u.judgment_unit_id}
              href={`/units`}
              className="block border rounded p-4 hover:bg-gray-50"
            >
              <div className="flex justify-between items-center">
                <span className="text-xs font-mono text-gray-400">
                  {u.judgment_unit_id}
                </span>
                <span className="text-xs px-2 py-1 rounded bg-gray-100">
                  {u.outcome_status
                    ? `Retrospective: ${u.outcome_status}`
                    : u.status}
                </span>
              </div>
              <p className="font-medium mt-1">{u.title}</p>
              <p className="text-xs text-gray-500">{u.department}</p>
            </Link>
          ))}
        </div>
      </section>

      <section className="border-t pt-8">
        <p className="text-sm text-gray-600">
          Explore the full catalog, or read the source on GitHub.
        </p>
        <div className="flex gap-4 mt-3">
          <Link href="/units" className="text-sm text-blue-700 hover:underline">
            Browse Judgment Units
          </Link>
          
            <a
            href="https://github.com/edinburghray-cell/Judgment-Engineering"
            target="_blank"
            rel="noopener noreferrer"
            className="text-sm text-blue-700 hover:underline"
          >
            GitHub Repository
          </a>
        </div>
      </section>
    </main>
  );
}

