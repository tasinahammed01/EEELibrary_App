import { describe, it, expect, vi, afterEach } from "vitest";
import {
  AdminApi,
  ApiError,
  adminFrom,
  pageFrom,
  permitted,
  type Identity,
} from "../src/lib/api";
const identity: Identity = {
  uid: "fixture",
  getIdToken: vi.fn(async () => "private-fixture-token"),
};
const response = (status: number, body: unknown = { ok: true }) =>
  new Response(JSON.stringify(body), { status });
afterEach(() => vi.useRealTimers());
describe("protected admin client", () => {
  it("uses SDK bearer token, no-store and no browser credentials", async () => {
    const transport = vi.fn(async () => response(200));
    const api = new AdminApi(
      "http://localhost:3000/api/v1",
      () => identity,
      vi.fn(),
      transport,
    );
    await api.request("/admin/books", "POST", { price: "0" });
    expect(transport).toHaveBeenCalledWith(
      "http://localhost:3000/api/v1/admin/books",
      expect.objectContaining({
        cache: "no-store",
        credentials: "omit",
        redirect: "error",
        body: '{"price":"0"}',
        headers: expect.objectContaining({
          Authorization: "Bearer private-fixture-token",
        }),
      }),
    );
  });
  it("refreshes token once on 401 and succeeds", async () => {
    const transport = vi
      .fn()
      .mockResolvedValueOnce(response(401))
      .mockResolvedValueOnce(response(200));
    const token = vi.fn(async () => "token");
    const api = new AdminApi(
      "http://localhost:3000",
      () => ({}) as Identity,
      vi.fn(),
      transport,
    );
    const user = { uid: "u", getIdToken: token };
    const real = new AdminApi(
      "http://localhost:3000",
      () => user,
      vi.fn(),
      transport,
    );
    await real.request("/admin/me");
    expect(token.mock.calls).toEqual([[false], [true]]);
    expect(api).toBeDefined();
  });
  it.each([401, 403, 409, 503, 400, 404])(
    "maps %i without raw backend data",
    async (status) => {
      const rejected = vi.fn();
      const transport = vi.fn(async () =>
        response(status, { message: "RAW PRIVATE INTERNAL" }),
      );
      const api = new AdminApi(
        "http://localhost:3000",
        () => identity,
        rejected,
        transport,
      );
      await expect(api.request("/admin/me")).rejects.toMatchObject({ status });
      try {
        await api.request("/admin/me");
      } catch (e) {
        expect((e as Error).message).not.toContain("RAW");
      }
      if ([401, 403].includes(status))
        expect(rejected).toHaveBeenCalledWith(status);
    },
  );
  it("does not send after sign out while token is pending", async () => {
    let resolve!: (value: string) => void;
    let current: Identity | null = {
      uid: "x",
      getIdToken: () =>
        new Promise((r) => {
          resolve = r;
        }),
    };
    const transport = vi.fn();
    const api = new AdminApi(
      "http://localhost:3000",
      () => current,
      vi.fn(),
      transport,
    );
    const pending = api.request("/admin/me");
    current = null;
    resolve("token");
    await expect(pending).rejects.toMatchObject({ name: "AbortError" });
    expect(transport).not.toHaveBeenCalled();
  });
  it("ignores response after account changes", async () => {
    let current: Identity | null = identity,
      resolve!: (value: Response) => void;
    const transport = vi.fn(
      () =>
        new Promise<Response>((r) => {
          resolve = r;
        }),
    );
    const api = new AdminApi(
      "http://localhost:3000",
      () => current,
      vi.fn(),
      transport,
    );
    const p = api.request("/admin/me");
    await vi.waitFor(() => expect(transport).toHaveBeenCalledTimes(1));
    current = { uid: "other", getIdToken: async () => "" };
    resolve(response(200));
    await expect(p).rejects.toMatchObject({ name: "AbortError" });
  });
  it("maps offline failures safely", async () => {
    const api = new AdminApi(
      "http://localhost:3000",
      () => identity,
      vi.fn(),
      vi.fn(async () => {
        throw new Error("private");
      }),
    );
    await expect(api.request("/admin/me")).rejects.toEqual(new ApiError(503));
  });
  it("bounds a stalled SDK token request", async () => {
    vi.useFakeTimers();
    const user: Identity = {
      uid: "x",
      getIdToken: () => new Promise(() => {}),
    };
    const transport = vi.fn();
    const api = new AdminApi(
      "http://localhost:3000",
      () => user,
      vi.fn(),
      transport,
    );
    const result = api.request("/admin/me").catch((error) => error as ApiError);
    await vi.advanceTimersByTimeAsync(15000);
    expect(await result).toMatchObject({ status: 503 });
    expect(transport).not.toHaveBeenCalled();
  });
  it("rejects malformed JSON", async () => {
    const api = new AdminApi(
      "http://localhost:3000",
      () => identity,
      vi.fn(),
      vi.fn(async () => new Response("<html>")),
    );
    await expect(api.request("/admin/me")).rejects.toMatchObject({
      status: 503,
    });
  });
  it("validates response shapes", () => {
    expect(() => adminFrom({ role: "SUPER_ADMIN" })).toThrow();
    expect(() => pageFrom({ items: "bad" })).toThrow();
  });
  it("fails closed for insecure nonlocal backend config", () => {
    expect(
      () => new AdminApi("http://api.example.com", () => identity, vi.fn()),
    ).toThrow();
  });
  it("guest cannot send requests", async () => {
    const transport = vi.fn();
    const api = new AdminApi(
      "http://localhost:3000",
      () => null,
      vi.fn(),
      transport,
    );
    await expect(api.request("/admin/me")).rejects.toMatchObject({
      status: 401,
    });
    expect(transport).not.toHaveBeenCalled();
  });
  it.each([
    "books",
    "categories",
    "payments",
    "orders",
    "users",
    "entitlements",
    "audit",
  ])("role matrix %s", (section) => {
    expect(permitted("SUPER_ADMIN", section)).toBe(true);
    expect(permitted("CONTENT_MANAGER", section)).toBe(
      ["books", "categories"].includes(section),
    );
    expect(permitted("PAYMENT_REVIEWER", section)).toBe(
      ["payments", "orders"].includes(section),
    );
  });
});
