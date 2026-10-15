import { NextRequest, NextResponse } from "next/server";
import { getStore, nextStatus, validId } from "@/lib/storage";
import { isStaff } from "@/lib/auth";
import type { ReportStatus } from "@/lib/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Public: the app polls this to learn when staff treated a report (the "Tell" step). Only status fields are returned. */
export async function GET(_req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const { id } = await ctx.params;
  if (!validId(id)) return NextResponse.json({ error: "Bad id." }, { status: 400 });
  const r = await getStore().getReport(id);
  if (!r) return NextResponse.json({ error: "Not found." }, { status: 404 });
  return NextResponse.json({ id: r.id, status: r.status, statusUpdatedAt: r.statusUpdatedAt });
}

/** Staff: change the status. Body: { "status": "confirmed" | "treated" | "dismissed" | "new" } */
export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  if (!(await isStaff())) return NextResponse.json({ error: "Sign in required." }, { status: 401 });
  const { id } = await ctx.params;
  if (!validId(id)) return NextResponse.json({ error: "Bad id." }, { status: 400 });
  const body = (await req.json().catch(() => ({}))) as { status?: string };
  const status = body.status as ReportStatus;
  if (!["new", "confirmed", "treated", "dismissed"].includes(status)) return NextResponse.json({ error: "Bad status." }, { status: 400 });
  const store = getStore(); const r = await store.getReport(id);
  if (!r) return NextResponse.json({ error: "Not found." }, { status: 404 });
  const updated = nextStatus(r, status); await store.updateReport(updated);
  return NextResponse.json({ id, status: updated.status, statusUpdatedAt: updated.statusUpdatedAt });
}
