"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";

export default function StatusButtons({ id, current }: { id: string; current: string }) {
  const [busy, setBusy] = useState<string | null>(null);
  const router = useRouter();
  async function set(status: string) {
    setBusy(status);
    const r = await fetch(`/api/reports/${id}/status`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ status }) });
    setBusy(null);
    if (r.ok) router.refresh(); else alert("Could not update: " + (await r.text()));
  }
  const b = (status: string, label: string, cls = "") => (
    <button key={status} className={`btn ${cls}`} disabled={current === status || busy !== null} onClick={() => set(status)}>{busy === status ? "Saving…" : label}</button>
  );
  return (<div className="btnrow">{b("confirmed", "Mark confirmed", "primary")}{b("treated", "Mark treated", "primary")}{b("dismissed", "Dismiss", "danger")}{b("new", "Back to new")}</div>);
}
