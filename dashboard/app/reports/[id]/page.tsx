import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { isStaff } from "@/lib/auth";
import { getStore, validId } from "@/lib/storage";
import { score, fmtDate, feet, PATCH_LABEL } from "@/lib/rank";
import StatusBadge from "@/components/StatusBadge";
import StatusButtons from "@/components/StatusButtons";
import ReportsMap from "@/components/ReportsMap";

export const dynamic = "force-dynamic";

export default async function ReportPage({ params }: { params: Promise<{ id: string }> }) {
  if (!(await isStaff())) redirect("/login");
  const { id } = await params;
  if (!validId(id)) notFound();
  const store = getStore(); const r = await store.getReport(id); if (!r) notFound();
  const all = await store.listReports(); const s = score(r, all);
  return (
    <main className="wrap">
      <p><Link href="/">← All reports</Link></p>
      <h1>{r.speciesName}</h1>
      <p className="sub">{r.scientificName ? <i>{r.scientificName} · </i> : null}<StatusBadge status={r.status} review={r.needsExpertReview} /></p>
      <div className="two">
        <div>
          <img className="photo" src={`/api/photos/${r.id}`} alt={`Photo of the reported ${r.speciesName}`} />
          <p className="footnote">Photo taken by the visitor in the app. Location metadata was stripped from the file; the coordinates below come from the report.</p>
        </div>
        <div className="grid" style={{ gap: 14 }}>
          <div className="card">
            <h2 style={{ marginTop: 0 }}>Staff action</h2>
            <StatusButtons id={r.id} current={r.status} />
            <p className="footnote" style={{ marginTop: 10 }}>Marking a report treated tells the visitor's app on its next check. Treatment method is yours to decide.</p>
          </div>
          <div className="card">
            <dl>
              <dt>Reported</dt><dd>{fmtDate(r.createdAt)}</dd>
              <dt>Received</dt><dd>{fmtDate(r.receivedAt)}</dd>
              <dt>Patch size</dt><dd>{PATCH_LABEL[r.patchSize]}</dd>
              <dt>Location</dt><dd>{r.latitude.toFixed(5)}, {r.longitude.toFixed(5)} (±{feet(Math.max(r.horizontalAccuracy, 0))}){r.lowAccuracy ? " · low accuracy" : ""} · <a href={`https://maps.apple.com/?ll=${r.latitude},${r.longitude}&q=${encodeURIComponent(r.speciesName)}`} target="_blank" rel="noreferrer">Open in Maps</a></dd>
              <dt>Nearest trail</dt><dd>{r.nearestTrailName || "Unknown"}</dd>
              <dt>Distance to creek</dt><dd>{typeof r.distanceToCreekMeters === "number" ? feet(r.distanceToCreekMeters) : "n/a"}</dd>
              <dt>Model confidence</dt><dd>{Math.round(r.confidence * 100)}%{r.modelVersion ? ` (model ${r.modelVersion})` : ""}</dd>
              {r.top3 && r.top3.length > 0 && (<><dt>Top guesses</dt><dd>{r.top3.map((t) => `${t.label.replace(/_/g, " ")} ${Math.round(t.probability * 100)}%`).join(", ")}</dd></>)}
              {r.note && (<><dt>Visitor's note</dt><dd>{r.note}</dd></>)}
              <dt>Status changes</dt><dd>{(r.statusHistory ?? []).map((h) => `${h.status} · ${fmtDate(h.at)}`).join(" → ")}</dd>
            </dl>
          </div>
          <div className="card">
            <h2 style={{ marginTop: 0 }}>Priority {s.total > 0 ? Math.round(s.total) : "—"}<span className="footnote"> / 100</span></h2>
            <dl>{s.factors.map((f) => (<span key={f.name} style={{ display: "contents" }}><dt>{f.name}</dt><dd><strong>{Math.round(f.points)}</strong> of {f.max} · <span className="footnote">{f.reason}</span></dd></span>))}</dl>
          </div>
        </div>
      </div>
      <h2>On the map</h2>
      <ReportsMap pins={[{ id: r.id, lat: r.latitude, lon: r.longitude, status: r.status, title: r.speciesName, subtitle: fmtDate(r.createdAt) }]} focus={{ lat: r.latitude, lon: r.longitude }} height={360} />
    </main>
  );
}
