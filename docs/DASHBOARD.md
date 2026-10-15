# Preserve dashboard (dashboard/)

A small Next.js site for preserve staff: every report sent from the app, ranked, on a map, with photos, status buttons and a CSV export. Designed for people who are not technical: one access code, big buttons, no account.

## How it fits the app
- The app's Reports > Send sheet has **Send to preserve staff**. It uploads each unsent report (JSON + the EXIF-stripped JPEG) to `POST /api/reports`. The server validates everything, rejects non-JPEG or >6 MB photos, and is idempotent per report id.
- Staff open the site, sign in once with the access code, and see the **work list** ranked by the same priority score as the app, the **map** (OpenStreetMap tiles plus the preserve's trails, boundary and creek), each **report page** with the photo and four status buttons, and **Export CSV**.
- The app polls `GET /api/reports/{id}/status` (public, status only) when it comes to the foreground. When staff mark a report **treated**, the app updates the report and fires the local "Your privet report was treated" notification. That is the Tell step, for real.
- Storage: Vercel Blob (free tier) in production, a local folder in development. No database to administer.

## Jeetu: deploy it (about 10 minutes, no cost)
1. Push the repo to a **private** GitHub repository (your call per HANDOFF).
2. On vercel.com: **Add New > Project > Import** that repository. Set **Root Directory** to `dashboard`. Framework: Next.js (auto). Deploy.
3. In the project: **Storage > Create Database > Blob** (free). Connect it to the project. Vercel adds `BLOB_READ_WRITE_TOKEN` to the environment automatically.
4. **Settings > Environment Variables**: add `STAFF_ACCESS_CODE` = the code staff will use (choose something a ranger can type; you give it to them in person). Redeploy once so both variables are live.
5. Open the site, sign in with the code, you should see "No reports yet".
6. Put the site address into the app: Reports > gear > **Preserve link > Preserve dashboard address** (for example `millsentry.vercel.app`). Then **Send to preserve staff** from the Send sheet. The report appears on the site within seconds.
7. Tell Claude the address so it becomes the default in `Config.defaultDashboardURL` for every install.

## Testing on your own Wi-Fi first (no Vercel needed)
Claude can run the site on the Mac: `cd dashboard && STAFF_ACCESS_CODE=<code> npm run dev`. On the phone, set the dashboard address to `http://<Mac LAN IP>:3000` (the app allows plain http only for local-network addresses). Send a report, open `http://<Mac LAN IP>:3000` in Safari on the phone or a laptop with the code, mark it treated, reopen the app: the notification fires.

## Privacy notes
- Reports carry no identity. Photos are the app's EXIF-stripped JPEGs. The site has no analytics.
- Photos and report JSON live in Vercel Blob at unguessable paths keyed by the report's random id; the dashboard only serves them to signed-in staff. If the preserve wants the files private at the storage level too, that is a one-line change once Blob private access is available on the free tier.
- The upload endpoint is open by design (visitors have no accounts) with size limits and a per-instance rate limit. An upload key can be added later if abuse appears.
