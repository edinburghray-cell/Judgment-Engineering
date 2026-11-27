// Keep the legacy bridge URL on the same authenticated handler as the canonical
// endpoint. The user's Supabase cookie reaches the RPC, preserving auth.uid().
export { POST } from "../../execution-release/route";
