import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import Link from "next/link";
import { updateRecoveredPassword } from "../actions";
import { createSupabaseServerClient } from "@/lib/supabaseServer";
export default async function ResetPassword({ searchParams }: { searchParams: Promise<{ error?: string; done?: string }> }) {
 const jar = await cookies(); const supabase = await createSupabaseServerClient(); const { data: { user } } = await supabase.auth.getUser();
 if (jar.get("je_password_recovery")?.value !== "1" || !user) redirect("/auth?error=Open%20a%20valid%20recovery%20link%20first");
 const params = await searchParams;
 return <main className="max-w-md mx-auto px-4 py-16"><section className="border rounded-lg p-6"><h1 className="text-2xl font-bold">Choose a new password</h1>{params.error && <p className="text-red-700 mt-3">{params.error}</p>}{params.done && <p className="text-green-700 mt-3">Password updated. <Link className="underline" href="/auth">Return to sign in</Link></p>}<form action={updateRecoveredPassword} className="mt-5 space-y-4"><label className="block">New password<input name="password" type="password" required minLength={8} className="block w-full border rounded p-3 mt-1" /></label><label className="block">Confirm new password<input name="confirmation" type="password" required minLength={8} className="block w-full border rounded p-3 mt-1" /></label><p className="text-sm text-gray-600">Use at least 8 characters.</p><button className="w-full bg-black text-white rounded p-3">Update password</button></form><Link className="block mt-4 underline" href="/auth">Back to login</Link></section></main>;
}
