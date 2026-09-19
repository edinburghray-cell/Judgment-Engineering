import { NextRequest, NextResponse } from "next/server";
import { createSupabaseAdminClient } from "@/lib/supabaseAdmin";

type BridgeIntakePayload = {
  source_system: "lumos";
  interaction_id: string;
  source_reference?: string | null;
  source_timestamp?: string | null;
  original_transcript: string;
  reviewed_representation: string;
  reviewer_identity: string;
  reviewed_at: string;
  machine_metadata?: Record<string, unknown>;
  idempotency_key: string;
};

function isValidPayload(body: unknown): body is BridgeIntakePayload {
  if (!body || typeof body !== "object") return false;

  const value = body as Record<string, unknown>;

  return (
    value.source_system === "lumos" &&
    typeof value.interaction_id === "string" &&
    value.interaction_id.trim().length > 0 &&
    typeof value.original_transcript === "string" &&
    value.original_transcript.trim().length > 0 &&
    typeof value.reviewed_representation === "string" &&
    value.reviewed_representation.trim().length > 0 &&
    typeof value.reviewer_identity === "string" &&
    value.reviewer_identity.trim().length > 0 &&
    typeof value.reviewed_at === "string" &&
    value.reviewed_at.trim().length > 0 &&
    typeof value.idempotency_key === "string" &&
    value.idempotency_key.trim().length > 0 &&
    (value.source_reference === undefined ||
      value.source_reference === null ||
      typeof value.source_reference === "string") &&
    (value.source_timestamp === undefined ||
      value.source_timestamp === null ||
      typeof value.source_timestamp === "string") &&
    (value.machine_metadata === undefined ||
      (typeof value.machine_metadata === "object" &&
        value.machine_metadata !== null &&
        !Array.isArray(value.machine_metadata)))
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
      { error: "invalid_bridge_intake_payload" },
      { status: 400 }
    );
  }

  const supabase = createSupabaseAdminClient();

  const { data: existing, error: lookupError } = await supabase
    .from("bridge_intakes")
    .select("id, status, proposal_id, proposal_version_id, review_cycle_id")
    .eq("idempotency_key", body.idempotency_key)
    .maybeSingle();

  if (lookupError) {
    return NextResponse.json(
      { error: "bridge_intake_lookup_failed" },
      { status: 500 }
    );
  }

  if (existing) {
    return NextResponse.json(
      {
        intake_id: existing.id,
        status: existing.status,
        proposal_id: existing.proposal_id,
        proposal_version_id: existing.proposal_version_id,
        review_cycle_id: existing.review_cycle_id,
        duplicate: true,
      },
      { status: 200 }
    );
  }

  const { data: intake, error: insertError } = await supabase
    .from("bridge_intakes")
    .insert({
      source_system: body.source_system,
      interaction_id: body.interaction_id.trim(),
      source_reference: body.source_reference ?? null,
      source_timestamp: body.source_timestamp ?? null,
      original_transcript: body.original_transcript,
      reviewed_representation: body.reviewed_representation,
      reviewer_identity: body.reviewer_identity,
      reviewed_at: body.reviewed_at,
      machine_metadata: body.machine_metadata ?? {},
      idempotency_key: body.idempotency_key.trim(),
    })
    .select(
      "id, status, interaction_id, source_system, created_at"
    )
    .single();

  if (insertError) {
    if (insertError.code === "23505") {
      const { data: duplicate } = await supabase
        .from("bridge_intakes")
        .select(
          "id, status, proposal_id, proposal_version_id, review_cycle_id"
        )
        .eq("idempotency_key", body.idempotency_key)
        .single();

      if (duplicate) {
        return NextResponse.json(
          {
            intake_id: duplicate.id,
            status: duplicate.status,
            proposal_id: duplicate.proposal_id,
            proposal_version_id: duplicate.proposal_version_id,
            review_cycle_id: duplicate.review_cycle_id,
            duplicate: true,
          },
          { status: 200 }
        );
      }
    }

    return NextResponse.json(
      { error: "bridge_intake_persistence_failed" },
      { status: 500 }
    );
  }

  return NextResponse.json(
    {
      intake_id: intake.id,
      status: intake.status,
      interaction_id: intake.interaction_id,
      source_system: intake.source_system,
      created_at: intake.created_at,
      duplicate: false,
    },
    { status: 201 }
  );
}


