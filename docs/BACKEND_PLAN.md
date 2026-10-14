# Backend plan (not built): sharing reports with preserve staff

Today every report stays on the phone until the user exports a package (PDF + CSV + photos) through Mail or the share sheet. The Reports screen has a "Share with preserve staff" button that only shows a notice saying this is not live yet. Nothing is uploaded anywhere.

If the preserve wants a live review queue, the cheapest honest design is:

- **Supabase free tier** (Postgres + storage + row-level security). One table `reports` (id, created_at, lat, lon, accuracy_m, species, confidence, needs_expert_review, patch_size, note, status, model_version) and one storage bucket `photos` for EXIF-stripped JPEGs.
- **No user accounts.** The app writes with an anon key restricted by RLS to `insert` only, and only into `reports`/`photos`. Staff log in to a tiny web page (Supabase Auth, email magic link) to see the queue, change status, and export.
- **Tell step for real:** the app polls its own report ids (stored locally) for status changes, or receives a push through a Supabase edge function. Until then the local "treated" notification demonstrates the loop on one device.
- **Privacy:** the same data minimisation holds (no identity, EXIF stripped, precise coordinates only for staff, no analytics). Add a one-line consent on the Send screen: "Sending uploads this report's photo and location to the preserve's review queue."
- **Keys:** the anon key would live in the app binary (that is normal for Supabase anon keys with RLS) but never in this repo's history until the project exists. Nothing paid.

`ReportSyncing` is the seam: `LocalOnlySync` today, `SupabaseSync` later, same package format.
