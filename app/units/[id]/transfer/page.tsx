import { supabase } from "@/lib/supabaseClient";
import { createSupabaseServerClient } from "@/lib/supabaseServer";
import Link from "next/link";
import TransferForm from "./TransferForm";
import { notFound, redirect } from "next/navigation";

export default async function TransferPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  const { data: unit, error } = await supabase
    .from("judgment_units")
    .select("*")
    .eq("id", id)
    .single();

  if (error || !unit) {
    return notFound();
  }

  const options = Array.isArray(unit.options) ? unit.options : [];

  const rejected = Array.isArray(unit.rejected_options)
    ? unit.rejected_options
    : [];

  const evidence = Array.isArray(unit.evidence)
    ? unit.evidence
    : [];

  const supabaseServer = await createSupabaseServerClient();

  const {
    data: { user },
  } = await supabaseServer.auth.getUser();

  const { data: unfinishedAttempts } = user
    ? await supabaseServer
        .from("transfer_attempts")
        .select("id, treatment, what_changed, status, created_at")
        .eq("actor_id", user.id)
        .eq("source_judgment_unit_id", id)
        .in("status", ["initiated", "processing"])
        .order("created_at", { ascending: false })
    : { data: [] };

  async function signOut() {
    "use server";

    const supabaseServer = await createSupabaseServerClient();

    await supabaseServer.auth.signOut();

    redirect("/auth");
  }

  async function createTransfer(formData: FormData) {
    "use server";

    const treatment = String(formData.get("treatment") || "");
    const whatChanged = String(formData.get("what_changed") || "");

    if (!["apply", "adapt", "reject"].includes(treatment)) {
      return;
    }

    const supabaseServer = await createSupabaseServerClient();

    const {
      data: { user },
      error: userError,
    } = await supabaseServer.auth.getUser();

    if (userError || !user) {
      redirect("/auth");
    }

    const attemptId = String(formData.get("attempt_id") || "").trim();

    if (!attemptId) {
      throw new Error("Missing transfer attempt ID.");
    }

    const { data: existingAttempt, error: existingAttemptError } =
      await supabaseServer
        .from("transfer_attempts")
        .select(
          "id, actor_id, source_judgment_unit_id, treatment, what_changed, status, result_transfer_id"
        )
        .eq("id", attemptId)
        .eq("actor_id", user.id)
        .maybeSingle();

    if (existingAttemptError) {
      throw new Error(existingAttemptError.message);
    }

    if (!existingAttempt) {
      const { error: attemptError } = await supabaseServer.rpc(
        "initiate_transfer_attempt",
        {
          target_attempt_id: attemptId,
          target_judgment_unit_id: id,
          target_treatment: treatment,
          target_what_changed: whatChanged,
        }
      );

      if (attemptError) {
        throw new Error(attemptError.message);
      }
    } else {
      const existingWhatChanged = existingAttempt.what_changed || null;
      const submittedWhatChanged = whatChanged || null;

      if (
        existingAttempt.source_judgment_unit_id !== id ||
        existingAttempt.treatment !== treatment ||
        existingWhatChanged !== submittedWhatChanged
      ) {
        throw new Error(
          "Transfer attempt does not match the original operation."
        );
      }

      if (existingAttempt.status === "completed") {
        redirect(`/units/${id}`);
      }

      if (
        existingAttempt.status !== "initiated" &&
        existingAttempt.status !== "processing"
      ) {
        throw new Error(
          `Transfer attempt cannot be resumed from status: ${existingAttempt.status}`
        );
      }
    }

    const { error: claimError } = await supabaseServer.rpc(
      "claim_transfer_attempt",
      {
        target_attempt_id: attemptId,
      }
    );

    if (claimError) {
      throw new Error(claimError.message);
    }

    const { error: completeError } = await supabaseServer.rpc(
      "complete_transfer_attempt",
      {
        target_attempt_id: attemptId,
      }
    );

    if (completeError) {
      throw new Error(completeError.message);
    }

    redirect(`/units/${id}`);
  }

  return (
    <main className="max-w-3xl mx-auto px-4 py-10">
      {user && (
        <section className="border rounded-lg p-4 mb-6 flex items-center justify-between gap-4">
          <div>
            <p className="text-xs font-medium text-gray-500 uppercase tracking-wide">
              Signed in as
            </p>
            <p className="font-semibold mt-1">
              {user.email}
            </p>
          </div>

          <form action={signOut}>
            <button
              type="submit"
              className="border rounded-lg px-4 py-2 text-sm font-semibold hover:bg-gray-50"
            >
              Sign out
            </button>
          </form>
        </section>
      )}
      <Link
        href={`/units/${unit.id}`}
        className="text-sm text-blue-700 hover:underline"
      >
        ? Back to Judgment Unit
      </Link>

      <div className="mt-8">
        <p className="text-sm font-medium text-gray-500">
          JUDGMENT TRANSFER
        </p>

        <h1 className="text-3xl font-bold mt-2">
          Use this judgment
        </h1>

        <p className="text-gray-600 mt-3">
          Review the preserved reasoning below before deciding whether it
          still applies to the situation you are facing now.
        </p>
      </div>

      <section className="border rounded-lg p-5 mt-8">
        <p className="text-sm text-gray-500">
          Preserved Judgment
        </p>

        <h2 className="text-xl font-semibold mt-1">
          {unit.title}
        </h2>

        <div className="mt-4 space-y-4 text-sm">
          <div>
            <h3 className="font-semibold">Situation</h3>
            <p className="text-gray-700 whitespace-pre-wrap mt-1">
              {unit.situation || "Not recorded."}
            </p>
          </div>

          <div>
            <h3 className="font-semibold">Decision</h3>
            <p className="text-gray-700 whitespace-pre-wrap mt-1">
              {unit.chosen_option || "Not recorded."}
            </p>
          </div>

          <div>
            <h3 className="font-semibold">Reasoning</h3>
            <p className="text-gray-700 whitespace-pre-wrap mt-1">
              {unit.rationale || "Not recorded."}
            </p>
          </div>

          <div>
            <h3 className="font-semibold">Assumptions</h3>
            <p className="text-gray-700 whitespace-pre-wrap mt-1">
              {unit.assumptions || "Not recorded."}
            </p>
          </div>

          <div>
            <h3 className="font-semibold">Accepted Risks</h3>
            <p className="text-gray-700 whitespace-pre-wrap mt-1">
              {unit.accepted_risks || "Not recorded."}
            </p>
          </div>

          {options.length > 0 && (
            <div>
              <h3 className="font-semibold">
                Alternatives considered
              </h3>

              <ul className="list-disc list-inside text-gray-700 mt-1">
                {options.map((option: any, index: number) => (
                  <li key={index}>
                    {typeof option === "string"
                      ? option
                      : option?.label || String(option)}
                  </li>
                ))}
              </ul>
            </div>
          )}

          {rejected.length > 0 && (
            <div>
              <h3 className="font-semibold">
                Rejected alternatives
              </h3>

              <ul className="list-disc list-inside text-gray-700 mt-1">
                {rejected.map((option: any, index: number) => (
                  <li key={index}>
                    {typeof option === "string"
                      ? option
                      : option?.label ||
                        option?.reason_rejected ||
                        String(option)}
                  </li>
                ))}
              </ul>
            </div>
          )}

          {evidence.length > 0 && (
            <div>
              <h3 className="font-semibold">
                Evidence / sources
              </h3>

              <ul className="list-disc list-inside text-gray-700 mt-1">
                {evidence.map((item: any, index: number) => (
                  <li key={index}>
                    {typeof item === "string"
                      ? item
                      : item?.label || String(item)}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      </section>

      {unfinishedAttempts && unfinishedAttempts.length > 0 && (
        <section className="border rounded-lg p-5 mt-6">
          <h2 className="text-xl font-semibold">
            Unfinished Transfer Attempts
          </h2>

          <p className="text-sm text-gray-600 mt-2">
            A previous transfer attempt has not reached a final outcome.
            Resume an existing attempt rather than starting the same operation
            again.
          </p>

          <div className="space-y-3 mt-5">
            {unfinishedAttempts.map((attempt) => (
              <form key={attempt.id} action={createTransfer}>
                <input
                  type="hidden"
                  name="attempt_id"
                  value={attempt.id}
                />

                <input
                  type="hidden"
                  name="treatment"
                  value={attempt.treatment}
                />

                <input
                  type="hidden"
                  name="what_changed"
                  value={attempt.what_changed || ""}
                />

                <div className="border rounded-lg p-4">
                  <div className="flex items-center justify-between gap-4">
                    <div>
                      <p className="font-semibold capitalize">
                        {attempt.treatment}
                      </p>

                      <p className="text-sm text-gray-700 mt-1">
                        {attempt.what_changed || "No change recorded."}
                      </p>

                      <p className="text-xs text-gray-400 mt-2">
                        {attempt.status} -{" "}
                        {new Date(attempt.created_at).toLocaleString()}
                      </p>
                    </div>

                    <button
                      type="submit"
                      className="border rounded-lg px-4 py-2 text-sm font-semibold hover:bg-gray-50"
                    >
                      Resume
                    </button>
                  </div>
                </div>
              </form>
            ))}
          </div>
        </section>
      )}

      <TransferForm action={createTransfer} />

      <div className="mt-8 border-t pt-6">
        <p className="text-sm text-gray-500">
          The original judgment remains unchanged. A subsequent decision
          can be recorded separately and linked to this judgment.
        </p>
      </div>
    </main>
  );
}


