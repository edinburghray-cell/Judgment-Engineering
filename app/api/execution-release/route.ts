import { NextRequest, NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabaseServer";

export async function POST(request: NextRequest) {
  const supabase = await createSupabaseServerClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser();

  if (authError || !user) {
    return NextResponse.json({ error: "authentication_required" }, { status: 401 });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }

  if (
    !body || typeof body !== "object" || Array.isArray(body) ||
    !("operation_id" in body) || typeof body.operation_id !== "string" ||
    !body.operation_id.trim()
  ) {
    return NextResponse.json({ error: "operation_id_required" }, { status: 400 });
  }

  const { data, error } = await supabase.rpc("release_execution_operation", {
    target_operation_id: body.operation_id.trim(),
  });

  if (error) {
    return NextResponse.json({ error: "execution_release_failed" }, { status: 400 });
  }

  const release = Array.isArray(data) ? data[0] : data;
  if (!release) {
    return NextResponse.json({ error: "execution_release_empty" }, { status: 500 });
  }

  return NextResponse.json(release);
}
