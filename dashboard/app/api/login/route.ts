import { NextRequest, NextResponse } from "next/server";
import { COOKIE, codeMatches, configured, tokenFor } from "@/lib/auth";

export const runtime = "nodejs";

function origin(req: NextRequest) {
  const proto = req.headers.get("x-forwarded-proto") ?? (req.nextUrl.protocol.replace(":", "") || "http");
  const host = req.headers.get("x-forwarded-host") ?? req.headers.get("host") ?? req.nextUrl.host;
  return `${proto}://${host}`;
}

export async function POST(req: NextRequest) {
  const form = await req.formData();
  const code = String(form.get("code") ?? "");
  const res = NextResponse.redirect(new URL(codeMatches(code) ? "/" : "/login?error=1", origin(req)), 303);
  if (configured() && codeMatches(code)) {
    res.cookies.set(COOKIE, tokenFor(code), { httpOnly: true, sameSite: "lax", secure: process.env.NODE_ENV === "production", path: "/", maxAge: 60 * 60 * 24 * 90 });
  }
  return res;
}

export async function DELETE(req: NextRequest) {
  const res = NextResponse.redirect(new URL("/login", origin(req)), 303);
  res.cookies.set(COOKIE, "", { path: "/", maxAge: 0 });
  return res;
}
