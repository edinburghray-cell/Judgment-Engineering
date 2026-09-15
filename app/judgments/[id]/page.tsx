import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabaseServer";

type JudgmentPageProps = {
  params: Promise<{ id: string }>;
};

export default async function JudgmentPage({
  params,
}: JudgmentPageProps) {
  const { id } = await params;

  const supabase = await createSupabaseServerClient();

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    redirect("/auth");
  }

  const { data: judgment, error: judgmentError } = await supabase
    .from("judgments")
    .select("*")
    .eq("id", id)
    .maybeSingle();

  if (judgmentError) {
    throw new Error(judgmentError.message);
  }

  if (!judgment) {
    return notFound();
  }

  const { data: history, error: historyError } = await supabase
    .from("judgment_events")
    .select("id, event_type, created_at, actor, payload")
    .eq("judgment_id", judgment.id)
    .order("created_at", { ascending: true });

  if (historyError) {
    throw new Error(historyError.message);
  }

  const retrospectiveEvents = (history ?? []).filter(
    (event) => event.event_type === "retrospective"
  );

  const predecessor = judgment.predecessor_judgment_id
    ? await supabase
        .from("judgments")
        .select("id, judgment_unit_id, title")
        .eq("id", judgment.predecessor_judgment_id)
        .maybeSingle()
    : { data: null };

  const formatJson = (value: unknown) => {
    if (value === null || value === undefined) return "";
    if (typeof value === "string") return value;
    return JSON.stringify(value, null, 2);
  };

  return (
    <main className="max-w-5xl mx-auto px-6 py-10">
      <div className="mb-6">
        <Link
          href="/retrieve"
          className="text-sm text-blue-700 hover:underline"
        >
          Back to Retrieval
        </Link>
      </div>

      <header className="border-b pb-6">
        <p className="text-sm font-medium text-gray-500">
          {judgment.judgment_unit_id}
        </p>
        <h1 className="text-3xl font-bold mt-1">{judgment.title}</h1>
        <p className="text-sm text-gray-500 mt-3">
          Judgment version {judgment.judgment_version}
        </p>
      </header>

      <section className="mt-6 border rounded-lg p-5">
        <h2 className="text-lg font-semibold mb-4">Judgment Durability</h2>
        <dl className="grid gap-4 sm:grid-cols-2">
          <div>
            <dt className="text-xs font-medium text-gray-500">Committed by</dt>
            <dd className="mt-1 text-sm">{judgment.committing_actor}</dd>
          </div>
          <div>
            <dt className="text-xs font-medium text-gray-500">Commit date</dt>
            <dd className="mt-1 text-sm">{judgment.committed_at}</dd>
          </div>
          <div>
            <dt className="text-xs font-medium text-gray-500">Sources</dt>
            <dd className="mt-1 text-sm whitespace-pre-wrap">
              {formatJson(judgment.evidence) || "None recorded"}
            </dd>
          </div>
          <div>
            <dt className="text-xs font-medium text-gray-500">History</dt>
            <dd className="mt-1 text-sm">
              {history?.length ?? 0} event(s)
            </dd>
          </div>
          <div>
            <dt className="text-xs font-medium text-gray-500">Retrospective</dt>
            <dd className="mt-1 text-sm">
              {retrospectiveEvents.length > 0
                ? `${retrospectiveEvents.length} recorded`
                : "None recorded"}
            </dd>
          </div>
          <div className="sm:col-span-2">
            <dt className="text-xs font-medium text-gray-500">
              Reconsideration condition
            </dt>
            <dd className="mt-1 text-sm whitespace-pre-wrap">
              {judgment.reconsideration_conditions || "None recorded"}
            </dd>
          </div>
        </dl>
      </section>

      {predecessor.data && (
        <section className="mt-6 border rounded-lg p-5">
          <h2 className="text-lg font-semibold mb-3">Prior Judgment</h2>
          <Link
            href={`/judgments/${predecessor.data.id}`}
            className="text-blue-700 hover:underline"
          >
            {predecessor.data.judgment_unit_id} â€” {predecessor.data.title}
          </Link>
        </section>
      )}

      <section className="mt-6 border rounded-lg p-5">
        <h2 className="text-lg font-semibold mb-4">Original Reasoning</h2>

        <div className="space-y-5">
          <div>
            <h3 className="text-sm font-medium text-gray-500">Situation</h3>
            <p className="mt-1 whitespace-pre-wrap text-sm">
              {judgment.situation}
            </p>
          </div>

          <div>
            <h3 className="text-sm font-medium text-gray-500">Problem</h3>
            <p className="mt-1 whitespace-pre-wrap text-sm">
              {judgment.problem}
            </p>
          </div>

          <div>
            <h3 className="text-sm font-medium text-gray-500">Assumptions</h3>
            <p className="mt-1 whitespace-pre-wrap text-sm">
              {judgment.assumptions}
            </p>
          </div>

          <div>
            <h3 className="text-sm font-medium text-gray-500">Options</h3>
            <pre className="mt-1 whitespace-pre-wrap text-sm">
              {formatJson(judgment.options)}
            </pre>
          </div>

          <div>
            <h3 className="text-sm font-medium text-gray-500">Rationale</h3>
            <p className="mt-1 whitespace-pre-wrap text-sm">
              {judgment.rationale}
            </p>
          </div>

          <div>
            <h3 className="text-sm font-medium text-gray-500">
              Chosen option
            </h3>
            <p className="mt-1 whitespace-pre-wrap text-sm">
              {judgment.chosen_option}
            </p>
          </div>

          <div>
            <h3 className="text-sm font-medium text-gray-500">
              Rejected options
            </h3>
            <pre className="mt-1 whitespace-pre-wrap text-sm">
              {formatJson(judgment.rejected_options)}
            </pre>
          </div>

          <div>
            <h3 className="text-sm font-medium text-gray-500">
              Accepted risks
            </h3>
            <p className="mt-1 whitespace-pre-wrap text-sm">
              {judgment.accepted_risks}
            </p>
          </div>

          <div>
            <h3 className="text-sm font-medium text-gray-500">
              Success metrics
            </h3>
            <p className="mt-1 whitespace-pre-wrap text-sm">
              {judgment.success_metrics}
            </p>
          </div>

          <div>
            <h3 className="text-sm font-medium text-gray-500">
              Decision owner
            </h3>
            <p className="mt-1 text-sm">{judgment.decision_owner}</p>
          </div>

          <div>
            <h3 className="text-sm font-medium text-gray-500">
              Authority context
            </h3>
            <p className="mt-1 whitespace-pre-wrap text-sm">
              {judgment.authority_context}
            </p>
          </div>
        </div>
      </section>

      <section className="mt-6 border rounded-lg p-5">
        <h2 className="text-lg font-semibold mb-4">
          Retrospective and Inheritance
        </h2>

        {retrospectiveEvents.length === 0 ? (
          <p className="text-sm text-gray-500">
            No retrospective has been recorded for this Judgment.
          </p>
        ) : (
          <div className="space-y-5">
            {retrospectiveEvents.map((event) => {
              const payload = event.payload as
                | {
                    inheritance?: {
                      future_decision_guidance?: string;
                    };
                  }
                | null;

              return (
                <article key={event.id} className="border-t pt-4 first:border-t-0 first:pt-0">
                  <p className="text-xs text-gray-500">
                    Recorded {event.created_at}
                  </p>

                  <div className="mt-3">
                    <h3 className="text-sm font-medium text-gray-500">
                      Future inheritance
                    </h3>
                    <p className="mt-1 whitespace-pre-wrap text-sm">
                      {payload?.inheritance?.future_decision_guidance ||
                        "No inheritance guidance recorded."}
                    </p>
                  </div>
                </article>
              );
            })}
          </div>
        )}
      </section>

      <section className="mt-6 border rounded-lg p-5">
        <h2 className="text-lg font-semibold mb-4">History</h2>

        {history?.length === 0 ? (
          <p className="text-sm text-gray-500">No events recorded.</p>
        ) : (
          <div className="space-y-3">
            {history?.map((event) => (
              <div key={event.id} className="border-t pt-3 first:border-t-0">
                <p className="text-sm font-medium">{event.event_type}</p>
                <p className="text-xs text-gray-500">{event.created_at}</p>
              </div>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
