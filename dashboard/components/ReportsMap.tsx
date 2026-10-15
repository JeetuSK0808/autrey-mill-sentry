"use client";
import { useEffect, useRef } from "react";

export interface Pin { id: string; lat: number; lon: number; status: string; title: string; subtitle: string }

/** Leaflet with OpenStreetMap tiles and the bundled preserve geometry (same GeoJSON as the app). Loaded from a CDN on the client. */
export default function ReportsMap({ pins, focus, height = 440 }: { pins: Pin[]; focus?: { lat: number; lon: number }; height?: number }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    let map: any; let cancelled = false;
    const colors: Record<string, string> = { new: "#456ba8", confirmed: "#78398c", treated: "#1c6b4a", dismissed: "#8e8e93" };
    async function init() {
      if (!document.getElementById("leaflet-css")) {
        const link = document.createElement("link"); link.id = "leaflet-css"; link.rel = "stylesheet"; link.href = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"; document.head.appendChild(link);
      }
      if (!(window as any).L) {
        await new Promise<void>((res, rej) => { const s = document.createElement("script"); s.src = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"; s.onload = () => res(); s.onerror = () => rej(); document.head.appendChild(s); });
      }
      if (cancelled || !ref.current) return;
      const L = (window as any).L;
      map = L.map(ref.current, { scrollWheelZoom: false });
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", { maxZoom: 19, attribution: "&copy; OpenStreetMap contributors" }).addTo(map);
      const layers: any[] = [];
      for (const [name, style] of [["boundary", { color: "#1c6b4a", weight: 2, fillOpacity: 0.06 }], ["waterways", { color: "#2a7dcc", weight: 3 }], ["trails", { color: "#5c4027", weight: 3 }]] as const) {
        try { const g = await (await fetch(`/geo/${name}.geojson`)).json(); layers.push(L.geoJSON(g, { style, onEachFeature: (f: any, l: any) => { const n = f.properties?.display_name || f.properties?.name; if (n) l.bindTooltip(n); } }).addTo(map)); } catch {}
      }
      const group = L.featureGroup();
      for (const p of pins) {
        const m = L.circleMarker([p.lat, p.lon], { radius: 9, color: "#fff", weight: 2, fillColor: colors[p.status] ?? "#8e8e93", fillOpacity: 1 });
        m.bindPopup(`<strong>${p.title}</strong><br>${p.subtitle}<br><a href="/reports/${p.id}">Open report</a>`);
        group.addLayer(m);
      }
      group.addTo(map);
      if (focus) map.setView([focus.lat, focus.lon], 18);
      else if (pins.length) map.fitBounds(group.getBounds().pad(0.3));
      else map.setView([34.0199, -84.2326], 16);
    }
    init();
    return () => { cancelled = true; if (map) map.remove(); };
  }, [JSON.stringify(pins), focus?.lat, focus?.lon]);
  return <div ref={ref} className="map" style={{ height }} role="region" aria-label="Map of reports" />;
}
