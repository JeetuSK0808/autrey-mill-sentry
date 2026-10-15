import type { Metadata } from "next";
import "./globals.css";
import { isStaff, configured } from "@/lib/auth";
import Link from "next/link";

export const metadata: Metadata = { title: "Mill Sentry · Preserve dashboard", description: "Invasive plant reports from the Autrey Mill Sentry app, for preserve staff." };

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const staff = await isStaff();
  return (
    <html lang="en">
      <body>
        <header className="topbar">
          <Link className="brand" href="/"><span className="mark">🌿</span> Mill Sentry</Link>
          <nav className="nav">
            {staff ? (<><Link href="/">Reports</Link><Link href="/map">Map</Link><a href="/api/export">Export CSV</a><Link href="/about">About</Link></>) : (configured() ? <Link href="/login">Staff sign in</Link> : null)}
          </nav>
        </header>
        {children}
      </body>
    </html>
  );
}
