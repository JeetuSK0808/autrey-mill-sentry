import Link from "next/link";
import { redirect } from "next/navigation";
import { isStaff } from "@/lib/auth";
import { getStore } from "@/lib/storage";
import { score, fmtDate, PATCH_LABEL } from "@/lib/rank";
import StatusBadge from "@/components/StatusBadge";
import ReportsMap from "@/components/ReportsMap";

export const dynamic = "force-dynamic";

export default async function Home({ searchParams }: { searchParams: Promise<{ status?: string; species?: string; sort?: string }> }) {
  if (!(await isStaff())) redirect("/login");
  const { status, species, sort } = await searchParams;
  const all = await getStore().listReports();
  const ranked = all.map((r) => ({ r, s: score(r, all) }));
  const open = ranked.filter((x) => x.r.status === "new" || x.r.status === "confirmed");
  const counts = { new: all.filter((r) => r.status === "new").length, confirmed: all.filter((r) => r.status === "confirmed").length, treated: all.filter((r) => r.status === "treated").length, review: all.filter((r) => r.needsExpertReview && (r.status === "new")).length, species: new Set(all.map((r) => r.species)).size };
  let list = ranked.filter((x) => (!status || x.r.status === status) && (!species || x.r.species === species));
  if (sort === "newest") list = list.sort((a, b) => b.r.createdAt.localeCompare(a.r.createdAt)); else list = list.sort((a, b) => b.s.total - a.s.total || b.r.createdAt.localeCompare(a.r.createdAt));
  const speciesList = Array.from(new Map(all.map((r) => [r.species, r.speciesName])).entries()).sort((a, b) => a[1].localeCompare(b[1]));
  const q = (o: Record<string, string | undefined>) => { const p = new URLSearchParams(); for (const [k, v] of Object.entries({ status, species, sort, ...o })) if (v) p.set(k, v); const s = p.toString(); return s ? `/?${s}` : "/"; };
  return (
    <main className="wrap">
      <h1>Invasive plant reports</h1>
      <p className="sub">From visitors using the Mill Sentry app at Autrey Mill. Ranked so the cheapest-to-fix patches come first: small, isolated, near the creek, recent. AI suggestions, not guarantees. Staff make the final call.</p>
      <div className="grid tiles">
        <div className="tile"><div className="num">{counts.new}</div><div className="lab">New</div></div>
        <div className="tile"><div className="num">{counts.review}</div><div className="lab">Need expert review</div></div>
        <div className="tile"><div className="num">{counts.confirmed}</div><div className="lab">Confirmed</div></div>
        <div className="tile"><div className="num">{counts.treated}</div><div className="lab">Treated</div></div>
        <div className="tile"><div className="num">{counts.species}</div><div className="lab">Species reported</div></div>
      </div>
      <h2>Where</h2>
      <ReportsMap pins={open.map(({ r }) => ({ id: r.id, lat: r.latitude, lon: r.longitude, status: r.status, title: r.speciesName, subtitle: `${PATCH_LABEL[r.patchSize]} · ${fmtDate(r.createdAt)}` }))} />
      <h2>Work list</h2>
      <div className="filters">
        <Link className={`chip ${!status ? "active" : ""}`} href={q({ status: undefined })}>All</Link>
        {(["new", "confirmed", "treated", "dismissed"] as const).map((s) => <Link key={s} className={`chip ${status === s ? "active" : ""}`} href={q({ status: s })}>{s[0].toUpperCase() + s.slice(1)}</Link>)}
        <span style={{ flex: 1 }} />
        <Link className={`chip ${sort !== "newest" ? "active" : ""}`} href={q({ sort: undefined })}>By priority</Link>
        <Link className={`chip ${sort === "newest" ? "active" : ""}`} href={q({ sort: "newest" })}>Newest</Link>
      </div>
      {speciesList.length > 1 && (
        <div className="filters">
          <Link className={`chip ${!species ? "active" : ""}`} href={q({ species: undefined })}>All species</Link>
          {speciesList.map(([label, name]) => <Link key={label} className={`chip ${species === label ? "active" : ""}`} href={q({ species: label })}>{name}</Link>)}
        </div>
      )}
      <div className="card">
        {list.length === 0 && <p className="footnote">No reports yet. When a visitor taps Send in the app, the report appears here within seconds.</p>}
        {list.map(({ r, s }, i) => (
          <Link key={r.id} href={`/reports/${r.id}`} className="row" style={{ color: "inherit", textDecoration: "none" }}>
            <div className="rank">{sort === "newest" ? "" : i + 1}</div>
            <img className="thumb" src={`/api/photos/${r.id}`} alt="" loading="lazy" />
            <div className="main">
              <div className="title">{r.speciesName}{r.scientificName ? <span className="meta" style={{ fontWeight: 400 }}> · <i>{r.scientificName}</i></span> : null}</div>
              <div className="meta">{fmtDate(r.createdAt)} · {PATCH_LABEL[r.patchSize]}{r.nearestTrailName ? ` · ${r.nearestTrailName}` : ""}{r.note ? ` · “${r.note.slice(0, 60)}${r.note.length > 60 ? "…" : ""}”` : ""}</div>
              <div style={{ marginTop: 4 }}><StatusBadge status={r.status} review={r.needsExpertReview} /></div>
            </div>
            <div className="score" title="Priority score, 0 to 100">{s.total > 0 ? Math.round(s.total) : "—"}</div>
          </Link>
        ))}
      </div>
      <p className="footnote" style={{ marginTop: 14 }}>Priority = patch size 25 + isolation 15 + near the creek 20 + model confidence 15 + recency 10 + aggressive spreader 15. Treatment method is the staff's decision; the app never recommends one.</p>
    </main>
  );
}
