import { notFound } from "next/navigation";

export function requireShowcaseTestRoutes() {
  if (process.env.JE_ENABLE_TEST_ROUTES !== "true") notFound();
}