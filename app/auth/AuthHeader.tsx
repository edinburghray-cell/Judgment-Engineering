import { createSupabaseServerClient } from "@/lib/supabaseServer";
import { signOut } from "./actions";
export default async function AuthHeader() {
 const supabase = await createSupabaseServerClient(); const { data: { user } } = await supabase.auth.getUser();
 if (!user) return null;
 return <header className="w-full border-b px-4 py-3 flex justify-end items-center gap-4 text-sm"><span>{user.email}</span><form action={signOut}><button className="underline" type="submit">Sign out</button></form></header>;
}
