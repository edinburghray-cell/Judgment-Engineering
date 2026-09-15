import Link from "next/link";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabaseServer";

type SearchParams = {
  context?: string;
  department?: string;
};

type RetrievedJudgment = {
  judgment_unit_row_id: string;
  judgment_unit_id: string;
  title: string;
  department: string | null;
  status: string | null;
  situation: string | null;
  problem: string | null;
  chosen_option: string | null;
  relevance_score: number;
};

export default async function RetrievePage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const params = await searchParams;
  const context = params.context?.trim() ?? "";
  const department = params.department?.trim() ?? "";

  const supabase = await createSupabaseServerClient();

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    redirect("/auth");
  }

  let results: RetrievedJudgment[] = [];
  let retrievalError: string | null = null;

  if (context) {
    const { data, error } = await supabase.rpc("retrieve_judgment_units", {
      target_context: context,
      target_department: department || null,
      result_limit: 10,
    });

    if (error) {
      retrievalError = error.message;
    } else {
      results = (data ?? []) as RetrievedJudgment[];
    }
  }

  return (
    <main className="max-w-4xl mx-auto px-4 py-12 space-y-10">
      <section className="space-y-3">
        <div className="flex items-center justify-between">
          <h1 className="text-3xl font-bold">Retrieve Prior Judgment</h1>
          <Link
            href="/units"
            className="text-sm text-blue-700 hover:underline"
          >
            Browse Judgment Units
          </Link>
        </div>

        <p className="text-gray-700 leading-relaxed">
          Describe the situation and problem you are facing. JE will surface
          relevant prior Judgment Units for human review.
        </p>

        <div className="border rounded p-4 bg-gray-50">
          <p className="text-sm font-medium">Retrieval is contextual, not authoritative.</p>
          <p className="text-sm text-gray-600 mt-1">
            A retrieved Judgment is prior reasoning that may be relevant. It
            does not automatically determine whether that reasoning applies to
            the current situation.
          </p>
        </div>
      </section>

      <section>
        <form method="get" className="space-y-4">
          <div>
            <label
              htmlFor="context"
              className="block text-sm font-medium mb-2"
            >
              Current situation and problem
            </label>
            <textarea
              id="context"
              name="context"
              defaultValue={context}
              rows={7}
              required
              placeholder="Describe the current situation, problem, constraints, or decision you are facing..."
              className="w-full border rounded p-3 text-sm"
            />
          </div>

          <div>
            <label
              htmlFor="department"
              className="block text-sm font-medium mb-2"
            >
              Department <span className="text-gray-400">(optional)</span>
            </label>
            <input
              id="department"
              name="department"
              defaultValue={department}
              placeholder="e.g. Operations"
              className="w-full border rounded p-3 text-sm"
            />
          </div>

          <button
            type="submit"
            className="bg-black text-white text-sm px-4 py-2 rounded"
          >
            Find Relevant Judgment
          </button>
        </form>
      </section>

      {retrievalError && (
        <section className="border border-red-200 rounded p-4">
          <h2 className="font-medium text-red-800">Retrieval error</h2>
          <p className="text-sm text-red-700 mt-1">{retrievalError}</p>
        </section>
      )}

      {context && !retrievalError && (
        <section className="space-y-5">
          <div>
            <h2 className="text-xl font-semibold">Relevant Prior Judgments</h2>
            <p className="text-sm text-gray-600 mt-1">
              Ranked by lexical relevance to the context you provided.
            </p>
          </div>

          {results.length === 0 ? (
            <div className="border rounded p-5">
              <p className="font-medium">No matching Judgment Units found.</p>
              <p className="text-sm text-gray-600 mt-1">
                No prior Judgment matched the supplied context using the
                current Retrieval v1 search.
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              {results.map((judgment) => (
                <article
                  key={judgment.judgment_unit_row_id}
                  className="border rounded p-5 space-y-3"
                >
                  <div className="flex justify-between gap-4">
                    <div>
                      <p className="text-xs font-mono text-gray-400">
                        {judgment.judgment_unit_id}
                      </p>
                      <h3 className="font-semibold text-lg">
                        {judgment.title}
                      </h3>
                    </div>

                    <span className="text-xs text-gray-500 whitespace-nowrap">
                      Relevance: {judgment.relevance_score.toFixed(4)}
                    </span>
                  </div>

                  {judgment.department && (
                    <p className="text-xs text-gray-500">
                      {judgment.department}
                      {judgment.status ? ` Â· ${judgment.status}` : ""}
                    </p>
                  )}

                  {judgment.situation && (
                    <div>
                      <p className="text-xs font-medium text-gray-500">
                        Situation
                      </p>
                      <p className="text-sm text-gray-700 mt-1">
                        {judgment.situation}
                      </p>
                    </div>
                  )}

                  {judgment.problem && (
                    <div>
                      <p className="text-xs font-medium text-gray-500">
                        Problem
                      </p>
                      <p className="text-sm text-gray-700 mt-1">
                        {judgment.problem}
                      </p>
                    </div>
                  )}

                  {judgment.chosen_option && (
                    <div>
                      <p className="text-xs font-medium text-gray-500">
                        Chosen option
                      </p>
                      <p className="text-sm text-gray-700 mt-1">
                        {judgment.chosen_option}
                      </p>
                    </div>
                  )}

                  <div className="pt-2">
                    <Link
                      href={judgment.status === "canonical" ? `/judgments/${judgment.judgment_unit_row_id}` : `/units/${judgment.judgment_unit_row_id}`}
                      className="text-sm text-blue-700 hover:underline"
                    >
                      Reconstruct this Judgment
                    </Link>
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>
      )}
    </main>
  );
}
