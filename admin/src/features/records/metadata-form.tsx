"use client";
import { useEffect, useRef, useState } from "react";
import { useSession } from "../auth/session";
import { object, pageFrom } from "../../lib/api";
import { Confirm, Notice } from "../../components/feedback";
export function MetadataForm({
  kind,
  initial = {},
  onSaved,
}: {
  kind: "books" | "categories";
  initial?: Record<string, unknown>;
  onSaved(): void;
}) {
  const { api } = useSession();
  const [categories, setCategories] = useState<Record<string, unknown>[]>([]),
    [categoryPage, setCategoryPage] = useState(1),
    [selectedCategory, setSelectedCategory] = useState(
      String(initial.categoryId || ""),
    ),
    [more, setMore] = useState(false),
    [categoryError, setCategoryError] = useState(""),
    [categoryRetry, setCategoryRetry] = useState(0),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [confirm, setConfirm] = useState<Record<string, unknown> | null>(null),
    [dirty, setDirty] = useState(false);
  const locked = useRef(false),
    alive = useRef(true);
  const editing = typeof initial.id === "string";
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
    };
  }, []);
  useEffect(() => {
    if (kind !== "books" || !api) return;
    const abort = new AbortController();
    void api
      .request(
        "/admin/categories?page=" + categoryPage + "&pageSize=40",
        "GET",
        undefined,
        abort.signal,
      )
      .then((v) => {
        const p = pageFrom(v);
        setCategories((old) =>
          categoryPage === 1 ? p.items : [...old, ...p.items],
        );
        setMore(p.hasMore);
        setCategoryError("");
      })
      .catch(() => {
        if (!abort.signal.aborted)
          setCategoryError(
            "Categories could not be loaded. Retry before saving.",
          );
      });
    return () => abort.abort();
  }, [api, kind, categoryPage, categoryRetry]);
  useEffect(() => {
    if (!dirty) return;
    const warn = (e: BeforeUnloadEvent) => {
      e.preventDefault();
    };
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [dirty]);
  async function save(data: Record<string, unknown>) {
    if (locked.current || !api) return;
    locked.current = true;
    setBusy(true);
    setError("");
    try {
      object(
        await api.request(
          "/admin/" + kind + (editing ? "/" + initial.id : ""),
          editing ? "PATCH" : "POST",
          data,
        ),
      );
      if (alive.current) {
        setDirty(false);
        setConfirm(null);
        onSaved();
      }
    } catch (e) {
      if (alive.current)
        setError(e instanceof Error ? e.message : "Could not save.");
    } finally {
      locked.current = false;
      if (alive.current) setBusy(false);
    }
  }
  function submit(form: HTMLFormElement) {
    const f = new FormData(form);
    const data: Record<string, unknown> =
      kind === "categories"
        ? {
            name: String(f.get("name")).trim(),
            description: String(f.get("description")),
            sortOrder: Number(f.get("sortOrder")),
            isActive: f.get("isActive") === "on",
          }
        : {
            title: String(f.get("title")).trim(),
            description: String(f.get("description")),
            categoryId: String(f.get("categoryId")),
            price: String(f.get("price")),
            currency: "BDT",
            status: String(f.get("status")),
            ...(f.get("pageCount")
              ? { pageCount: Number(f.get("pageCount")) }
              : {}),
          };
    if (
      kind === "books" &&
      data.status !== initial.status &&
      (data.status === "PUBLISHED" || initial.status === "PUBLISHED")
    )
      setConfirm(data);
    else void save(data);
  }
  return (
    <>
      <h2>
        {editing ? "Edit" : "Create"} {kind === "books" ? "book" : "category"}
      </h2>
      <form
        className="metadata-form"
        onChange={() => setDirty(true)}
        onSubmit={(e) => {
          e.preventDefault();
          submit(e.currentTarget);
        }}
      >
        <fieldset disabled={busy}>
          <label>
            {kind === "books" ? "Title" : "Name"}
            <input
              name={kind === "books" ? "title" : "name"}
              required
              maxLength={kind === "books" ? 240 : 100}
              defaultValue={String(initial.title || initial.name || "")}
            />
          </label>
          <label>
            Description
            <textarea
              name="description"
              required={kind === "books"}
              maxLength={kind === "books" ? 20000 : 4000}
              rows={5}
              defaultValue={String(initial.description || "")}
            />
          </label>
          {kind === "books" ? (
            <>
              <label>
                Category
                <select
                  name="categoryId"
                  required
                  value={selectedCategory}
                  onChange={(event) => setSelectedCategory(event.target.value)}
                >
                  <option value="">Choose a category</option>
                  {!!initial.categoryId &&
                    !categories.some((c) => c.id === initial.categoryId) && (
                      <option value={String(initial.categoryId)}>
                        {String(
                          (
                            initial.category as
                              Record<string, unknown> | undefined
                          )?.name || "Current category",
                        )}
                      </option>
                    )}
                  {categories.map((c) => (
                    <option key={String(c.id)} value={String(c.id)}>
                      {String(c.name)}
                      {c.isActive ? "" : " (inactive)"}
                    </option>
                  ))}
                </select>
              </label>
              {categoryError && (
                <Notice error>
                  {categoryError}{" "}
                  <button
                    type="button"
                    onClick={() => setCategoryRetry((p) => p + 1)}
                  >
                    Retry
                  </button>
                </Notice>
              )}
              {more && (
                <button
                  type="button"
                  onClick={() => setCategoryPage((p) => p + 1)}
                >
                  Load more categories
                </button>
              )}
              <div className="form-row">
                <label>
                  Price (BDT, 0 for free)
                  <input
                    name="price"
                    inputMode="decimal"
                    pattern="(?:0|[1-9][0-9]{0,9})(?:\.[0-9]{1,2})?"
                    required
                    defaultValue={String(initial.price || "0")}
                  />
                </label>
                <label>
                  Page count (optional)
                  <input
                    name="pageCount"
                    type="number"
                    min="1"
                    max="100000"
                    defaultValue={
                      initial.pageCount ? String(initial.pageCount) : ""
                    }
                  />
                </label>
              </div>
              <label>
                Publication status
                <select
                  name="status"
                  defaultValue={String(initial.status || "DRAFT")}
                >
                  {["DRAFT", "PUBLISHED", "ARCHIVED"].map((s) => (
                    <option key={s}>{s}</option>
                  ))}
                </select>
              </label>
              <p className="muted">
                Metadata only. PDF and cover uploads are outside this workflow.
                Slugs are generated on creation and remain stable.
              </p>
            </>
          ) : (
            <>
              <label>
                Sort order
                <input
                  name="sortOrder"
                  type="number"
                  required
                  min="0"
                  max="100000"
                  defaultValue={String(initial.sortOrder || 0)}
                />
              </label>
              <label className="checkbox">
                <input
                  type="checkbox"
                  name="isActive"
                  defaultChecked={initial.isActive !== false}
                />
                Active category
              </label>
              <p className="muted">
                Inactive categories hide their books from the public catalog and
                new purchases.
              </p>
            </>
          )}
        </fieldset>
        {error && !confirm && <Notice error>{error}</Notice>}
        <button className="primary" disabled={busy || !!categoryError}>
          {busy
            ? "Saving…"
            : "Save " + (kind === "books" ? "book" : "category")}
        </button>
      </form>
      {confirm && (
        <Confirm
          title="Confirm publication change"
          busy={busy}
          error={error}
          onCancel={() => setConfirm(null)}
          onConfirm={() => void save(confirm)}
        >
          <p>
            <strong>{String(confirm.title)}</strong>
          </p>
          <p>
            {String(initial.status || "New book")} →{" "}
            <strong>{String(confirm.status)}</strong>. This affects catalog
            visibility and purchase availability.
          </p>
        </Confirm>
      )}
    </>
  );
}
