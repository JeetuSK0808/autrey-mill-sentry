import { createHmac, timingSafeEqual } from "crypto";
import { cookies } from "next/headers";

/** Staff sign-in is one access code (STAFF_ACCESS_CODE on Vercel). The cookie is an HMAC of a fixed message under that code. */
export const COOKIE = "sentry_staff";
function code() { return process.env.STAFF_ACCESS_CODE ?? ""; }
export function configured() { return code().length >= 4; }
export function tokenFor(c: string) { return createHmac("sha256", c).update("mill-sentry-staff-v1").digest("hex"); }
export function codeMatches(input: string) {
  const a = Buffer.from(tokenFor(input)); const b = Buffer.from(tokenFor(code()));
  return configured() && a.length === b.length && timingSafeEqual(a, b);
}
export async function isStaff(): Promise<boolean> {
  if (!configured()) return false;
  const c = (await cookies()).get(COOKIE)?.value ?? "";
  const expected = tokenFor(code());
  return c.length === expected.length && timingSafeEqual(Buffer.from(c), Buffer.from(expected));
}
