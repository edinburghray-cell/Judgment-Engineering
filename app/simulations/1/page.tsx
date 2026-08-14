"use client";

import { useState } from "react";
import Link from "next/link";

export default function SimulationOne() {
  const [view, setView] = useState<"event" | "judgment">("event");

  return (
    <main className="max-w-5xl mx-auto px-4 py-10">
      <Link
        href="/simulations"
        className="text-sm text-blue-700 hover:underline"
      >
        ? Back to Simulations
      </Link>

      <div className="mt-8">
        <p className="text-xs font-mono tracking-widest text-gray-400">
          SIMULATION 01
        </p>

        <h1 className="text-4xl font-bold mt-2">The Loss</h1>

        <p className="text-lg text-gray-600 mt-4 max-w-3xl">
          An organization can preserve what happened while losing the
          reasoning that explains why it happened.
        </p>
      </div>

      <section className="mt-8 border rounded-xl p-6">
        <h2 className="text-xl font-semibold mb-3">
          The decision
        </h2>

        <p className="text-gray-700 leading-7">
          A team decides to change an operational process because the
          existing approach is creating repeated delays. The decision is
          recorded, implemented, and eventually becomes part of the normal
          operating process.
        </p>

        <div className="mt-5 rounded-lg bg-gray-50 p-5">
          <p className="text-sm text-gray-500 mb-2">
            What remains months later?
          </p>

          <p className="font-medium">
            The organization can usually find the decision.
          </p>

          <p className="text-gray-600 mt-2">
            But can it reconstruct the judgment that produced it?
          </p>
        </div>
      </section>

      <section className="mt-6 border rounded-xl p-6">
        <div className="flex flex-wrap gap-2 mb-6">
          <button
            onClick={() => setView("event")}
            className={`px-4 py-2 rounded text-sm font-medium ${
              view === "event"
                ? "bg-blue-900 text-white"
                : "border hover:bg-gray-50"
            }`}
          >
            What was recorded
          </button>

          <button
            onClick={() => setView("judgment")}
            className={`px-4 py-2 rounded text-sm font-medium ${
              view === "judgment"
                ? "bg-blue-900 text-white"
                : "border hover:bg-gray-50"
            }`}
          >
            What was lost
          </button>
        </div>

        {view === "event" ? (
          <div>
            <h2 className="text-xl font-semibold">
              The organizational record
            </h2>

            <div className="mt-4 border rounded-lg p-5">
              <p className="text-sm text-gray-500">
                Decision record
              </p>

              <p className="font-semibold mt-2">
                Process changed
              </p>

              <p className="text-gray-600 mt-2">
                The team changed the process to reduce recurring delays.
              </p>

              <div className="mt-5 grid md:grid-cols-3 gap-3 text-sm">
                <div className="bg-gray-50 rounded p-3">
                  <span className="text-gray-500 block">Decision</span>
                  Process changed
                </div>

                <div className="bg-gray-50 rounded p-3">
                  <span className="text-gray-500 block">Owner</span>
                  Operations team
                </div>

                <div className="bg-gray-50 rounded p-3">
                  <span className="text-gray-500 block">Outcome</span>
                  Delays reduced
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div>
            <h2 className="text-xl font-semibold">
              The missing judgment layer
            </h2>

            <div className="mt-4 border rounded-lg p-5">
              <p className="text-sm text-gray-500">
                Questions the ordinary record cannot answer
              </p>

              <ul className="mt-4 space-y-3 text-gray-700">
                <li>
                  <span className="font-medium">Why</span> was this option
                  chosen?
                </li>

                <li>
                  <span className="font-medium">What alternatives</span>
                  were considered?
                </li>

                <li>
                  <span className="font-medium">What assumptions</span>
                  did the decision depend on?
                </li>

                <li>
                  <span className="font-medium">What risks</span> were
                  consciously accepted?
                </li>

                <li>
                  <span className="font-medium">What would change</span>
                  the decision today?
                </li>
              </ul>
            </div>
          </div>
        )}
      </section>

      <section className="mt-6 border rounded-xl p-6 bg-gray-50">
        <h2 className="text-xl font-semibold">
          The Judgment Engineering distinction
        </h2>

        <p className="text-gray-700 leading-7 mt-3">
          Preserving the event tells the organization what happened.
          Preserving the judgment makes it possible to reconstruct why the
          decision made sense at the time, what was uncertain, what was
          accepted, and what should be reconsidered when circumstances
          change.
        </p>

        <div className="mt-5 border-l-4 border-blue-700 pl-4">
          <p className="font-semibold">
            The loss is not the decision.
          </p>

          <p className="text-gray-600 mt-1">
            The loss is the reasoning that made the decision intelligible.
          </p>
        </div>
      </section>

      <div className="mt-8 flex justify-between">
        <Link
          href="/simulations"
          className="border rounded px-4 py-2 text-sm hover:bg-gray-50"
        >
          All Simulations
        </Link>

        <Link
          href="/simulations/2"
          className="bg-blue-900 text-white rounded px-4 py-2 text-sm"
        >
          Next Simulation ?
        </Link>
      </div>
    </main>
  );
}
