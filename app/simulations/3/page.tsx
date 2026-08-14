import Link from "next/link";

export default function Simulation3() {
  return (
    <main className="min-h-screen bg-white text-gray-900 px-6 py-10">
      <div className="max-w-4xl mx-auto">
        <Link href="/simulations" className="text-sm text-gray-600 hover:underline">
          ? Back to Simulations
        </Link>

        <div className="mt-10 border rounded-xl p-8">
          <p className="text-sm tracking-widest text-gray-500">SIMULATION 03</p>
          <h1 className="text-4xl font-semibold mt-3">The Transfer</h1>
          <p className="text-lg text-gray-600 mt-4">
            Preserved judgment can move from one person to another, and from
            human decision makers into AI-assisted systems.
          </p>
        </div>

        <section className="mt-8 border rounded-xl p-8">
          <h2 className="text-2xl font-semibold">From human decision to structured memory</h2>
          <p className="text-gray-600 mt-4">
            A useful judgment record allows future decision makers to inherit
            more than historical facts. They inherit the reasoning that shaped
            the earlier decision.
          </p>

          <div className="mt-6 grid md:grid-cols-3 gap-4">
            <div className="border rounded-lg p-5">
              <p className="font-semibold">Human judgment</p>
              <p className="text-sm text-gray-600 mt-2">
                Experience, context, uncertainty and reasoning.
              </p>
            </div>
            <div className="border rounded-lg p-5">
              <p className="font-semibold">Structured memory</p>
              <p className="text-sm text-gray-600 mt-2">
                The reasoning is captured in a reusable form.
              </p>
            </div>
            <div className="border rounded-lg p-5">
              <p className="font-semibold">Future decision</p>
              <p className="text-sm text-gray-600 mt-2">
                Another person can evaluate the inherited judgment.
              </p>
            </div>
          </div>
        </section>

        <section className="mt-6 border rounded-xl p-8">
          <h2 className="text-2xl font-semibold">Information vs. judgment for AI</h2>
          <p className="text-gray-600 mt-4">
            AI systems can retrieve and process large amounts of information.
            The value of preserved judgment is different. It provides structured
            human reasoning that helps an AI-assisted system understand not only
            what was decided, but the conditions and assumptions surrounding it.
          </p>
        </section>

        <section className="mt-6 border rounded-xl p-8">
          <h2 className="text-2xl font-semibold">The transfer</h2>
          <p className="text-gray-600 mt-4">
            The objective is not to make the machine the original decision maker.
            The objective is to make preserved human judgment available as a
            decision support layer.
          </p>
        </section>

        <div className="mt-8 flex justify-between">
          <Link href="/simulations/2" className="border rounded px-4 py-2 text-sm">
            Previous Simulation
          </Link>
          <Link href="/simulations/4" className="bg-blue-900 text-white rounded px-4 py-2 text-sm">
            Next Simulation →
          </Link>
        </div>
      </div>
    </main>
  );
}
