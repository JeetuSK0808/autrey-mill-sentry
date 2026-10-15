import { NextRequest, NextResponse } from "next/server";
import { getStore, validId } from "@/lib/storage";
import { isStaff } from "@/lib/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Staff only: the report photo. */
export async function GET(_req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  if (!(await isStaff())) return new NextResponse("Sign in required.", { status: 401 });
  const { id } = await ctx.params;
  if (!validId(id)) return new NextResponse("Bad id.", { status: 400 });
  const bytes = await getStore().getPhoto(id);
  if (!bytes) return new NextResponse("Not found.", { status: 404 });
  return new NextResponse(new Uint8Array(bytes), { headers: { "content-type": "image/jpeg", "cache-control": "private, max-age=3600" } });
}
