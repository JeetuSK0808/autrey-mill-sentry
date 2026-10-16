import { NextRequest, NextResponse } from "next/server";
import { getStore, validId } from "@/lib/storage";
import { isStaff } from "@/lib/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Staff: remove a report and its photo (tests, duplicates, junk). */
export async function DELETE(_req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  if (!(await isStaff())) return NextResponse.json({ error: "Sign in required." }, { status: 401 });
  const { id } = await ctx.params;
  if (!validId(id)) return NextResponse.json({ error: "Bad id." }, { status: 400 });
  await getStore().deleteReport(id);
  return NextResponse.json({ id, deleted: true });
}
