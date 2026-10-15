import { NextRequest, NextResponse } from "next/server";
import { getStore, validId } from "@/lib/storage";
import { isStaff } from "@/lib/auth";
import type { IncomingReport, StoredReport } from "@/lib/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const MAX_PHOTO = 6 * 1024 * 1024;
const buckets = new Map<string, { n: number; t: number }>();   // best-effort per-instance rate limit
function limited(ip: string) {
  const now = Date.now(); const b = buckets.get(ip) ?? { n: 0, t: now };
  if (now - b.t > 60_000) { b.n = 0; b.t = now; }
  b.n += 1; buckets.set(ip, b); return b.n > 30;
}

function clean(x: unknown): IncomingReport | null {
  if (typeof x !== "object" || x === null) return null;
  const r = x as Record<string, unknown>;
  const num = (v: unknown) => (typeof v === "number" && isFinite(v) ? v : null);
  const str = (v: unknown, max = 200) => (typeof v === "string" ? v.slice(0, max) : "");
  const id = str(r.id, 36); if (!validId(id)) return null;
  const lat = num(r.latitude), lon = num(r.longitude); if (lat === null || lon === null || Math.abs(lat) > 90 || Math.abs(lon) > 180) return null;
  const patch = ["few", "patch", "large"].includes(str(r.patchSize)) ? (str(r.patchSize) as IncomingReport["patchSize"]) : "patch";
  const tier = ["tier1", "tier2", "native", "other"].includes(str(r.tier)) ? (str(r.tier) as IncomingReport["tier"]) : undefined;
  const createdAt = str(r.createdAt, 40); if (isNaN(Date.parse(createdAt))) return null;
  const top3 = Array.isArray(r.top3) ? (r.top3 as unknown[]).slice(0, 3).map((t) => { const o = t as Record<string, unknown>; return { label: str(o.label, 60), probability: num(o.probability) ?? 0 }; }) : undefined;
  return {
    id, createdAt, latitude: lat, longitude: lon, horizontalAccuracy: num(r.horizontalAccuracy) ?? -1,
    species: str(r.species, 60) || "unknown", speciesName: str(r.speciesName, 80) || "Unknown plant", scientificName: str(r.scientificName, 80) || undefined,
    tier, aggressiveness: num(r.aggressiveness) ?? undefined, confidence: Math.max(0, Math.min(1, num(r.confidence) ?? 0)), top3,
    needsExpertReview: r.needsExpertReview === true, patchSize: patch, note: str(r.note, 500) || undefined,
    nearestTrailName: str(r.nearestTrailName, 80) || undefined, distanceToCreekMeters: num(r.distanceToCreekMeters),
    modelVersion: str(r.modelVersion, 40) || undefined, appVersion: str(r.appVersion, 20) || undefined, lowAccuracy: r.lowAccuracy === true,
  };
}

/** The app's Send button posts here: multipart with `report` (JSON) and `photo` (JPEG). Idempotent per report id. */
export async function POST(req: NextRequest) {
  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "local";
  if (limited(ip)) return NextResponse.json({ error: "Too many uploads, try again in a minute." }, { status: 429 });
  let form: FormData;
  try { form = await req.formData(); } catch { return NextResponse.json({ error: "Expected multipart form data." }, { status: 400 }); }
  const reportField = form.get("report"); const photo = form.get("photo");
  if (typeof reportField !== "string") return NextResponse.json({ error: "Missing report." }, { status: 400 });
  let parsed: unknown; try { parsed = JSON.parse(reportField); } catch { return NextResponse.json({ error: "Report is not JSON." }, { status: 400 }); }
  const incoming = clean(parsed); if (!incoming) return NextResponse.json({ error: "Report failed validation." }, { status: 400 });
  if (!(photo instanceof Blob) || photo.size === 0 || photo.size > MAX_PHOTO) return NextResponse.json({ error: "Photo missing or larger than 6 MB." }, { status: 400 });
  const bytes = Buffer.from(await photo.arrayBuffer());
  if (!(bytes[0] === 0xff && bytes[1] === 0xd8)) return NextResponse.json({ error: "Photo must be a JPEG." }, { status: 400 });
  const store = getStore();
  const existing = await store.getReport(incoming.id);
  if (existing) return NextResponse.json({ id: existing.id, status: existing.status, statusUpdatedAt: existing.statusUpdatedAt, duplicate: true });
  const now = new Date().toISOString();
  const stored: StoredReport = { ...incoming, status: "new", statusUpdatedAt: now, receivedAt: now, photoPath: `photos/${incoming.id}.jpg`, statusHistory: [{ status: "new", at: now }] };
  await store.putReport(stored, bytes);
  return NextResponse.json({ id: stored.id, status: stored.status, statusUpdatedAt: stored.statusUpdatedAt }, { status: 201 });
}

/** Staff only: every report as JSON. */
export async function GET() {
  if (!(await isStaff())) return NextResponse.json({ error: "Sign in required." }, { status: 401 });
  return NextResponse.json(await getStore().listReports());
}
