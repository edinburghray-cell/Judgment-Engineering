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

  const { data: lifecycle, error: lifecycleError } = await supabase.rpc(
    "get_judgment_lifecycle_history",
    { target_judgment_id: judgment.id }
  );
  const lifecycleHistory = lifecycle as {
    decisions?: Array<Record<string, unknown>>;
    authorities?: Array<Record<string, unknown>>;
    operations?: Array<Record<string, unknown>>;
    attempts?: Array<Record<string, unknown>>;
    runs?: Array<Record<string, unknown>>;
    execution_evidence?: Array<Record<string, unknown>>;
  } | null;
  const lifecycleRows = (key: keyof NonNullable<typeof lifecycleHistory>) =>
    (lifecycleHistory?.[key] ?? []) as Array<Record<string, unknown>>;
  const lifecycleDate = (value: unknown) =>
    typeof value === "string" ? new Date(value).toLocaleString() : "Not recorded";
  const lifecycleText = (value: unknown) =>
    value === null || value === undefined || value === "" ? "Not recorded" : String(value);

  const { data: history, error: historyError } = await supabase
    .from("judgment_events")
    .select("id, event_type, created_at, actor, description, payload")
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

  const { data: successorData } = await supabase
    .from("judgments")
    .select("id, judgment_unit_id, title")
    .eq("predecessor_judgment_id", judgment.id)
    .order("committed_at", { ascending: true })
    .limit(2);
  const successors = successorData ?? [];
  const successor = successors[0] ?? null;

  const { data: laterEvidenceData } = await supabase
    .from("judgment_evidence")
    .select("id, description, evidence_category, entered_at, judgment_event_id")
    .eq("judgment_id", judgment.id)
    .order("entered_at", { ascending: true });
  const laterEvidence = laterEvidenceData ?? [];
  const eventIds = (history ?? []).map((event) => event.id);
  const { data: eventEvidence = [] } = eventIds.length
    ? await supabase
        .from("judgment_evidence")
        .select("id, description, evidence_category, entered_at, judgment_event_id")
        .in("judgment_event_id", eventIds)
        .order("entered_at", { ascending: true })
    : { data: [] };

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
        <p className="text-sm text-gray-500 mt-3">Independent Judgment record · committed {new Date(judgment.committed_at).toLocaleString()}</p>
      </header>

      <section className="mt-6 rounded-lg border-2 border-slate-400 bg-slate-50 p-5">
        <p className="text-xs font-semibold uppercase tracking-wide text-slate-600">Original decision · immutable record</p>
        <h2 className="mt-3 text-lg font-semibold">Issue / underlying challenge</h2>
        <p className="mt-1 whitespace-pre-wrap text-sm">{judgment.problem || judgment.situation || "No issue description recorded"}</p>
        <h2 className="mt-4 text-lg font-semibold">Judgment / resolution</h2>
        <p className="mt-1 whitespace-pre-wrap text-sm">{judgment.rationale || judgment.chosen_option || "No resolution recorded"}</p>
        <dl className="mt-5 grid gap-3 text-sm sm:grid-cols-2">
          <div><dt className="font-medium text-gray-500">Decision Owner</dt><dd className="mt-1">{judgment.decision_owner || "Not recorded"}</dd></div>
          <div><dt className="font-medium text-gray-500">Committing Actor</dt><dd className="mt-1 break-all font-mono">{judgment.committing_actor}</dd></div>
          <div><dt className="font-medium text-gray-500">Capture Actor</dt><dd className="mt-1 break-all font-mono">{judgment.capture_actor || "Not recorded"}</dd></div>
          <div><dt className="font-medium text-gray-500">Lifecycle</dt><dd className="mt-1">{successors.length > 1 ? "Multiple successors found; the single-successor constraint needs verification" : successor ? "Superseded by a separate Judgment" : "No superseding Judgment recorded"}</dd></div>
        </dl>
        {successors.map((item) => <p key={item.id} className="mt-3 text-sm"><Link className="text-blue-700 hover:underline" href={`/judgments/${item.id}`}>View successor: {item.judgment_unit_id} — {item.title}</Link></p>)}
      </section>

      <section className="mt-6 border rounded-lg p-5">
        <h2 className="text-lg font-semibold">Consequential lifecycle</h2>
        <p className="mt-1 text-sm text-gray-600">Decision, authority, release validation and actual execution are separate historical records.</p>
        {lifecycleError ? (
          <p role="alert" className="mt-4 rounded border border-red-300 bg-red-50 p-3 text-sm text-red-800">
            Lifecycle history could not be loaded: {lifecycleError.message}. The records below are unavailable; this page is not showing a complete lifecycle.
          </p>
        ) : (
          <div className="mt-5 space-y-6">
            <div>
              <h3 className="font-semibold">Consequential decisions</h3>
              {lifecycleRows("decisions").length === 0 ? <p className="mt-2 text-sm text-gray-500">No consequential decision is linked to this Judgment.</p> : lifecycleRows("decisions").map((row) => (
                <article key={String(row.id)} className="mt-3 border-t pt-3 text-sm">
                  <p className="font-medium">{lifecycleText(row.decision)} · {lifecycleDate(row.decided_at)}</p>
                  <p>Decision actor: <span className="font-mono">{lifecycleText(row.actor_id)}</span></p>
                  <p>Authority basis: {lifecycleText(row.authority_basis)}</p>
                  <p>Rationale: {lifecycleText(row.rationale)}</p>
                  <p>Residual risks: {lifecycleText(row.residual_risks)}</p>
                  <p>Review cycle: <span className="font-mono">{lifecycleText(row.review_cycle_id)}</span>; correlation: <span className="font-mono">{lifecycleText(row.correlation_id)}</span>; causation: <span className="font-mono">{lifecycleText(row.causation_id)}</span></p>
                </article>
              ))}
            </div>
            <div>
              <h3 className="font-semibold">Execution authority</h3>
              {lifecycleRows("authorities").length === 0 ? <p className="mt-2 text-sm text-gray-500">No execution authority is recorded.</p> : lifecycleRows("authorities").map((row) => (
                <article key={String(row.id)} className="mt-3 border-t pt-3 text-sm">
                  <p>Authority <span className="font-mono">{String(row.id)}</span>, issued by <span className="font-mono">{lifecycleText(row.actor_id)}</span> at {lifecycleDate(row.created_at)}</p>
                  <p>Scope: {lifecycleText(row.scope)} · action: {lifecycleText(row.action)} · target: {lifecycleText(row.target)}</p>
                  <p>Valid {lifecycleDate(row.valid_from)} through {lifecycleDate(row.valid_until)} · {row.revoked_at ? `revoked ${lifecycleDate(row.revoked_at)} by ${lifecycleText(row.revoked_by)}` : "not recorded as revoked"}</p>
                </article>
              ))}
            </div>
            <div>
              <h3 className="font-semibold">Operation and release validation</h3>
              <p className="mt-1 text-xs text-gray-600">Release validation is separate from external execution. JE currently persists rejected release attempts, but does not persist successful release validations, so an absent attempt is not evidence that validation passed or did not occur.</p>
              {lifecycleRows("operations").length === 0 ? <p className="mt-2 text-sm text-gray-500">No operation is recorded.</p> : lifecycleRows("operations").map((row) => {
                const attempts = lifecycleRows("attempts").filter((attempt) => attempt.operation_id === row.operation_id);
                return <article key={String(row.operation_id)} className="mt-3 border-t pt-3 text-sm">
                  <p>Operation <span className="font-mono">{String(row.operation_id)}</span> · actor <span className="font-mono">{lifecycleText(row.actor_id)}</span> · status {lifecycleText(row.status)} · created {lifecycleDate(row.created_at)}</p>
                  {attempts.length === 0 ? <p>No release attempt is recorded.</p> : attempts.map((attempt) => <p key={String(attempt.id)}>Release attempt {lifecycleDate(attempt.attempted_at)}: {lifecycleText(attempt.status)}{attempt.rejection_reason ? ` · ${String(attempt.rejection_reason)}` : ""}</p>)}
                </article>;
              })}
            </div>
            <div>
              <h3 className="font-semibold">Actual execution</h3>
              {lifecycleRows("execution_evidence").length === 0 ? <p className="mt-2 text-sm text-gray-600">Execution has not been evidenced in JE&apos;s records.</p> : lifecycleRows("execution_evidence").map((row) => <article key={String(row.id)} className="mt-3 border-t pt-3 text-sm">
                <p>Execution evidence <span className="font-mono">{String(row.id)}</span> for operation <span className="font-mono">{String(row.operation_id)}</span> at {lifecycleDate(row.executed_at)}.</p>
                <p>Actor: <span className="font-mono">{lifecycleText(row.actor_id)}</span> · outcome recorded: {lifecycleText(row.result)}</p>
              </article>)}
              {lifecycleRows("runs").length > 0 && <ul className="mt-3 list-disc pl-5 text-sm">{lifecycleRows("runs").map((row) => <li key={String(row.id)}>Run {String(row.id)} for operation {String(row.operation_id)}: {lifecycleText(row.execution_status)} · evidence status {lifecycleText(row.evidence_status)}{row.completed_at ? ` · completed ${lifecycleDate(row.completed_at)}` : ""}. A run status alone is not treated as execution evidence.</li>)}</ul>}
            </div>
          </div>
        )}
      </section>

      <section className="mt-6 border rounded-lg p-5">
        <h2 className="text-lg font-semibold mb-4">Judgment Durability</h2>
        <dl className="grid gap-4 sm:grid-cols-2">
          <div>
            <dt className="text-xs font-medium text-gray-500">Committing Actor</dt>
            <dd className="mt-1 text-sm">{judgment.committing_actor}</dd>
          </div>
          <div>
            <dt className="text-xs font-medium text-gray-500">Commit date</dt>
            <dd className="mt-1 text-sm">{new Date(judgment.committed_at).toLocaleString()}</dd>
          </div>
          <div>
            <dt className="text-xs font-medium text-gray-500">Decision Owner</dt>
            <dd className="mt-1 text-sm">{judgment.decision_owner || "Not recorded"}</dd>
          </div>
          <div>
            <dt className="text-xs font-medium text-gray-500">Capture Actor</dt>
            <dd className="mt-1 break-all font-mono text-sm">{judgment.capture_actor || "Not recorded"}</dd>
          </div>
          <div className="sm:col-span-2">
            <dt className="text-xs font-medium text-gray-500">Authority Context at Commitment</dt>
            <dd className="mt-1 whitespace-pre-wrap text-sm">{judgment.authority_context}</dd>
            <dd className="mt-1 text-xs text-gray-500">This is the basis stated at commitment; it is not independent verification of organizational mandate.</dd>
          </div>
          <div>
            <dt className="text-xs font-medium text-gray-500">Evidence recorded at commitment</dt>
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
                    Recorded {new Date(event.created_at).toLocaleString()} by <span className="break-all font-mono">{event.actor}</span>
                  </p>
                  <p className="mt-2 text-sm">Outcome: {String((event.payload as Record<string, unknown> | null)?.outcome_status || "Not recorded")}</p>
                  <p className="mt-2 text-sm"><span className="font-medium">Assumptions that held:</span> {String((event.payload as Record<string, unknown> | null)?.assumptions_confirmed || "Not recorded")}</p>
                  <p className="mt-2 text-sm"><span className="font-medium">Assumptions that failed:</span> {String((event.payload as Record<string, unknown> | null)?.assumptions_invalidated || "Not recorded")}</p>
                  <p className="mt-2 text-sm"><span className="font-medium">Unexpected risks / observations:</span> {String((event.payload as Record<string, unknown> | null)?.unexpected_risks || "Not recorded")}</p>
                  <p className="mt-2 text-sm"><span className="font-medium">Lessons for next time:</span> {String((event.payload as Record<string, unknown> | null)?.next_time_changes || "Not recorded")}</p>

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
          <h2 className="text-lg font-semibold mb-4">Historical Activity</h2>
          <p className="mb-4 text-sm text-gray-600">Events describe what happened after or around commitment. They do not change the sealed Judgment.</p>

        {history?.length === 0 ? (
          <p className="text-sm text-gray-500">No events recorded.</p>
        ) : (
          <ol className="relative space-y-5 border-l border-slate-300 pl-5">
            {history?.map((event) => (
              <li key={event.id} className="relative">
                <span className="absolute -left-[25px] top-1 h-2.5 w-2.5 rounded-full bg-slate-500" />
                <p className="text-sm font-medium">{event.event_type.replaceAll("_", " ")}</p>
                <p className="text-xs text-gray-500">{new Date(event.created_at).toLocaleString()} · actor {event.actor}</p>
                <p className="mt-1 whitespace-pre-wrap text-sm">{event.description}</p>
                {event.event_type === "human_confirmed" && <div className="mt-2 text-sm"><p>Review Cycle: {String((event.payload as Record<string, unknown> | null)?.review_cycle_id || "Not recorded")}</p><p>Judgment Draft: {String((event.payload as Record<string, unknown> | null)?.judgment_draft_id || "Not recorded")}</p><p>Confirmation correlation: {String((event.payload as Record<string, unknown> | null)?.correlation_id || "Not recorded")}</p><p>Confirmation causation: {String((event.payload as Record<string, unknown> | null)?.causation_id || "Not recorded")}</p></div>}
                {event.event_type === "supersession" && <div className="mt-2 text-sm"><p><span className="font-medium">Rationale:</span> {String((event.payload as Record<string, unknown> | null)?.supersession_rationale || "Not recorded")}</p><p className="mt-1"><span className="font-medium">Validation basis:</span> {String((event.payload as Record<string, unknown> | null)?.validation_basis || "Not recorded")}</p><p className="mt-1">Supersedes Judgment: {String((event.payload as Record<string, unknown> | null)?.superseded_judgment_id || "Not recorded")}</p></div>}
                {event.event_type === "retrospective" && <p className="mt-2 text-sm">Retrospective recorded as a separate event.</p>}
                {(eventEvidence ?? []).filter((item) => item.judgment_event_id === event.id).map((item) => <p key={item.id} className="mt-2 text-sm">Evidence recorded {new Date(item.entered_at).toLocaleString()}: {item.description} <span className="text-gray-500">({item.evidence_category})</span></p>)}
              </li>
            ))}
          </ol>
        )}
        {laterEvidence.length > 0 ? <div className="mt-6 border-t pt-4"><h3 className="font-semibold">Subsequent evidence</h3><ul className="mt-2 list-disc space-y-2 pl-5 text-sm">{laterEvidence.map((item) => <li key={item.id}>{item.description} <span className="text-gray-500">({item.evidence_category}; {new Date(item.entered_at).toLocaleString()}{item.judgment_event_id ? "; attached to event" : ""})</span></li>)}</ul></div> : null}
      </section>
    </main>
  );
}
