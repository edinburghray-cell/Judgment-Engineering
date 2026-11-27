import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabaseServer";
import CaptureForm from "./CaptureForm";

export default async function CapturePage() {
  const supabase = await createSupabaseServerClient();
  const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user) redirect("/auth");
  return <CaptureForm />;
}