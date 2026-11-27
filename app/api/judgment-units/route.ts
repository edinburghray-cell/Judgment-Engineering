import { NextRequest, NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabaseServer";

const textLimits = {
  title: 300, department: 200, decision_owner: 200, situation: 10000,
  problem: 10000, rationale: 10000, assumptions: 10000,
  accepted_risks: 10000, success_metrics: 10000, chosen_option: 2000,
} as const;
const allowedFields = new Set([...Object.keys(textLimits), "status", "options", "rejected_options", "evidence"]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function validNested(value: unknown, rejected = false) {
  if (!Array.isArray(value) || value.length > 100) return false;
  return value.every((item) => {
    if (!isRecord(item)) return false;
    const keys = Object.keys(item);
    if (rejected) return keys.length === 2 && keys.includes("label") && keys.includes("reason_rejected") &&
      typeof item.label === "string" && item.label.length > 0 && item.label.length <= 500 &&
      typeof item.reason_rejected === "string" && item.reason_rejected.length <= 2000;
    return keys.length === 1 && keys[0] === "label" && typeof item.label === "string" &&
      item.label.length > 0 && item.label.length <= 500;
  });
}

export async function POST(request: NextRequest) {
  const supabase = await createSupabaseServerClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return NextResponse.json({ error: "authentication_required" }, { status: 401 });
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }
  if (!isRecord(payload)) {
    return NextResponse.json({ error: "invalid_judgment_unit" }, { status: 400 });
  }
  if (Object.keys(payload).some((key) => !allowedFields.has(key)))
    return NextResponse.json({ error: "unexpected_field" }, { status: 400 });
  if (payload.status !== undefined && payload.status !== "Proposed")
    return NextResponse.json({ error: "status_must_be_proposed" }, { status: 400 });
  if (typeof payload.title !== "string" || !payload.title.trim() || payload.title.length > textLimits.title)
    return NextResponse.json({ error: "invalid_required_field" }, { status: 400 });
  for (const [field, limit] of Object.entries(textLimits)) {
    const value = payload[field];
    if (value !== undefined && (typeof value !== "string" || value.length > limit))
      return NextResponse.json({ error: `invalid_${field}` }, { status: 400 });
  }
  for (const field of ["options", "rejected_options", "evidence"] as const) {
    if (payload[field] !== undefined && !validNested(payload[field], field === "rejected_options"))
      return NextResponse.json({ error: `invalid_${field}` }, { status: 400 });
  }

  const insert = {
    title: payload.title.trim(), department: payload.department ?? null,
    decision_owner: payload.decision_owner ?? null, status: payload.status ?? "Proposed",
    situation: payload.situation ?? null, problem: payload.problem ?? null,
    rationale: payload.rationale ?? null, assumptions: payload.assumptions ?? null,
    accepted_risks: payload.accepted_risks ?? null, success_metrics: payload.success_metrics ?? null,
    chosen_option: payload.chosen_option ?? null, options: payload.options ?? [],
    rejected_options: payload.rejected_options ?? [], evidence: payload.evidence ?? [],
    capture_actor: user.id,
  };
  const { error } = await supabase.from("judgment_units").insert(insert);
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json({ ok: true }, { status: 201 });
}
