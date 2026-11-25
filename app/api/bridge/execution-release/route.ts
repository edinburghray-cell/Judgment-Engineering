import { NextRequest, NextResponse } from "next/server";
import { createSupabaseAdminClient } from "@/lib/supabaseAdmin";

export async function POST(request: NextRequest) {
  const expectedSecret = process.env.JE_BRIDGE_SECRET;

  if (!expectedSecret) {
    return NextResponse.json(
      { error: "bridge_not_configured" },
      { status: 503 }
    );
  }

  const suppliedSecret = request.headers.get("x-je-bridge-secret");

  if (!suppliedSecret || suppliedSecret !== expectedSecret) {
    return NextResponse.json(
      { error: "unauthorized" },
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

  if (
    typeof body !== "object" ||
    body === null ||
    !("operation_id" in body) ||
    typeof body.operation_id !== "string" ||
    !body.operation_id.trim()
  ) {
    return NextResponse.json(
      { error: "operation_id_required" },
      { status: 400 }
    );
  }

  const operationId = body.operation_id.trim();

  const supabase = createSupabaseAdminClient();

  const { data, error } = await supabase.rpc(
    "release_execution_operation",
    {
      target_operation_id: operationId,
    }
  );

  if (error) {
    return NextResponse.json(
      {
        error: "execution_release_failed",
        detail: error.message,
      },
      { status: 500 }
    );
  }

  const release = Array.isArray(data) ? data[0] : data;

  if (!release) {
    return NextResponse.json(
      { error: "execution_release_empty" },
      { status: 500 }
    );
  }

  return NextResponse.json(release);
}