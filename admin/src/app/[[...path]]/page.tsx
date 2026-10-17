"use client";
import { usePathname, useRouter } from "next/navigation";
import { useEffect } from "react";
import { useSession } from "../../features/auth/session";
import { Login } from "../../features/auth/login";
import { Shell } from "../../components/shell";
import { Notice } from "../../components/feedback";
import { Overview } from "../../features/dashboard/overview";
import { Records, Detail } from "../../features/records/records";
import { MetadataForm } from "../../features/records/metadata-form";
import { permitted, sections } from "../../lib/api";
export default function Page() {
  const { state, admin } = useSession();
  const path = usePathname();
  const router = useRouter();
  const [section = "", id] = path.split("/").filter(Boolean);
  useEffect(() => {
    if (state === "ready" && path === "/login") router.replace("/");
    else if (state === "guest" && path !== "/login") router.replace("/login");
  }, [state, path, router]);
  if (state !== "ready" || !admin) return <Login />;
  if (!permitted(admin.role, section))
    return (
      <Shell section={section}>
        <Notice error>You do not have access to this section.</Notice>
      </Shell>
    );
  const content = !section ? (
    <Overview />
  ) : id === "new" && ["books", "categories"].includes(section) ? (
    <section className="panel">
      <MetadataForm
        kind={section as "books" | "categories"}
        onSaved={() => router.push("/" + section)}
      />
    </section>
  ) : id &&
    ["payments", "books", "users", "orders", "entitlements"].includes(
      section,
    ) ? (
    <Detail key={path} kind={section} id={id} />
  ) : sections.some(([key]) => key === section) ? (
    <Records key={section} kind={section} />
  ) : (
    <Notice error>This page is unavailable.</Notice>
  );
  return <Shell section={section}>{content}</Shell>;
}
