import { promises as fs } from "fs";
import path from "path";
import type { StoredReport, ReportStatus } from "./types";

/** Local files in development, Vercel Blob in production. Same four operations either way. */
export interface Store {
  putReport(report: StoredReport, photo: Buffer): Promise<void>;
  updateReport(report: StoredReport): Promise<void>;
  deleteReport(id: string): Promise<void>;
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
  async deleteReport(id: string) { for (const f of [path.join(this.dir, "reports", `${id}.json`), path.join(this.dir, "photos", `${id}.jpg`)]) { try { await fs.unlink(f); } catch {} } }
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
  private async readText(pathname: string): Promise<string | null> {
    const { get } = await this.blob();
    const r = await get(pathname, { access: "private", useCache: false });
    if (!r || r.statusCode !== 200 || !r.stream) return null;
    return await new Response(r.stream).text();
  }
  async putReport(report: StoredReport, photo: Buffer) {
    const { put } = await this.blob();
    await put(`photos/${report.id}.jpg`, photo, { access: "private", addRandomSuffix: false, allowOverwrite: true, contentType: "image/jpeg" });
    await put(`reports/${report.id}.json`, JSON.stringify(report), { access: "private", addRandomSuffix: false, allowOverwrite: true, contentType: "application/json" });
  }
  async updateReport(report: StoredReport) {
    const { put } = await this.blob();
    await put(`reports/${report.id}.json`, JSON.stringify(report), { access: "private", addRandomSuffix: false, allowOverwrite: true, contentType: "application/json" });
  }
  async deleteReport(id: string) {
    const { del } = await this.blob();
    await del([`reports/${id}.json`, `photos/${id}.jpg`]);
  }
  async getReport(id: string) {
    const t = await this.readText(`reports/${id}.json`);
    try { return t ? (JSON.parse(t) as StoredReport) : null; } catch { return null; }
  }
  async listReports() {
    const { list } = await this.blob();
    const out: StoredReport[] = []; let cursor: string | undefined;
    do {
      const res = await list({ prefix: "reports/", cursor, limit: 1000 });
      const items = await Promise.all(res.blobs.map(async (b) => { const t = await this.readText(b.pathname); try { return t ? (JSON.parse(t) as StoredReport) : null; } catch { return null; } }));
      for (const i of items) if (i) out.push(i);
      cursor = res.hasMore ? res.cursor : undefined;
    } while (cursor);
    return out.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  }
  async getPhoto(id: string) {
    const { get } = await this.blob();
    const r = await get(`photos/${id}.jpg`, { access: "private", useCache: false });
    if (!r || r.statusCode !== 200 || !r.stream) return null;
    return Buffer.from(await new Response(r.stream).arrayBuffer());
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
