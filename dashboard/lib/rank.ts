import type { StoredReport } from "./types";

/** Same transparent score as the app (docs/RANKING.md): 0..100, early-detection first. */
export const WEIGHTS = { patchSize: 25, isolation: 15, creekProximity: 20, confidence: 15, recency: 10, speciesAggressiveness: 15,
  creekFullPointsWithinMeters: 15, creekZeroPointsBeyondMeters: 150, recencyFullPointsWithinDays: 7, recencyFloorAtDays: 90, isolationRadiusMeters: 30 };

export function distanceMeters(a: { latitude: number; longitude: number }, b: { latitude: number; longitude: number }) {
  const R = 6371008.8, d = Math.PI / 180;
  const dLat = (b.latitude - a.latitude) * d, dLon = (b.longitude - a.longitude) * d;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.latitude * d) * Math.cos(b.latitude * d) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}

export interface Factor { name: string; points: number; max: number; reason: string }

export function score(r: StoredReport, all: StoredReport[], now = new Date()): { total: number; factors: Factor[] } {
  const open = r.status === "new" || r.status === "confirmed";
  if (!open) return { total: 0, factors: [{ name: "Closed", points: 0, max: 100, reason: "Treated or dismissed reports are not ranked." }] };
  const W = WEIGHTS; const f: Factor[] = [];
  const patch = r.patchSize === "few" ? 1 : r.patchSize === "patch" ? 0.6 : 0.2;
  f.push({ name: "Patch size", points: patch * W.patchSize, max: W.patchSize, reason: r.patchSize === "few" ? "A few plants: cheapest to remove now." : r.patchSize === "patch" ? "A patch: still manageable." : "A large stand: ranked lower for early detection." });
  const nearby = all.filter((o) => o.id !== r.id && (o.status === "new" || o.status === "confirmed") && distanceMeters(o, r) <= W.isolationRadiusMeters).length;
  const iso = nearby === 0 ? 1 : nearby <= 2 ? 0.6 : 0.2;
  f.push({ name: "Isolation", points: iso * W.isolation, max: W.isolation, reason: nearby === 0 ? "No other open reports within 100 ft." : `${nearby} other report(s) nearby.` });
  let creek = 0, creekReason = "No waterway data.";
  if (typeof r.distanceToCreekMeters === "number") {
    const d = r.distanceToCreekMeters;
    creek = d <= W.creekFullPointsWithinMeters ? 1 : d >= W.creekZeroPointsBeyondMeters ? 0 : 1 - (d - W.creekFullPointsWithinMeters) / (W.creekZeroPointsBeyondMeters - W.creekFullPointsWithinMeters);
    creekReason = `${Math.round(d * 3.28084)} ft from the creek.`;
  }
  f.push({ name: "Near the creek", points: creek * W.creekProximity, max: W.creekProximity, reason: creekReason });
  const confRaw = r.needsExpertReview ? Math.min(r.confidence, 0.3) : r.confidence;
  const conf = Math.max(0, Math.min(1, (confRaw - 0.5) / 0.5));
  f.push({ name: "Model confidence", points: conf * W.confidence, max: W.confidence, reason: r.needsExpertReview ? "Needs expert review." : `${Math.round(r.confidence * 100)}% calibrated confidence.` });
  const ageDays = (now.getTime() - new Date(r.createdAt).getTime()) / 86400000;
  let rec = 1;
  if (ageDays > W.recencyFullPointsWithinDays) rec = Math.max(0.3, 1 - (0.7 * (ageDays - W.recencyFullPointsWithinDays)) / Math.max(1, W.recencyFloorAtDays - W.recencyFullPointsWithinDays));
  f.push({ name: "Recent and unaddressed", points: rec * W.recency, max: W.recency, reason: ageDays <= 7 ? "Reported in the last week." : `${Math.round(ageDays)} days old and still open.` });
  const agg = Math.max(0, Math.min(1, r.aggressiveness ?? (r.species === "unknown" ? 0.3 : 0)));
  f.push({ name: "Aggressive spreader", points: agg * W.speciesAggressiveness, max: W.speciesAggressiveness, reason: `Weight ${agg.toFixed(2)} (Georgia Forestry Commission Dirty Dozen).` });
  const total = Math.round(f.reduce((s, x) => s + x.points, 0) * 10) / 10;
  return { total, factors: f };
}

export function feet(m: number) { return `${Math.round(m * 3.28084)} ft`; }
export function fmtDate(iso: string) { return new Date(iso).toLocaleString("en-US", { month: "short", day: "numeric", year: "numeric", hour: "numeric", minute: "2-digit", timeZone: "America/New_York" }); }
export const STATUS_LABEL: Record<string, string> = { new: "New", confirmed: "Confirmed", treated: "Treated", dismissed: "Dismissed" };
export const PATCH_LABEL: Record<string, string> = { few: "Few plants", patch: "Patch", large: "Large stand" };
