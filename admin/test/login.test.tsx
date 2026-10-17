import React from "react";
import { describe, it, expect, vi, afterEach } from "vitest";
import { render, screen, waitFor, act } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Login } from "../src/features/auth/login";
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
const token = vi.fn<Identity["getIdToken"]>(async () => "controlled-fixture");
const identity: Identity = { uid: "fixture", getIdToken: token };
const admin = {
  id: "id",
  role: "SUPER_ADMIN",
  status: "ACTIVE",
  displayName: "Operator",
  email: "admin@example.test",
};
function View() {
  const session = useSession();
  return session.state === "ready" ? <p>Authorized dashboard</p> : <Login />;
}
function setup({ enabled = true, base = "http://127.0.0.1:3000/api/v1" } = {}) {
  let next: (identity: Identity | null) => void = () => {};
  let current: Identity | null = null;
  const gateway: Gateway = {
    subscribe: vi.fn((observer) => {
      next = observer;
      observer(current);
      return vi.fn();
    }),
    login: vi.fn(async () => {
      current = identity;
      next(identity);
    }),
    logout: vi.fn(async () => {
      current = null;
      next(null);
    }),
  };
  const result = render(
    <SessionProvider gateway={gateway} enabled={enabled} base={base}>
      <View />
    </SessionProvider>,
  );
  return { gateway, ...result };
}
async function submit() {
  await userEvent.type(
    screen.getByLabelText("Email address"),
    "admin@example.test",
  );
  await userEvent.type(
    screen.getByLabelText("Password"),
    "private-fixture-password",
  );
  await userEvent.click(
    screen.getByRole("button", { name: "Sign in securely" }),
  );
}
afterEach(() => {
  vi.unstubAllGlobals();
  token.mockClear();
});
describe("admin login feedback and password accessibility", () => {
  it("hides by default and preserves the typed password through both toggles", async () => {
    setup();
    const field = screen.getByLabelText("Password");
    expect(field).toHaveAttribute("type", "password");
    await userEvent.type(field, "private-fixture");
    await userEvent.click(
      screen.getByRole("button", { name: "Show password" }),
    );
    expect(field).toHaveAttribute("type", "text");
    expect(field).toHaveValue("private-fixture");
    await userEvent.click(
      screen.getByRole("button", { name: "Hide password" }),
    );
    expect(field).toHaveAttribute("type", "password");
    expect(field).toHaveValue("private-fixture");
  });
  it("supports Tab, Enter and Space without submitting the form", async () => {
    const f = setup();
    const field = screen.getByLabelText("Password");
    field.focus();
    await userEvent.tab();
    const toggle = screen.getByRole("button", { name: "Show password" });
    expect(toggle).toHaveFocus();
    expect(toggle).toHaveAttribute("type", "button");
    await userEvent.keyboard("{Enter}");
    expect(screen.getByRole("button", { name: "Hide password" })).toHaveFocus();
    await userEvent.keyboard(" ");
    expect(field).toHaveAttribute("type", "password");
    expect(f.gateway.login).not.toHaveBeenCalled();
  });
  it("pointer activation preserves an already focused password field", async () => {
    setup();
    const field = screen.getByLabelText("Password");
    await userEvent.type(field, "private");
    await userEvent.click(
      screen.getByRole("button", { name: "Show password" }),
    );
    expect(field).toHaveFocus();
  });
  it("Firebase credential failure shows one alert without checking admin access", async () => {
    const fetcher = vi.fn();
    vi.stubGlobal("fetch", fetcher);
    const f = setup();
    vi.mocked(f.gateway.login).mockRejectedValue({
      code: "auth/invalid-credential",
      message: "RAW SECRET",
    });
    await submit();
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Unable to sign in",
    );
    expect(screen.getAllByRole("alert")).toHaveLength(1);
    expect(
      screen.queryByText(/couldn.t check administrator access/i),
    ).not.toBeInTheDocument();
    expect(screen.queryByText(/RAW SECRET/)).not.toBeInTheDocument();
    expect(fetcher).not.toHaveBeenCalled();
  });
  it("backend denial is only shown after Firebase succeeds", async () => {
    const fetcher = vi.fn(async () => new Response("{}", { status: 403 }));
    vi.stubGlobal("fetch", fetcher);
    setup();
    expect(fetcher).not.toHaveBeenCalled();
    await submit();
    expect(
      await screen.findByRole("heading", { name: "Access denied" }),
    ).toBeVisible();
    expect(screen.getAllByRole("alert")).toHaveLength(1);
    expect(screen.getByRole("alert")).toHaveTextContent(
      "does not have active administrator access",
    );
    expect(screen.queryByText(/Unable to sign in/)).not.toBeInTheDocument();
  });
  it.each(["network", "503"])(
    "backend %s shows one temporary error and Retry recovers",
    async (failure) => {
      const fetcher = vi
        .fn()
        .mockImplementationOnce(async () => {
          if (failure === "network") throw new Error("RAW NETWORK");
          return new Response("{}", { status: 503 });
        })
        .mockResolvedValueOnce(new Response(JSON.stringify(admin)));
      vi.stubGlobal("fetch", fetcher);
      setup();
      await submit();
      expect(await screen.findByRole("alert")).toHaveTextContent(
        "We couldn't check administrator access",
      );
      expect(screen.getAllByRole("alert")).toHaveLength(1);
      expect(
        screen.getByRole("button", { name: "Sign in securely" }),
      ).toBeDisabled();
      await userEvent.click(screen.getByRole("button", { name: "Try again" }));
      expect(await screen.findByText("Authorized dashboard")).toBeVisible();
      expect(fetcher).toHaveBeenCalledTimes(2);
    },
  );
  it("clears a previous backend failure before a new failed Firebase sign-in", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response("{}", { status: 503 })),
    );
    const f = setup();
    await submit();
    await screen.findByRole("alert");
    await userEvent.click(screen.getByRole("button", { name: "Sign out" }));
    vi.mocked(f.gateway.login).mockRejectedValue(new Error("RAW FIREBASE"));
    await submit();
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Unable to sign in",
    );
    expect(screen.getAllByRole("alert")).toHaveLength(1);
    expect(screen.queryByText(/We couldn.t check/)).not.toBeInTheDocument();
  });
  it("missing Firebase config fails visibly and prevents authentication attempts", () => {
    const f = setup({ enabled: false });
    expect(screen.getByRole("alert")).toHaveTextContent(
      "check the web configuration",
    );
    expect(screen.getAllByRole("alert")).toHaveLength(1);
    expect(
      screen.getByRole("button", { name: "Sign in securely" }),
    ).toBeDisabled();
    expect(f.gateway.subscribe).not.toHaveBeenCalled();
    expect(f.gateway.login).not.toHaveBeenCalled();
  });
  it("invalid API configuration does not leak the configured value", () => {
    setup({ base: "http://private-insecure.example/api/v1" });
    expect(screen.getByRole("alert")).toHaveTextContent(
      "check the web configuration",
    );
    expect(screen.queryByText(/private-insecure/)).not.toBeInTheDocument();
  });
  it("invalid Firebase SDK configuration is distinct from credentials failure", async () => {
    const f = setup();
    vi.mocked(f.gateway.login).mockRejectedValue({
      code: "auth/invalid-api-key",
      message: "RAW KEY",
    });
    await submit();
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "check the web configuration",
    );
    expect(screen.getAllByRole("alert")).toHaveLength(1);
    expect(
      screen.queryByText(/Unable to sign in|RAW KEY/),
    ).not.toBeInTheDocument();
  });
  it("persistent 401 refreshes once and fails closed", async () => {
    const fetcher = vi.fn(async () => new Response("{}", { status: 401 }));
    vi.stubGlobal("fetch", fetcher);
    setup();
    await submit();
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Please sign in again",
    );
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(token.mock.calls.map((call) => call[0])).toEqual([false, true]);
    expect(screen.queryByText("Authorized dashboard")).not.toBeInTheDocument();
  });
  it("does not render a dashboard until the backend confirms authorization", async () => {
    let resolve!: (response: Response) => void;
    vi.stubGlobal(
      "fetch",
      vi.fn(
        () =>
          new Promise<Response>((finish) => {
            resolve = finish;
          }),
      ),
    );
    setup();
    await submit();
    expect(screen.queryByText("Authorized dashboard")).not.toBeInTheDocument();
    await waitFor(() => expect(resolve).toBeTypeOf("function"));
    await act(async () => resolve(new Response(JSON.stringify(admin))));
    expect(await screen.findByText("Authorized dashboard")).toBeVisible();
  });
});

describe("same-user reauthentication", () => {
  it("rechecks backend authority when Firebase succeeds without another auth-state event", async () => {
    const fetcher = vi
      .fn()
      .mockResolvedValueOnce(new Response("{}", { status: 401 }))
      .mockResolvedValueOnce(new Response("{}", { status: 401 }))
      .mockResolvedValueOnce(new Response(JSON.stringify(admin)));
    vi.stubGlobal("fetch", fetcher);
    const f = setup();
    await submit();
    await screen.findByText("Please sign in again to continue.");
    vi.mocked(f.gateway.login).mockResolvedValueOnce(identity);
    await submit();
    expect(await screen.findByText("Authorized dashboard")).toBeVisible();
    expect(fetcher).toHaveBeenCalledTimes(3);
  });
});
