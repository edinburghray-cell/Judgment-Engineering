import Link from "next/link";

export default function Simulation2() {
  return (
    <main className="min-h-screen bg-white text-gray-900 px-6 py-10">
      <div className="max-w-4xl mx-auto">
        <Link href="/simulations" className="text-sm text-gray-600 hover:underline">
          ? Back to Simulations
        </Link>

        <div className="mt-10 border rounded-xl p-8">
          <p className="text-sm tracking-widest text-gray-500">SIMULATION 02</p>
          <h1 className="text-4xl font-semibold mt-3">The Capture</h1>
          <p className="text-lg text-gray-600 mt-4">
            This simulation demonstrates how individual expertise can be transformed
            into structured organizational memory through Judgment Engineering.
          </p>
        </div>

        <section className="mt-8 border rounded-xl p-8">
          <h2 className="text-2xl font-semibold">The expertise</h2>
          <p className="text-gray-600 mt-4">
            A decision maker carries knowledge that is rarely contained in the
            final decision alone. The useful part includes what was noticed,
            what was uncertain, which alternatives were rejected, and why the
            chosen path made sense at the time.
          </p>
        </section>

        <section className="mt-6 border rounded-xl p-8">
          <h2 className="text-2xl font-semibold">The capture</h2>
          <p className="text-gray-600 mt-4">
            Judgment Engineering converts that human expertise into a structured
            judgment record that can be preserved, retrieved, reviewed, and used
            by others without pretending that the original judgment can simply
            be replaced.
          </p>

          <div className="mt-6 border rounded-lg p-6 bg-gray-50">
            <p className="font-semibold">Judgment record</p>
            <div className="grid md:grid-cols-2 gap-4 mt-4 text-sm text-gray-600">
              <p><span className="font-medium text-gray-900">Decision:</span> What was decided</p>
              <p><span className="font-medium text-gray-900">Context:</span> What was happening</p>
              <p><span className="font-medium text-gray-900">Assumptions:</span> What was believed</p>
              <p><span className="font-medium text-gray-900">Alternatives:</span> What was considered</p>
              <p><span className="font-medium text-gray-900">Risks:</span> What was accepted</p>
              <p><span className="font-medium text-gray-900">Reasoning:</span> Why the choice made sense</p>
            </div>
          </div>
        </section>

        <section className="mt-6 border rounded-xl p-8">
          <h2 className="text-2xl font-semibold">The transformation</h2>
          <p className="text-gray-600 mt-4">
            The objective is not to automate the judgment. It is to prevent
            valuable human judgment from disappearing when the person who made
            the decision is no longer available.
          </p>
        </section>

        <section className="mt-6 border rounded-xl p-8">
          <h2 className="text-2xl font-semibold">The Judgment Engineering distinction</h2>
          <p className="text-gray-600 mt-4">
            Information tells an organization what happened. A preserved
            judgment record helps explain why it happened and what future
            decision makers should reconsider when circumstances change.
          </p>
        </section>

        <div className="mt-8 flex justify-between">
          <Link href="/simulations/1" className="border rounded px-4 py-2 text-sm">
            Previous Simulation
          </Link>
          <Link href="/simulations/3" className="bg-blue-900 text-white rounded px-4 py-2 text-sm">
            Next Simulation →
          </Link>
        </div>
      </div>
    </main>
  );
}
