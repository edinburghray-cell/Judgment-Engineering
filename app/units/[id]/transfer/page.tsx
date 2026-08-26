import { supabase } from "@/lib/supabaseClient";
import Link from "next/link";
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

  async function createTransfer(formData: FormData) {
    "use server";

    const treatment = String(formData.get("treatment") || "");
    const whatChanged = String(formData.get("what_changed") || "");

    if (!["apply", "adapt", "reject"].includes(treatment)) {
      return;
    }

    const { error } = await supabase
      .from("judgment_transfers")
      .insert({
        source_judgment_unit_id: id,
        treatment,
        what_changed: whatChanged || null,
      });

    if (error) {
      throw new Error(error.message);
    }

    redirect(`/units/${id}`);
  }

  return (
    <main className="max-w-3xl mx-auto px-4 py-10">
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

      <form action={createTransfer}>
        <section className="border rounded-lg p-5 mt-6">
          <h2 className="text-xl font-semibold">
            What has changed?
          </h2>

          <p className="text-sm text-gray-600 mt-2">
            The preserved judgment is historical context. Before applying it,
            identify what is different about the situation you are facing now.
          </p>

          <textarea
            name="what_changed"
            placeholder="What is different now?"
            className="w-full border rounded p-3 mt-4 min-h-32"
          />
        </section>

        <section className="border rounded-lg p-5 mt-6">
          <h2 className="text-xl font-semibold">
            Your judgment
          </h2>

          <p className="text-sm text-gray-600 mt-2">
            How should the preserved judgment be treated in the current
            situation?
          </p>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mt-5">
            <button
              type="submit"
              name="treatment"
              value="apply"
              className="border rounded-lg p-4 text-left hover:bg-gray-50"
            >
              <strong>Apply</strong>
              <span className="block text-sm text-gray-600 mt-1">
                The reasoning still applies.
              </span>
            </button>

            <button
              type="submit"
              name="treatment"
              value="adapt"
              className="border rounded-lg p-4 text-left hover:bg-gray-50"
            >
              <strong>Adapt</strong>
              <span className="block text-sm text-gray-600 mt-1">
                The reasoning is useful, but circumstances have changed.
              </span>
            </button>

            <button
              type="submit"
              name="treatment"
              value="reject"
              className="border rounded-lg p-4 text-left hover:bg-gray-50"
            >
              <strong>Reject</strong>
              <span className="block text-sm text-gray-600 mt-1">
                The original reasoning no longer applies.
              </span>
            </button>
          </div>
        </section>
      </form>

      <div className="mt-8 border-t pt-6">
        <p className="text-sm text-gray-500">
          The original judgment remains unchanged. A subsequent decision
          can be recorded separately and linked to this judgment.
        </p>
      </div>
    </main>
  );
}
