import { randomUUID } from "crypto";
import { NextRequest, NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabaseServer";

type ContextQuery = {
  workflow: string;
  decision_class: string;
  proposed_change: string;
  intended_outcome: string;
  affected_system_scope: string;
  current_trigger: string;
  constraints: string[];
  relevant_evidence: string[];
  known_risks: string[];
  workflow_state: string;
  occurred_at: string;
  provenance: Record<string, unknown>;
};

type ContextualRetrievalRequest = {
  context_query: ContextQuery;
  result_limit?: number;
};

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function isStringArray(value: unknown): value is string[] {
  return (
    Array.isArray(value) &&
    value.every((item) => typeof item === "string" && item.trim().length > 0)
  );
}

function isContextQuery(value: unknown): value is ContextQuery {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }

  const context = value as Record<string, unknown>;

  return (
    isNonEmptyString(context.workflow) &&
    isNonEmptyString(context.decision_class) &&
    isNonEmptyString(context.proposed_change) &&
    isNonEmptyString(context.intended_outcome) &&
    isNonEmptyString(context.affected_system_scope) &&
    isNonEmptyString(context.current_trigger) &&
    isStringArray(context.constraints) &&
    isStringArray(context.relevant_evidence) &&
    isStringArray(context.known_risks) &&
    isNonEmptyString(context.workflow_state) &&
    isNonEmptyString(context.occurred_at) &&
    typeof context.provenance === "object" &&
    context.provenance !== null &&
    !Array.isArray(context.provenance)
  );
}

function isValidRequest(value: unknown): value is ContextualRetrievalRequest {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }

  const request = value as Record<string, unknown>;

  if (!isContextQuery(request.context_query)) {
    return false;
  }

  if (
    request.result_limit !== undefined &&
    (typeof request.result_limit !== "number" ||
      !Number.isInteger(request.result_limit) ||
      request.result_limit < 1 ||
      request.result_limit > 10)
  ) {
    return false;
  }

  return true;
}

export async function POST(request: NextRequest) {
  const supabase = await createSupabaseServerClient();

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return NextResponse.json(
      { error: "authentication_required" },
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

  if (!isValidRequest(body)) {
    return NextResponse.json(
      { error: "invalid_contextual_retrieval_request" },
      { status: 400 }
    );
  }

  const requestId = randomUUID();
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
      target_actor_id: user.id,
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
