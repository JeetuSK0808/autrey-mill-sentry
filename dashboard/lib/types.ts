export type ReportStatus = "new" | "confirmed" | "treated" | "dismissed";

/** What the app uploads (one JSON object + one JPEG). Field names match the app's ReportRow where possible. */
export interface IncomingReport {
  id: string;
  createdAt: string;            // ISO 8601
  latitude: number;
  longitude: number;
  horizontalAccuracy: number;
  species: string;              // classifier label or "unknown"
  speciesName: string;
  scientificName?: string;
  tier?: "tier1" | "tier2" | "native" | "other";
  aggressiveness?: number;      // 0..1 from the app's catalog
  confidence: number;           // calibrated top probability
  top3?: { label: string; probability: number }[];
  needsExpertReview: boolean;
  patchSize: "few" | "patch" | "large";
  note?: string;
  nearestTrailName?: string;
  distanceToCreekMeters?: number | null;
  modelVersion?: string;
  appVersion?: string;
  lowAccuracy?: boolean;
}

export interface StoredReport extends IncomingReport {
  status: ReportStatus;
  statusUpdatedAt: string;
  receivedAt: string;
  photoPath: string;            // storage key for the JPEG
  statusHistory: { status: ReportStatus; at: string }[];
}
