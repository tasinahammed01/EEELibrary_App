import React from "react";
import { describe, it, expect, vi, afterEach } from "vitest";
import { render, screen, waitFor, act } from "@testing-library/react";
import {
  SessionProvider,
  useSession,
  type Gateway,
} from "../src/features/auth/session";
import type { Identity } from "../src/lib/api";
vi.mock("../src/features/auth/firebase", () => ({
  configured: false,
  firebaseGateway: {},
  isFirebaseConfigurationError: (error: unknown) =>
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    error.code === "auth/invalid-api-key",
}));
const identity: Identity = {
  uid: "fixture",
  getIdToken: async () => "controlled-token",
};
const admin = {
  id: "admin-id",
  role: "SUPER_ADMIN",
  status: "ACTIVE",
  email: "admin@example.test",
  displayName: "Operator",
};
function Probe() {
  const s = useSession();
  return (
    <>
      <span data-testid="state">{s.state}</span>
      <span>{s.admin?.displayName}</span>
      <button onClick={() => void s.logout()}>Sign out</button>
    </>
  );
}
function setup() {
  let listener: (identity: Identity | null) => void = () => {};
  const gateway: Gateway = {
    subscribe: vi.fn((next) => {
      listener = next;
      return vi.fn();
    }),
    login: vi.fn(),
    logout: vi.fn(async () => {}),
  };
  return {
    gateway,
    emit: (user: Identity | null) => act(() => listener(user)),
  };
}
afterEach(() => vi.unstubAllGlobals());
describe("authoritative admin bootstrap", () => {
  it("starts at guest with Firebase signed out", () => {
    const f = setup();
    render(
      <SessionProvider gateway={f.gateway} enabled>
        <Probe />
      </SessionProvider>,
    );
    f.emit(null);
    expect(screen.getByTestId("state")).toHaveTextContent("guest");
  });
  it("enters only after backend confirms persisted admin", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response(JSON.stringify(admin))),
    );
    const f = setup();
    render(
      <SessionProvider gateway={f.gateway} enabled>
        <Probe />
      </SessionProvider>,
    );
    f.emit(identity);
    expect(await screen.findByText("Operator")).toBeInTheDocument();
    expect(screen.getByTestId("state")).toHaveTextContent("ready");
  });
  it("ordinary user gets safe denial", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response("{}", { status: 403 })),
    );
    const f = setup();
    render(
      <SessionProvider gateway={f.gateway} enabled>
        <Probe />
      </SessionProvider>,
    );
    f.emit(identity);
    await waitFor(() =>
      expect(screen.getByTestId("state")).toHaveTextContent("denied"),
    );
  });
  it("persistent 401 returns to sign in after one refresh", async () => {
    const fetcher = vi.fn(async () => new Response("{}", { status: 401 }));
    vi.stubGlobal("fetch", fetcher);
    const f = setup();
    render(
      <SessionProvider gateway={f.gateway} enabled>
        <Probe />
      </SessionProvider>,
    );
    f.emit(identity);
    await waitFor(() =>
      expect(screen.getByTestId("state")).toHaveTextContent("guest"),
    );
    expect(fetcher).toHaveBeenCalledTimes(2);
  });
  it("malformed admin payload fails closed", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response('{"role":"SUPER_ADMIN"}')),
    );
    const f = setup();
    render(
      <SessionProvider gateway={f.gateway} enabled>
        <Probe />
      </SessionProvider>,
    );
    f.emit(identity);
    await waitFor(() =>
      expect(screen.getByTestId("state")).toHaveTextContent("error"),
    );
  });
  it("missing Firebase configuration does not authenticate", () => {
    const f = setup();
    render(
      <SessionProvider gateway={f.gateway} enabled={false}>
        <Probe />
      </SessionProvider>,
    );
    expect(screen.getByTestId("state")).toHaveTextContent("error");
    expect(f.gateway.subscribe).not.toHaveBeenCalled();
  });
  it("sign out invalidates pending bootstrap before SDK completion", async () => {
    let resolve!: (r: Response) => void;
    vi.stubGlobal(
      "fetch",
      vi.fn(
        () =>
          new Promise<Response>((r) => {
            resolve = r;
          }),
      ),
    );
    const f = setup();
    render(
      <SessionProvider gateway={f.gateway} enabled>
        <Probe />
      </SessionProvider>,
    );
    f.emit(identity);
    await act(async () => {
      await Promise.resolve();
    });
    await act(async () => screen.getByRole("button").click());
    await act(async () => resolve(new Response(JSON.stringify(admin))));
    expect(screen.getByTestId("state")).toHaveTextContent("guest");
    expect(screen.queryByText("Operator")).not.toBeInTheDocument();
  });
  it("ignores old account bootstrap response after account switches", async () => {
    let resolve!: (r: Response) => void;
    vi.stubGlobal(
      "fetch",
      vi.fn(
        () =>
          new Promise<Response>((r) => {
            resolve = r;
          }),
      ),
    );
    const f = setup();
    render(
      <SessionProvider gateway={f.gateway} enabled>
        <Probe />
      </SessionProvider>,
    );
    f.emit(identity);
    await act(async () => {
      await Promise.resolve();
    });
    f.emit(null);
    await act(async () => resolve(new Response(JSON.stringify(admin))));
    expect(screen.getByTestId("state")).toHaveTextContent("guest");
  });
});
