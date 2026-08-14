import Link from "next/link";

export default function Simulation4() {
  return (
    <main className="min-h-screen bg-white text-gray-900 px-6 py-10">
      <div className="max-w-4xl mx-auto">
        <Link href="/simulations" className="text-sm text-gray-600 hover:underline">
          ? Back to Simulations
        </Link>

        <div className="mt-10 border rounded-xl p-8">
          <p className="text-sm tracking-widest text-gray-500">SIMULATION 04</p>
          <h1 className="text-4xl font-semibold mt-3">The Institution</h1>
          <p className="text-lg text-gray-600 mt-4">
            Judgment Engineering becomes an organizational capability when
            preserved judgment can be systematically captured, retrieved,
            evaluated, and improved.
          </p>
        </div>

        <section className="mt-8 border rounded-xl p-8">
          <h2 className="text-2xl font-semibold">Evolution of organizational memory</h2>
          <p className="text-gray-600 mt-4">
            Organizations traditionally preserve documents, records and events.
            A stronger memory preserves the reasoning that made important
            decisions intelligible.
          </p>

          <div className="mt-6 grid md:grid-cols-4 gap-3">
            <div className="border rounded-lg p-4 text-sm">Events</div>
            <div className="border rounded-lg p-4 text-sm">Information</div>
            <div className="border rounded-lg p-4 text-sm">Judgment</div>
            <div className="border rounded-lg p-4 text-sm">Organizational memory</div>
          </div>
        </section>

        <section className="mt-6 border rounded-xl p-8">
          <h2 className="text-2xl font-semibold">The organizational learning loop</h2>
          <p className="text-gray-600 mt-4">
            Preserved judgment creates a continuous learning cycle. Decisions
            can be captured, revisited, evaluated against outcomes, and refined
            as circumstances change.
          </p>

          <div className="mt-6 grid md:grid-cols-4 gap-3">
            <div className="border rounded-lg p-4">
              <p className="font-semibold">Capture</p>
              <p className="text-sm text-gray-600 mt-2">Preserve the reasoning.</p>
            </div>
            <div className="border rounded-lg p-4">
              <p className="font-semibold">Retrieve</p>
              <p className="text-sm text-gray-600 mt-2">Find relevant judgment.</p>
            </div>
            <div className="border rounded-lg p-4">
              <p className="font-semibold">Evaluate</p>
              <p className="text-sm text-gray-600 mt-2">Compare judgment with outcomes.</p>
            </div>
            <div className="border rounded-lg p-4">
              <p className="font-semibold">Improve</p>
              <p className="text-sm text-gray-600 mt-2">Update future decisions.</p>
            </div>
          </div>
        </section>

        <section className="mt-6 border rounded-xl p-8">
          <h2 className="text-2xl font-semibold">The institution</h2>
          <p className="text-gray-600 mt-4">
            At this stage, Judgment Engineering is no longer simply a way to
            document individual decisions. It becomes part of how the
            organization learns from its own judgment over time.
          </p>
        </section>

        <div className="mt-8 flex justify-between">
          <Link href="/simulations/3" className="border rounded px-4 py-2 text-sm">
            Previous Simulation
          </Link>
          <Link href="/simulations" className="bg-blue-900 text-white rounded px-4 py-2 text-sm">
            All Simulations
          </Link>
        </div>
      </div>
    </main>
  );
}
