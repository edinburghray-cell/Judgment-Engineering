import { NextRequest, NextResponse } from "next/server";
import { createSupabaseAdminClient } from "@/lib/supabaseAdmin";

type BridgeContextualRetrievalPayload = {
  source_system: "lumos";
  external_identity: string;
  context_query: Record<string, unknown>;
  result_limit?: number;
};

function isValidPayload(
  body: unknown
): body is BridgeContextualRetrievalPayload {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return false;
  }

  const value = body as Record<string, unknown>;

  return (
    value.source_system === "lumos" &&
    typeof value.external_identity === "string" &&
    value.external_identity.trim().length > 0 &&
    typeof value.context_query === "object" &&
    value.context_query !== null &&
    !Array.isArray(value.context_query) &&
    (value.result_limit === undefined ||
      (typeof value.result_limit === "number" &&
        Number.isInteger(value.result_limit) &&
        value.result_limit >= 1 &&
        value.result_limit <= 10))
  );
}

export async function POST(request: NextRequest) {
  const expectedSecret = process.env.JE_BRIDGE_SECRET;

  if (!expectedSecret) {
    return NextResponse.json(
      { error: "bridge_not_configured" },
      { status: 503 }
    );
  }

  const providedSecret = request.headers.get("x-je-bridge-secret");

  if (!providedSecret || providedSecret !== expectedSecret) {
    return NextResponse.json(
      { error: "bridge_unauthorized" },
      { status: 401 }
    );
  }

  let body: unknown;

  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { error: "invalid_json" },
      { status: 400 }
    );
  }

  if (!isValidPayload(body)) {
    return NextResponse.json(
      { error: "invalid_contextual_retrieval_bridge_payload" },
      { status: 400 }
    );
  }

  const supabase = createSupabaseAdminClient();

  const { data: binding, error: bindingError } = await supabase
    .from("external_identity_bindings")
    .select("je_actor_id")
    .eq("source_system", "lumos")
    .eq("external_identity", body.external_identity.trim())
    .maybeSingle();

  if (bindingError) {
    return NextResponse.json(
      { error: "external_identity_lookup_failed" },
      { status: 500 }
    );
  }

  if (!binding) {
    return NextResponse.json(
      { error: "external_identity_not_bound" },
      { status: 403 }
    );
  }

  const requestId = crypto.randomUUID();
  const resultLimit = body.result_limit ?? 5;

  const retrievalContext = {
    ...body.context_query,
    request_id: requestId,
    source_system: "lumos",
  };

  const { data, error } = await supabase.rpc(
    "retrieve_contextual_judgments",
    {
      target_context: retrievalContext,
      result_limit: resultLimit,
      target_actor_id: binding.je_actor_id,
    }
  );

  if (error) {
    return NextResponse.json(
      {
        error: "contextual_retrieval_failed",
        request_id: requestId,
        message: error.message,
      },
      { status: 500 }
    );
  }

  return NextResponse.json(
    {
      request_id: requestId,
      context_query: body.context_query,
      result_limit: resultLimit,
      candidates: data ?? [],
    },
    { status: 200 }
  );
}
