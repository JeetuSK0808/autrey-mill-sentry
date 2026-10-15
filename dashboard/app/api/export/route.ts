import { NextResponse } from "next/server";
import { getStore } from "@/lib/storage";
import { isStaff } from "@/lib/auth";
import { score } from "@/lib/rank";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function esc(s: string) { return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s; }

/** Staff: CSV of every report, same columns as the app's export plus the server status and priority. */
export async function GET() {
  if (!(await isStaff())) return new NextResponse("Sign in required.", { status: 401 });
  const all = await getStore().listReports();
  const header = "id,created_at,received_at,latitude,longitude,horizontal_accuracy_m,species_label,species_name,tier,confidence,needs_expert_review,patch_size,status,status_updated_at,nearest_trail,distance_to_creek_m,priority_score,model_version,note";
  const lines = all.map((r) => [r.id, r.createdAt, r.receivedAt, r.latitude.toFixed(6), r.longitude.toFixed(6), r.horizontalAccuracy.toFixed(1), r.species, r.speciesName, r.tier ?? "", r.confidence.toFixed(3),
    String(r.needsExpertReview), r.patchSize, r.status, r.statusUpdatedAt, r.nearestTrailName ?? "", r.distanceToCreekMeters == null ? "" : r.distanceToCreekMeters.toFixed(1), score(r, all).total.toFixed(1), r.modelVersion ?? "", r.note ?? ""].map(esc).join(","));
  return new NextResponse([header, ...lines].join("\n") + "\n", { headers: { "content-type": "text/csv; charset=utf-8", "content-disposition": `attachment; filename="mill-sentry-reports-${new Date().toISOString().slice(0, 10)}.csv"` } });
}
