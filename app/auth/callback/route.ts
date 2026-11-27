import { createSupabaseServerClient } from "@/lib/supabaseServer";
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export async function GET(request: NextRequest) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const next = url.searchParams.get("next");
  const isRecovery = next === "/auth/reset-password";
  const isConfirmation = next === "/auth?confirmed=1";
  if (!code) return NextResponse.redirect(new URL("/auth?error=Invalid%20or%20expired%20email%20link", url));

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.exchangeCodeForSession(code);
  if (error) return NextResponse.redirect(new URL("/auth?error=Invalid%20or%20expired%20email%20link", url));
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.redirect(new URL("/auth?error=Invalid%20or%20expired%20email%20session", url));

  if (isRecovery) {
    const response = NextResponse.redirect(new URL("/auth/reset-password", url));
    response.cookies.set("je_password_recovery", "1", { httpOnly: true, secure: url.protocol === "https:", sameSite: "lax", path: "/", maxAge: 900 });
    return response;
  }
  return NextResponse.redirect(new URL(isConfirmation ? "/auth?confirmed=1" : "/auth", url));
}