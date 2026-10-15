import { promises as fs } from "fs";
import path from "path";
import type { StoredReport, ReportStatus } from "./types";

/** Local files in development, Vercel Blob in production. Same four operations either way. */
export interface Store {
  putReport(report: StoredReport, photo: Buffer): Promise<void>;
  updateReport(report: StoredReport): Promise<void>;
  getReport(id: string): Promise<StoredReport | null>;
  listReports(): Promise<StoredReport[]>;
  getPhoto(id: string): Promise<Buffer | null>;
}

const ID = /^[0-9a-fA-F-]{36}$/;
export function validId(id: string): boolean { return ID.test(id); }

class LocalStore implements Store {
  constructor(private dir: string) {}
  private async ensure() { await fs.mkdir(path.join(this.dir, "reports"), { recursive: true }); await fs.mkdir(path.join(this.dir, "photos"), { recursive: true }); }
  async putReport(report: StoredReport, photo: Buffer) {
    await this.ensure();
    await fs.writeFile(path.join(this.dir, "photos", `${report.id}.jpg`), photo);
    await fs.writeFile(path.join(this.dir, "reports", `${report.id}.json`), JSON.stringify(report, null, 1));
  }
  async updateReport(report: StoredReport) { await this.ensure(); await fs.writeFile(path.join(this.dir, "reports", `${report.id}.json`), JSON.stringify(report, null, 1)); }
  async getReport(id: string) {
    try { return JSON.parse(await fs.readFile(path.join(this.dir, "reports", `${id}.json`), "utf8")) as StoredReport; } catch { return null; }
  }
  async listReports() {
    await this.ensure();
    const files = (await fs.readdir(path.join(this.dir, "reports"))).filter((f) => f.endsWith(".json"));
    const out: StoredReport[] = [];
    for (const f of files) { try { out.push(JSON.parse(await fs.readFile(path.join(this.dir, "reports", f), "utf8"))); } catch {} }
    return out.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  }
  async getPhoto(id: string) { try { return await fs.readFile(path.join(this.dir, "photos", `${id}.jpg`)); } catch { return null; } }
}

class BlobStore implements Store {
  private async blob() { return await import("@vercel/blob"); }
  private async fetchJSON(url: string) {
    const r = await fetch(url, { cache: "no-store" }); if (!r.ok) return null; return (await r.json()) as StoredReport;
  }
  async putReport(report: StoredReport, photo: Buffer) {
    const { put } = await this.blob();
    await put(`photos/${report.id}.jpg`, photo, { access: "public", addRandomSuffix: false, contentType: "image/jpeg" });
    await put(`reports/${report.id}.json`, JSON.stringify(report), { access: "public", addRandomSuffix: false, contentType: "application/json" });
  }
  async updateReport(report: StoredReport) {
    const { put } = await this.blob();
    await put(`reports/${report.id}.json`, JSON.stringify(report), { access: "public", addRandomSuffix: false, contentType: "application/json" });
  }
  async getReport(id: string) {
    const { list } = await this.blob();
    const res = await list({ prefix: `reports/${id}.json`, limit: 1 });
    const b = res.blobs[0]; if (!b) return null;
    return this.fetchJSON(b.url);
  }
  async listReports() {
    const { list } = await this.blob();
    const out: StoredReport[] = []; let cursor: string | undefined;
    do {
      const res = await list({ prefix: "reports/", cursor, limit: 1000 });
      const items = await Promise.all(res.blobs.map((b) => this.fetchJSON(b.url)));
      for (const i of items) if (i) out.push(i);
      cursor = res.hasMore ? res.cursor : undefined;
    } while (cursor);
    return out.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  }
  async getPhoto(id: string) {
    const { list } = await this.blob();
    const res = await list({ prefix: `photos/${id}.jpg`, limit: 1 });
    const b = res.blobs[0]; if (!b) return null;
    const r = await fetch(b.url, { cache: "no-store" }); if (!r.ok) return null;
    return Buffer.from(await r.arrayBuffer());
  }
}

let store: Store | null = null;
export function getStore(): Store {
  if (store) return store;
  store = process.env.BLOB_READ_WRITE_TOKEN ? new BlobStore() : new LocalStore(process.env.DASHBOARD_DATA_DIR ?? path.join(process.cwd(), "data-local"));
  return store;
}

export function nextStatus(report: StoredReport, status: ReportStatus): StoredReport {
  const at = new Date().toISOString();
  return { ...report, status, statusUpdatedAt: at, statusHistory: [...(report.statusHistory ?? []), { status, at }] };
}
