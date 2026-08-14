import Link from 'next/link';

const simulations = [
  {
    number: '01',
    title: 'The Loss',
    description:
      'See how organizations preserve events while unintentionally losing the reasoning behind decisions.',
    href: '/simulations/1',
  },
  {
    number: '02',
    title: 'The Capture',
    description:
      'See how individual expertise can be transformed into structured organizational memory through Judgment Engineering.',
    href: '/simulations/2',
  },
  {
    number: '03',
    title: 'The Transfer',
    description:
      'See how preserved judgment can move from one person to another, and from humans to AI assisted systems.',
    href: '/simulations/3',
  },
  {
    number: '04',
    title: 'The Institution',
    description:
      'See how Judgment Engineering becomes an organizational capability and creates a continuous learning loop.',
    href: '/simulations/4',
  },
];

export default function SimulationsPage() {
  return (
    <main className="max-w-5xl mx-auto px-4 py-10">
      <div className="mb-10">
        <Link
          href="/"
          className="text-sm text-blue-700 hover:underline"
        >
          ? Back to Home
        </Link>

        <h1 className="text-3xl font-bold mt-6">
          Judgment Engineering Simulations
        </h1>

        <p className="text-gray-600 mt-3 max-w-3xl">
          Four simulations showing the progression from lost judgment,
          to captured judgment, to transferred judgment, and finally to
          organizational learning.
        </p>
      </div>

      <div className="grid gap-5 md:grid-cols-2">
        {simulations.map((simulation) => (
          <Link
            key={simulation.number}
            href={simulation.href}
            className="block border rounded-xl p-6 hover:border-blue-400 transition"
          >
            <div className="text-sm font-mono text-gray-400 mb-3">
              SIMULATION {simulation.number}
            </div>

            <h2 className="text-xl font-semibold mb-2">
              {simulation.title}
            </h2>

            <p className="text-sm text-gray-600">
              {simulation.description}
            </p>

            <div className="mt-5 text-sm font-medium text-blue-700">
              Enter simulation ?
            </div>
          </Link>
        ))}
      </div>
    </main>
  );
}
