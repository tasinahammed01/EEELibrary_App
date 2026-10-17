"use client";
import { useEffect, useRef, type ReactNode } from "react";
export function Notice({
  children,
  error = false,
}: {
  children: ReactNode;
  error?: boolean;
}) {
  return (
    <div
      className={"notice " + (error ? "error" : "")}
      role={error ? "alert" : "status"}
      aria-live={error ? "assertive" : "polite"}
    >
      {children}
    </div>
  );
}
export function Loading() {
  return (
    <div role="status" aria-label="Loading records" className="skeleton">
      <span />
      <span />
      <span />
    </div>
  );
}
export function Confirm({
  title,
  children,
  busy,
  error,
  onCancel,
  onConfirm,
}: {
  title: string;
  children: ReactNode;
  busy: boolean;
  error: string;
  onCancel(): void;
  onConfirm(): void;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const element = ref.current;
    const previous = document.activeElement as HTMLElement | null;
    element?.showModal();
    return () => {
      element?.close();
      previous?.focus();
    };
  }, []);
  return (
    <dialog
      ref={ref}
      aria-labelledby="confirmation-title"
      onCancel={(e) => {
        e.preventDefault();
        if (!busy) onCancel();
      }}
    >
      <h2 id="confirmation-title">{title}</h2>
      {children}
      {error && <Notice error>{error}</Notice>}
      <div className="actions">
        <button type="button" onClick={onCancel} disabled={busy}>
          Cancel
        </button>
        <button
          className="primary"
          type="button"
          onClick={onConfirm}
          disabled={busy}
        >
          {busy ? "Saving…" : "Confirm"}
        </button>
      </div>
    </dialog>
  );
}
