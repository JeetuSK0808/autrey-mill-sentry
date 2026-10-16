import { redirect } from "next/navigation";
import { openMode } from "@/lib/auth";

export const dynamic = "force-dynamic";

export default async function Login({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  if (openMode()) redirect("/");
  const { error } = await searchParams;
  return (
    <main className="wrap" style={{ maxWidth: 520 }}>
      <h1>Staff sign in</h1>
      <p className="sub">Enter the preserve's access code. Ask Jeetu SK if you do not have it.</p>
      {error && <p className="notice" style={{ borderColor: "rgba(120,57,140,.3)" }}>That code did not match. Try again.</p>}
      <form method="post" action="/api/login" className="card" style={{ display: "grid", gap: 12 }}>
        <label htmlFor="code">Access code</label>
        <input id="code" name="code" type="password" autoComplete="current-password" required />
        <button className="btn primary" type="submit">Sign in</button>
        <p className="footnote">This page sets one cookie so you stay signed in on this device for 90 days. No account, no email.</p>
      </form>
    </main>
  );
}
