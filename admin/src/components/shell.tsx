"use client";
import Link from "next/link";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { sections, permitted } from "../lib/api";
import { useSession } from "../features/auth/session";
import { Notice } from "./feedback";
export function Shell({
  section,
  children,
}: {
  section: string;
  children: ReactNode;
}) {
  const { admin, logout } = useSession();
  const [open, setOpen] = useState(false),
    [error, setError] = useState("");
  const menu = useRef<HTMLButtonElement>(null);
  const navigation = useRef<HTMLElement>(null);
  useEffect(() => {
    if (!open) return;
    navigation.current?.querySelector<HTMLAnchorElement>("a")?.focus();
    const escape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setOpen(false);
        menu.current?.focus();
      }
    };
    document.addEventListener("keydown", escape);
    return () => document.removeEventListener("keydown", escape);
  }, [open]);
  if (!admin) return null;
  return (
    <div className="workspace">
      <aside className={open ? "sidebar open" : "sidebar"}>
        <Link href="/" className="brand" onClick={() => setOpen(false)}>
          ▤ EEELibrary <span>ADMIN</span>
        </Link>
        <p className="nav-label">WORKSPACE</p>
        <nav ref={navigation} id="admin-navigation" aria-label="Administration">
          {sections
            .filter(([key]) => permitted(admin.role, key))
            .map(([key, label]) => (
              <Link
                key={key}
                href={"/" + key}
                aria-current={section === key ? "page" : undefined}
                onClick={() => setOpen(false)}
              >
                {label}
              </Link>
            ))}
        </nav>
        <p className="sidebar-foot">
          A better place to learn.
          <br />A secure place to manage.
        </p>
      </aside>
      <div className="workspace-main">
        <header>
          <button
            ref={menu}
            aria-controls="admin-navigation"
            aria-label="Toggle navigation"
            aria-expanded={open}
            className="menu"
            onClick={() => setOpen(!open)}
          >
            ☰
          </button>
          <span className="header-section">
            {sections.find(([key]) => key === section)?.[1] || "Workspace"}
          </span>
          <div className="identity">
            <strong>{admin.displayName}</strong>
            <span>{admin.role.replaceAll("_", " ").toLowerCase()}</span>
          </div>
          <button
            onClick={() =>
              void logout().catch(() =>
                setError("Sign out could not complete. Try again."),
              )
            }
          >
            Sign out
          </button>
        </header>
        <main id="main-content">
          {error && <Notice error>{error}</Notice>}
          {children}
        </main>
      </div>
    </div>
  );
}
