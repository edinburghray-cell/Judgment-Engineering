"use server";

import { createSupabaseServerClient } from "@/lib/supabaseServer";

export async function recordJudgmentRetrospective(formData: FormData) {
  const targetJudgmentId = String(formData.get("target_judgment_id") ?? "").trim();
  const outcomeStatus = String(formData.get("outcome_status") ?? "").trim();
  const assumptionsConfirmed = String(formData.get("assumptions_confirmed") ?? "").trim();
  const assumptionsInvalidated = String(formData.get("assumptions_invalidated") ?? "").trim();
  const unexpectedRisks = String(formData.get("unexpected_risks") ?? "").trim();
  const nextTimeChanges = String(formData.get("next_time_changes") ?? "").trim();
  const futureDecisionGuidance = String(formData.get("future_decision_guidance") ?? "").trim();

  if (!targetJudgmentId || !outcomeStatus || !futureDecisionGuidance) {
    return { error: "Outcome, Judgment, and future decision guidance are required." };
  }

  const supabase = await createSupabaseServerClient();

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return { error: "Authentication required." };
  }

  const { error } = await supabase.rpc("record_judgment_retrospective", {
    target_judgment_id: targetJudgmentId,
    target_outcome_status: outcomeStatus,
    target_assumptions_confirmed: assumptionsConfirmed,
    target_assumptions_invalidated: assumptionsInvalidated,
    target_unexpected_risks: unexpectedRisks,
    target_next_time_changes: nextTimeChanges,
    target_future_decision_guidance: futureDecisionGuidance,
  });

  if (error) {
    return { error: error.message };
  }

  return { success: true };
}
