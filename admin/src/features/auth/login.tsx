"use client";
import { useRef, useState } from "react";
import { useSession } from "./session";
import { Loading, Notice } from "../../components/feedback";
export function Login() {
  const session = useSession();
  const [error, setError] = useState(""),
    [busy, setBusy] = useState(false),
    [showPassword, setShowPassword] = useState(false);
  const locked = useRef(false);
  const passwordInput = useRef<HTMLInputElement>(null);
  const unavailable = session.state === "error";
  if (session.state === "loading")
    return (
      <main className="login">
        <Loading />
      </main>
    );
  return (
    <main className="login">
      <section className="login-story">
        <div className="brand">
          ▤ EEELibrary <span>ADMIN</span>
        </div>
        <p className="eyebrow">THE WORK BEHIND THE LEARNING</p>
        <h1>
          A thoughtful library.
          <br />
          In trusted hands.
        </h1>
        <p>
          Manage the catalog, review payments, and support every reader from one
          secure workspace.
        </p>
        <div className="story-card">
          Books, opportunities,
          <br />
          <strong>and a little more possibility.</strong>
        </div>
      </section>
      <section className="login-form">
        <p className="eyebrow">EEELIBRARY WORKSPACE</p>
        <h2>{session.state === "denied" ? "Access denied" : "Welcome back"}</h2>
        <p>Sign in with your provisioned administrator account.</p>
        {session.state === "denied" ? (
          <>
            <Notice error>
              This account does not have active administrator access. Contact
              your trusted operator.
            </Notice>
            <button
              onClick={() =>
                void session
                  .logout()
                  .catch(() => setError("Could not sign out. Try again."))
              }
            >
              Sign out
            </button>
          </>
        ) : (
          <form
            onSubmit={async (event) => {
              event.preventDefault();
              if (locked.current || unavailable) return;
              locked.current = true;
              setBusy(true);
              setError("");
              setShowPassword(false);
              const data = new FormData(event.currentTarget);
              try {
                await session.login(
                  String(data.get("email")),
                  String(data.get("password")),
                );
              } catch {
                setError(
                  "Unable to sign in. Check your email, password and connection.",
                );
              } finally {
                locked.current = false;
                setBusy(false);
              }
            }}
          >
            <label>
              Email address
              <input
                name="email"
                type="email"
                autoComplete="username"
                required
                disabled={busy || unavailable}
              />
            </label>
            <div className="password-group">
              <label htmlFor="admin-password">Password</label>
              <div className="password-control">
                <input
                  id="admin-password"
                  ref={passwordInput}
                  name="password"
                  type={showPassword ? "text" : "password"}
                  autoComplete="current-password"
                  required
                  disabled={busy || unavailable}
                />
                <button
                  type="button"
                  className="password-toggle"
                  aria-label={showPassword ? "Hide password" : "Show password"}
                  aria-controls="admin-password"
                  disabled={busy || unavailable}
                  onPointerDown={(event) => {
                    if (document.activeElement === passwordInput.current)
                      event.preventDefault();
                  }}
                  onClick={() => setShowPassword((value) => !value)}
                >
                  <svg
                    width="20"
                    height="20"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.8"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    aria-hidden="true"
                    focusable="false"
                  >
                    {showPassword ? (
                      <path d="m3 3 18 18M10.6 10.6a2 2 0 0 0 2.8 2.8M9.9 5.2A11 11 0 0 1 12 5c6 0 10 7 10 7a18 18 0 0 1-3.1 3.8M6.5 6.5A23 23 0 0 0 2 12s4 7 10 7a12 12 0 0 0 5.5-1.5" />
                    ) : (
                      <>
                        <path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z" />
                        <circle cx="12" cy="12" r="3" />
                      </>
                    )}
                  </svg>
                </button>
              </div>
            </div>
            {unavailable ? (
              <Notice error>
                {session.problem === "configuration"
                  ? "Administrator sign-in is unavailable. Ask your operator to check the web configuration."
                  : "We couldn't check administrator access. Check your connection and try again."}
                <button
                  type="button"
                  onClick={() => {
                    setError("");
                    session.retry();
                  }}
                >
                  Try again
                </button>
                {session.problem === "backend" && (
                  <button
                    type="button"
                    onClick={() =>
                      void session
                        .logout()
                        .catch(() => setError("Could not sign out. Try again."))
                    }
                  >
                    Sign out
                  </button>
                )}
              </Notice>
            ) : error ? (
              <Notice error>{error}</Notice>
            ) : session.problem === "session" ? (
              <Notice error>Please sign in again to continue.</Notice>
            ) : null}
            <button className="primary" disabled={busy || unavailable}>
              {busy ? "Signing in…" : "Sign in securely"}
            </button>
          </form>
        )}
        <p className="muted">
          Administrator access is provisioned by a trusted operator. There is no
          public registration.
        </p>
      </section>
    </main>
  );
}
