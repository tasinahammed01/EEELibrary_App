export type Role = "SUPER_ADMIN" | "CONTENT_MANAGER" | "PAYMENT_REVIEWER";
export interface Admin {
  id: string;
  role: Role;
  status: "ACTIVE";
  displayName: string;
  email: string;
}
export interface Identity {
  uid: string;
  getIdToken(force?: boolean): Promise<string>;
}
export class ApiError extends Error {
  constructor(public status: number) {
    super(
      status === 401
        ? "Please sign in again."
        : status === 403
          ? "You do not have access to this section."
          : status === 409
            ? "This record changed or conflicts with an existing record. Refresh and try again."
            : status === 400
              ? "Check the form values and try again."
              : status === 404
                ? "This record is unavailable."
                : "We could not connect to EEELibrary. Please try again.",
    );
  }
}
export function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw new ApiError(503);
  return value as Record<string, unknown>;
}
export function adminFrom(value: unknown): Admin {
  const a = object(value);
  if (
    typeof a.id !== "string" ||
    typeof a.displayName !== "string" ||
    typeof a.email !== "string" ||
    a.status !== "ACTIVE" ||
    !["SUPER_ADMIN", "CONTENT_MANAGER", "PAYMENT_REVIEWER"].includes(
      String(a.role),
    )
  )
    throw new ApiError(503);
  return a as unknown as Admin;
}
export interface Page {
  items: Record<string, unknown>[];
  page: number;
  pageSize: number;
  total: number;
  hasMore: boolean;
}
export function pageFrom(value: unknown): Page {
  const p = object(value);
  if (
    !Array.isArray(p.items) ||
    !Number.isInteger(p.page) ||
    !Number.isInteger(p.total) ||
    typeof p.hasMore !== "boolean" ||
    !Number.isInteger(p.pageSize) ||
    Number(p.pageSize) < 1 ||
    Number(p.pageSize) > 40 ||
    Number(p.total) < 0 ||
    p.items.length > 40
  )
    throw new ApiError(503);
  return { ...p, items: p.items.map(object) } as unknown as Page;
}
export class AdminApi {
  constructor(
    private base: string,
    private current: () => Identity | null,
    private rejected: (status: number) => void,
    private transport: typeof fetch = fetch,
  ) {
    const u = new URL(base);
    if (
      !["http:", "https:"].includes(u.protocol) ||
      u.username ||
      u.password ||
      u.search ||
      u.hash ||
      (u.protocol !== "https:" &&
        !["127.0.0.1", "localhost"].includes(u.hostname))
    )
      throw new Error("Invalid API configuration");
    this.base = base.replace(/\/$/, "");
  }
  async request(
    path: string,
    method = "GET",
    body?: unknown,
    signal?: AbortSignal,
  ): Promise<unknown> {
    if (!/^\/[a-z0-9/?=&_%+.-]+$/i.test(path)) throw new ApiError(400);
    const identity = this.current();
    if (!identity) throw new ApiError(401);
    const same = () => {
      if (this.current() !== identity || signal?.aborted)
        throw new DOMException("Request superseded", "AbortError");
    };
    const controller = new AbortController();
    const abort = () => controller.abort();
    signal?.addEventListener("abort", abort);
    const timeout = setTimeout(abort, 15000);
    try {
      for (let attempt = 0; attempt < 2; attempt++) {
        same();
        const token = await new Promise<string>((resolve, reject) => {
          const abortToken = () => reject(new ApiError(503));
          if (controller.signal.aborted) {
            abortToken();
            return;
          }
          controller.signal.addEventListener("abort", abortToken, {
            once: true,
          });
          identity.getIdToken(attempt === 1).then(
            (value) => {
              controller.signal.removeEventListener("abort", abortToken);
              resolve(value);
            },
            (error) => {
              controller.signal.removeEventListener("abort", abortToken);
              reject(error);
            },
          );
        });
        same();
        const response = await this.transport.call(
          globalThis,
          this.base + path,
          {
            method,
            body: body === undefined ? undefined : JSON.stringify(body),
            headers: {
              Authorization: "Bearer " + token,
              Accept: "application/json",
              ...(body === undefined
                ? {}
                : { "Content-Type": "application/json" }),
            },
            cache: "no-store",
            credentials: "omit",
            redirect: "error",
            signal: controller.signal,
          },
        );
        same();
        if (response.status === 401 && attempt === 0) continue;
        if (!response.ok) {
          if (response.status === 401 || response.status === 403)
            this.rejected(response.status);
          throw new ApiError(response.status);
        }
        const text = await response.text();
        same();
        if (text.length > 512000) throw new ApiError(503);
        try {
          return JSON.parse(text) as unknown;
        } catch {
          throw new ApiError(503);
        }
      }
      throw new ApiError(401);
    } catch (error) {
      same();
      if (error instanceof ApiError) throw error;
      throw new ApiError(503);
    } finally {
      clearTimeout(timeout);
      signal?.removeEventListener("abort", abort);
    }
  }
}
export const sections = [
  ["", "Dashboard"],
  ["payments", "Payments"],
  ["books", "Books"],
  ["categories", "Categories"],
  ["users", "Users"],
  ["orders", "Orders"],
  ["entitlements", "Entitlements"],
  ["audit", "Audit Log"],
] as const;
export function permitted(role: Role, section: string) {
  return (
    role === "SUPER_ADMIN" ||
    section === "" ||
    (role === "CONTENT_MANAGER"
      ? ["books", "categories"].includes(section)
      : ["payments", "orders"].includes(section))
  );
}
