import { redirect } from "next/navigation";
import { isStaff } from "@/lib/auth";
import { getStore } from "@/lib/storage";
import { fmtDate, PATCH_LABEL } from "@/lib/rank";
import ReportsMap from "@/components/ReportsMap";

export const dynamic = "force-dynamic";

export default async function MapPage() {
  if (!(await isStaff())) redirect("/login");
  const all = await getStore().listReports();
  return (
    <main className="wrap">
      <h1>Map</h1>
      <p className="sub">Every report, coloured by status: slate = new, plum = confirmed, green = treated, grey = dismissed. Trails, boundary and Sal's Creek from OpenStreetMap.</p>
      <ReportsMap height={620} pins={all.map((r) => ({ id: r.id, lat: r.latitude, lon: r.longitude, status: r.status, title: r.speciesName, subtitle: `${PATCH_LABEL[r.patchSize]} · ${fmtDate(r.createdAt)}` }))} />
      <p className="footnote" style={{ marginTop: 12 }}>Map data © OpenStreetMap contributors (ODbL).</p>
    </main>
  );
}
