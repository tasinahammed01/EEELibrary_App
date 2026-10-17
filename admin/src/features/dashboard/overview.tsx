"use client";
import Link from "next/link";
import { useRecord } from "../../lib/use-record";
import { object } from "../../lib/api";
import { Loading, Notice } from "../../components/feedback";
const labels: Record<string, string> = {
  publishedBooks: "Published books",
  activeUsers: "Active readers",
  pendingPayments: "Pending reviews",
  completedOrders: "Completed orders",
  activeEntitlements: "Available library access",
};
export function Overview() {
  const state = useRecord("/admin/dashboard");
  let metrics: Record<string, unknown> = {};
  let error = state.error;
  try {
    if (state.value) {
      metrics = object(state.value);
      if (
        Object.values(metrics).some(
          (value) =>
            typeof value !== "number" || !Number.isInteger(value) || value < 0,
        )
      )
        error = "Dashboard data is unavailable.";
    }
  } catch {
    error = "Dashboard data is unavailable.";
  }
  return (
    <>
      <div className="page-heading">
        <p className="eyebrow">YOUR WORKSPACE AT A GLANCE</p>
        <h1>Good work starts here.</h1>
        <p>A clear view of the library and the people learning with it.</p>
      </div>
      {state.loading ? (
        <Loading />
      ) : error ? (
        <Notice error>
          {error} <button onClick={state.reload}>Try again</button>
        </Notice>
      ) : (
        <>
          <div className="metrics">
            {Object.entries(metrics).map(([key, value]) => (
              <article className="metric" key={key}>
                <p>{labels[key] || key}</p>
                <strong>{String(value)}</strong>
                <span>Current database total</span>
              </article>
            ))}
          </div>
          <section className="panel welcome-panel">
            <div>
              <p className="eyebrow">MADE FOR CAREFUL DECISIONS</p>
              <h2>Keep learning moving.</h2>
              <p>
                Review each payment against your receiving records. Catalog
                changes and access decisions remain protected by the backend.
              </p>
            </div>
            <Link
              href="/"
              className="gold-mark"
              aria-label="EEELibrary dashboard"
            >
              ▤
            </Link>
          </section>
        </>
      )}
    </>
  );
}
