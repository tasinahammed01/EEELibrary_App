"use client";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { object, pageFrom, type Page } from "../../lib/api";
import { useRecord } from "../../lib/use-record";
import { useSession } from "../auth/session";
import { Confirm, Loading, Notice } from "../../components/feedback";
import { MetadataForm } from "./metadata-form";
export const rejectionReasons = {
  REFERENCE_NOT_FOUND: "Transaction reference not found",
  AMOUNT_MISMATCH: "Amount does not match",
  METHOD_MISMATCH: "Payment method does not match",
};
export function text(value: unknown): string {
  return value === null || value === undefined ? "—" : String(value);
}
function nested(row: Record<string, unknown>, key: string, field: string) {
  const value = row[key];
  return value && typeof value === "object"
    ? text((value as Record<string, unknown>)[field])
    : "—";
}
function paymentContext(row: Record<string, unknown>) {
  const order = row.order as Record<string, unknown> | undefined;
  return order ? (
    <>
      {nested(order, "book", "title")}
      <br />
      Order: {text(order.id)}
    </>
  ) : (
    text(row.id)
  );
}
function paymentTitle(row: Record<string, unknown>) {
  const order = row.order as Record<string, unknown> | undefined;
  return order && order.book
    ? nested(order, "book", "title")
    : "Payment review";
}
function time(value: unknown) {
  return typeof value === "string" ? new Date(value).toLocaleString() : "—";
}
export function Chip({ value }: { value: unknown }) {
  return (
    <span
      className={
        "chip " +
        (["PENDING", "PAYMENT_SUBMITTED"].includes(String(value))
          ? "pending"
          : ["ACTIVE", "APPROVED", "COMPLETED", "PUBLISHED"].includes(
                String(value),
              )
            ? "positive"
            : "neutral")
      }
    >
      {text(value).replaceAll("_", " ")}
    </span>
  );
}
const filters: Record<string, string[]> = {
  payments: ["PENDING", "APPROVED", "REJECTED"],
  books: ["DRAFT", "PUBLISHED", "ARCHIVED"],
  users: ["ACTIVE", "SUSPENDED", "DISABLED"],
  orders: ["PENDING_PAYMENT", "PAYMENT_SUBMITTED", "COMPLETED", "CANCELLED"],
  entitlements: ["ACTIVE", "REVOKED"],
};
export function Records({ kind }: { kind: string }) {
  const [page, setPage] = useState(1),
    [status, setStatus] = useState(kind === "payments" ? "PENDING" : ""),
    [search, setSearch] = useState(""),
    [query, setQuery] = useState(""),
    [edit, setEdit] = useState<Record<string, unknown> | null>(null);
  const { admin } = useSession();
  useEffect(() => {
    const t = setTimeout(() => {
      setQuery(search.trim());
      setPage(1);
    }, 300);
    return () => clearTimeout(t);
  }, [search]);
  const state = useRecord(
    "/admin/" +
      kind +
      "?page=" +
      page +
      "&pageSize=12" +
      (status ? "&status=" + status : "") +
      (query ? "&search=" + encodeURIComponent(query) : ""),
  );
  let result: Page | null = null,
    error = state.error;
  try {
    if (state.value) result = pageFrom(state.value);
  } catch {
    error = "The service returned an unexpected response.";
  }
  const canEdit =
    ["books", "categories"].includes(kind) &&
    admin &&
    ["SUPER_ADMIN", "CONTENT_MANAGER"].includes(admin.role);
  return (
    <>
      <div className="page-heading heading-row">
        <div>
          <p className="eyebrow">EEELIBRARY ADMINISTRATION</p>
          <h1>
            {kind === "audit"
              ? "Audit log"
              : kind[0].toUpperCase() + kind.slice(1)}
          </h1>
          <p>
            {kind === "payments"
              ? "Review receiving records carefully before granting access."
              : kind === "audit"
                ? "An immutable history of administrator actions."
                : "Live records, protected by backend permissions."}
          </p>
        </div>
        {canEdit && (
          <Link className="button primary" href={"/" + kind + "/new"}>
            Add {kind === "books" ? "book" : "category"}
          </Link>
        )}
      </div>
      <section className="panel">
        <div className="toolbar">
          {filters[kind] && (
            <label>
              Status
              <select
                value={status}
                onChange={(e) => {
                  setStatus(e.target.value);
                  setPage(1);
                }}
              >
                <option value="">All statuses</option>
                {filters[kind].map((s) => (
                  <option key={s}>{s}</option>
                ))}
              </select>
            </label>
          )}
          {["books", "categories", "users"].includes(kind) && (
            <label>
              Search by {kind === "books" ? "title" : "name"}
              <input
                type="search"
                maxLength={100}
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search records…"
              />
            </label>
          )}
          <button onClick={state.reload}>Refresh</button>
        </div>
        {state.loading ? (
          <Loading />
        ) : error ? (
          <Notice error>
            {error} <button onClick={state.reload}>Try again</button>
          </Notice>
        ) : result?.items.length ? (
          <>
            <div
              className="table-scroll"
              tabIndex={0}
              role="region"
              aria-label={kind + " table"}
            >
              <table>
                <thead>
                  <tr>
                    <th>
                      {kind === "books"
                        ? "Book"
                        : kind === "categories"
                          ? "Category"
                          : kind === "users"
                            ? "Reader"
                            : kind === "audit"
                              ? "Action"
                              : "Record"}
                    </th>
                    <th>
                      {kind === "payments"
                        ? "Method / amount"
                        : kind === "audit"
                          ? "Target"
                          : "Status / context"}
                    </th>
                    <th>Created</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {result.items.map((row) => (
                    <tr key={text(row.id)}>
                      <td>
                        <strong>
                          {text(
                            row.title ||
                              row.name ||
                              row.displayName ||
                              row.action ||
                              (kind === "payments"
                                ? paymentTitle(row)
                                : row.id),
                          )}
                        </strong>
                        {kind === "payments" && (
                          <small>
                            Payment: {text(row.id)}
                            <br />
                            Order: {nested(row, "order", "id")}
                          </small>
                        )}
                        {kind === "audit" && (
                          <small>
                            {nested(row, "adminActor", "displayName")}
                          </small>
                        )}
                        {kind === "orders" && (
                          <small>
                            {nested(row, "book", "title")} ·{" "}
                            {nested(row, "user", "displayName")}
                          </small>
                        )}
                        {kind === "entitlements" && (
                          <small>
                            {nested(row, "book", "title")} ·{" "}
                            {nested(row, "user", "displayName")}
                          </small>
                        )}
                      </td>
                      <td>
                        {kind === "payments" ? (
                          <>
                            <Chip value={row.status} />
                            <small>
                              {text(row.method)} · {text(row.currency)}{" "}
                              {text(row.amount)}
                            </small>
                          </>
                        ) : kind === "audit" ? (
                          <>
                            {text(row.targetType)}
                            <small>{text(row.targetId)}</small>
                          </>
                        ) : kind === "categories" ? (
                          <Chip value={row.isActive ? "ACTIVE" : "INACTIVE"} />
                        ) : (
                          <>
                            <Chip value={row.status} />
                            {["books", "orders"].includes(kind) && (
                              <small>
                                {text(row.currency)}{" "}
                                {text(
                                  kind === "books" ? row.price : row.amount,
                                )}{" "}
                                · {nested(row, "category", "name")}
                              </small>
                            )}
                          </>
                        )}
                      </td>
                      <td>{time(row.createdAt)}</td>
                      <td>
                        {kind === "audit" ? (
                          <span className="muted">Read only</span>
                        ) : kind === "categories" ? (
                          <button onClick={() => setEdit(row)}>Edit</button>
                        ) : (
                          <Link href={"/" + kind + "/" + text(row.id)}>
                            View {kind === "books" ? " / edit" : ""}
                          </Link>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="pagination">
              <span>
                {result.total} records · Page {page}
              </span>
              <button
                disabled={page === 1}
                onClick={() => setPage((p) => p - 1)}
              >
                Previous
              </button>
              <button
                disabled={!result.hasMore}
                onClick={() => setPage((p) => p + 1)}
              >
                Next
              </button>
            </div>
          </>
        ) : (
          <div className="empty">
            <h2>No records to show</h2>
            <p>Try a different filter or return later.</p>
          </div>
        )}
      </section>
      {edit && (
        <section className="panel">
          <MetadataForm
            key={String(edit.id)}
            kind="categories"
            initial={edit}
            onSaved={() => {
              setEdit(null);
              state.reload();
            }}
          />
          <button onClick={() => setEdit(null)}>Close editor</button>
        </section>
      )}
    </>
  );
}
export function Detail({ kind, id }: { kind: string; id: string }) {
  const state = useRecord("/admin/" + kind + "/" + id);
  const { api, admin } = useSession();
  const [action, setAction] = useState(""),
    [reason, setReason] = useState("REFERENCE_NOT_FOUND"),
    [userStatus, setUserStatus] = useState("DISABLED"),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [success, setSuccess] = useState("");
  const locked = useRef(false),
    alive = useRef(true);
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
    };
  }, []);
  if (state.loading) return <Loading />;
  if (state.error)
    return (
      <Notice error>
        {state.error} <button onClick={state.reload}>Try again</button>
      </Notice>
    );
  let row: Record<string, unknown>;
  try {
    row = object(state.value);
  } catch {
    return <Notice error>Record unavailable.</Notice>;
  }
  async function submit() {
    if (locked.current || !api) return;
    locked.current = true;
    setBusy(true);
    setError("");
    try {
      await api.request(
        "/admin/" +
          kind +
          "/" +
          id +
          (kind === "payments" ? "/" + action : "/status"),
        kind === "payments" ? "POST" : "PATCH",
        kind === "payments"
          ? action === "reject"
            ? { reason }
            : {}
          : { status: userStatus },
      );
      if (alive.current) {
        setAction("");
        setSuccess("Change confirmed by EEELibrary.");
        state.reload();
      }
    } catch (e) {
      if (alive.current)
        setError(e instanceof Error ? e.message : "Could not save.");
    } finally {
      locked.current = false;
      if (alive.current) setBusy(false);
    }
  }
  return (
    <>
      <Link href={"/" + kind}>← Back to {kind}</Link>
      <div className="page-heading">
        <p className="eyebrow">RECORD DETAILS</p>
        <h1>
          {text(
            row.title ||
              row.displayName ||
              (
                {
                  payments: "Payment review",
                  orders: "Order details",
                  entitlements: "Entitlement details",
                } as Record<string, string>
              )[kind] ||
              "Record details",
          )}
        </h1>
        <p className="record-id">{id}</p>
      </div>
      {success && <Notice>{success}</Notice>}
      {kind === "books" ? (
        <section className="panel">
          <MetadataForm
            kind="books"
            initial={row}
            onSaved={() => {
              setSuccess("Book saved.");
              state.reload();
            }}
          />
        </section>
      ) : (
        <section className="panel">
          {kind === "orders" && Array.isArray(row.payments) && (
            <div className="actions">
              <span>Latest payment</span>
              {row.payments.map((value, index) => (
                <Chip key={index} value={object(value).status} />
              ))}
            </div>
          )}
          <dl className="details">
            {Object.entries(row)
              .filter(([key]) => !["payments", "category"].includes(key))
              .map(([key, value]) => (
                <div key={key}>
                  <dt>{key.replace(/([A-Z])/g, " $1")}</dt>
                  <dd>
                    {key.endsWith("At") ? (
                      time(value)
                    ) : key === "rejectionReason" &&
                      typeof value === "string" &&
                      value in rejectionReasons ? (
                      rejectionReasons[value as keyof typeof rejectionReasons]
                    ) : key === "order" ? (
                      paymentContext(row)
                    ) : ["status"].includes(key) ? (
                      <Chip value={value} />
                    ) : typeof value === "object" && value ? (
                      text(
                        (value as Record<string, unknown>).title ||
                          (value as Record<string, unknown>).displayName ||
                          (value as Record<string, unknown>).id,
                      )
                    ) : (
                      text(value)
                    )}
                  </dd>
                </div>
              ))}
          </dl>
          {kind === "payments" && row.status === "PENDING" && (
            <div className="actions">
              <button
                className="primary"
                onClick={() => {
                  setError("");
                  setAction("approve");
                }}
              >
                Approve payment
              </button>
              <button
                onClick={() => {
                  setError("");
                  setAction("reject");
                }}
              >
                Reject payment
              </button>
            </div>
          )}
          {kind === "users" && admin?.role === "SUPER_ADMIN" && (
            <div className="actions">
              <label>
                New account status
                <select
                  value={userStatus}
                  onChange={(e) => setUserStatus(e.target.value)}
                >
                  {["ACTIVE", "DISABLED", "SUSPENDED"].map((s) => (
                    <option key={s}>{s}</option>
                  ))}
                </select>
              </label>
              <button
                onClick={() => {
                  setError("");
                  setAction("status");
                }}
                disabled={row.status === userStatus}
              >
                Change status
              </button>
            </div>
          )}
          <button onClick={state.reload}>Refresh record</button>
        </section>
      )}
      {action && (
        <Confirm
          title={
            action === "approve"
              ? "Approve this payment?"
              : action === "reject"
                ? "Reject this payment?"
                : "Change reader account status?"
          }
          busy={busy}
          error={error}
          onCancel={() => setAction("")}
          onConfirm={() => void submit()}
        >
          <p>
            Record: <strong className="record-id">{id}</strong>
          </p>
          {kind === "payments" ? (
            <>
              <p>
                {text(row.currency)} {text(row.amount)} · {text(row.method)}
                <br />
                Reference: <strong>{text(row.transactionReference)}</strong>
              </p>
              {action === "approve" ? (
                <p>
                  Confirm you have verified receipt. Approval grants library
                  access through the backend.
                </p>
              ) : (
                <label>
                  Rejection reason
                  <select
                    value={reason}
                    onChange={(e) => setReason(e.target.value)}
                  >
                    {Object.entries(rejectionReasons).map(([code, label]) => (
                      <option key={code} value={code}>
                        {label}
                      </option>
                    ))}
                  </select>
                </label>
              )}
            </>
          ) : (
            <p>
              {text(row.displayName)}:{" "}
              <strong>
                {text(row.status)} → {userStatus}
              </strong>
              . The backend will enforce this account status.
            </p>
          )}
        </Confirm>
      )}
    </>
  );
}
