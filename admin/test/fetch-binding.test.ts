import { afterEach, describe, expect, it, vi } from "vitest";
import { AdminApi, type Identity } from "../src/lib/api";
const identity: Identity = {
  uid: "binding-fixture",
  getIdToken: async () => "test-only-invalid-token",
};
afterEach(() => vi.unstubAllGlobals());
describe("browser fetch receiver regression", () => {
  it("invokes the default browser transport with its global receiver", async () => {
    let acquired = false;
    const user = {
      ...identity,
      getIdToken: async () => {
        acquired = true;
        return "test-only-invalid-token";
      },
    };
    const transport = vi.fn(function (
      this: unknown,
      input: RequestInfo | URL,
      options?: RequestInit,
    ) {
      if (this !== globalThis) throw new TypeError("Illegal invocation");
      expect(input).toBe("http://127.0.0.1:3000/api/v1/admin/me");
      expect(options).toMatchObject({
        cache: "no-store",
        credentials: "omit",
        redirect: "error",
      });
      return Promise.resolve(new Response(JSON.stringify({ ok: true })));
    });
    vi.stubGlobal("fetch", transport);
    const api = new AdminApi(
      "http://127.0.0.1:3000/api/v1",
      () => user,
      vi.fn(),
    );
    await expect(api.request("/admin/me")).resolves.toEqual({ ok: true });
    expect(acquired).toBe(true);
    expect(transport).toHaveBeenCalledTimes(1);
  });
  it("preserves the native receiver across the single forced-refresh retry", async () => {
    let count = 0;
    const getIdToken = vi.fn<Identity["getIdToken"]>(
      async () => "test-only-invalid-token",
    );
    const transport = function (this: unknown) {
      if (this !== globalThis) throw new TypeError("Illegal invocation");
      return Promise.resolve(
        new Response(JSON.stringify({ ok: true }), {
          status: ++count === 1 ? 401 : 200,
        }),
      );
    };
    const api = new AdminApi(
      "http://127.0.0.1:3000/api/v1",
      () => user,
      vi.fn(),
      transport,
    );
    const user = { uid: "binding-fixture", getIdToken };
    await expect(api.request("/admin/me")).resolves.toEqual({ ok: true });
    expect(getIdToken.mock.calls).toEqual([[false], [true]]);
    expect(count).toBe(2);
  });
});
