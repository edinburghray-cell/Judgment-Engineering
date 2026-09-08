import { createSupabaseServerClient } from "@/lib/supabaseServer";
import { redirect } from "next/navigation";

export default async function AuthPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;

  async function signIn(formData: FormData) {
    "use server";

    const email = String(formData.get("email") || "").trim();
    const password = String(formData.get("password") || "");

    if (!email || !password) {
      redirect("/auth?error=Email%20and%20password%20are%20required");
    }

    const supabase = await createSupabaseServerClient();

    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      redirect(`/auth?error=${encodeURIComponent(error.message)}`);
    }

    redirect("/units");
  }

  return (
    <main className="max-w-md mx-auto px-4 py-16">
      <section className="border rounded-lg p-6">
        <p className="text-sm font-medium text-gray-500">
          JUDGMENT ENGINEERING
        </p>

        <h1 className="text-2xl font-bold mt-2">
          Sign in
        </h1>

        <p className="text-sm text-gray-600 mt-2">
          Sign in to perform authorized judgment transfers.
        </p>

        {params.error && (
          <p className="text-sm text-red-700 mt-4">
            {params.error}
          </p>
        )}

        <form action={signIn} className="mt-6 space-y-4">
          <div>
            <label className="block text-sm font-medium">
              Email
            </label>
            <input
              name="email"
              type="email"
              required
              className="w-full border rounded p-3 mt-1"
            />
          </div>

          <div>
            <label className="block text-sm font-medium">
              Password
            </label>
            <input
              name="password"
              type="password"
              required
              className="w-full border rounded p-3 mt-1"
            />
          </div>

          <button
            type="submit"
            className="w-full bg-black text-white rounded p-3"
          >
            Sign in
          </button>
        </form>
      </section>
    </main>
  );
}
