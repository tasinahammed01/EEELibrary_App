import React from "react";
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor, fireEvent } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Records, Detail } from "../src/features/records/records";
import { MetadataForm } from "../src/features/records/metadata-form";
import { Overview } from "../src/features/dashboard/overview";
import { Shell } from "../src/components/shell";
import { Login } from "../src/features/auth/login";
import { ApiError } from "../src/lib/api";
const { session } = vi.hoisted(() => ({
  session: {
    state: "ready",
    admin: {
      id: "admin",
      role: "SUPER_ADMIN",
      status: "ACTIVE",
      displayName: "Trusted Operator",
      email: "admin@example.test",
    },
    api: { request: vi.fn() },
    logout: vi.fn(),
    login: vi.fn(),
    retry: vi.fn(),
  },
}));
vi.mock("../src/features/auth/session", () => ({ useSession: () => session }));
vi.mock("next/link", () => ({
  default: ({
    href,
    children,
    ...props
  }: React.AnchorHTMLAttributes<HTMLAnchorElement>) => (
    <a href={href} {...props}>
      {children}
    </a>
  ),
}));
const id = "11111111-1111-4111-8111-111111111111";
const page = (items: unknown[]) => ({
  items,
  page: 1,
  pageSize: 12,
  total: items.length,
  hasMore: false,
});
beforeEach(() => {
  session.state = "ready";
  session.admin.role = "SUPER_ADMIN";
  session.api.request.mockReset().mockResolvedValue(page([]));
  session.logout.mockReset().mockResolvedValue(undefined);
  session.login.mockReset().mockResolvedValue(undefined);
  HTMLDialogElement.prototype.showModal = function () {
    this.setAttribute("open", "");
  };
  HTMLDialogElement.prototype.close = function () {
    this.removeAttribute("open");
  };
});
describe("admin workflows", () => {
  it("shows email/password login without signup", () => {
    session.state = "guest";
    render(<Login />);
    expect(screen.getByLabelText("Email address")).toBeVisible();
    expect(screen.getByLabelText("Password")).toHaveAttribute(
      "type",
      "password",
    );
    expect(
      screen.queryByRole("button", { name: /register/i }),
    ).not.toBeInTheDocument();
  });
  it("safe non-admin denial", () => {
    session.state = "denied";
    render(<Login />);
    expect(screen.getByRole("alert")).toHaveTextContent(
      "does not have active administrator access",
    );
  });
  it("signs out through gateway", async () => {
    render(
      <Shell section="">
        <p>Page</p>
      </Shell>,
    );
    await userEvent.click(screen.getByRole("button", { name: "Sign out" }));
    expect(session.logout).toHaveBeenCalledTimes(1);
  });
  it("role navigation hides unauthorized links", () => {
    session.admin.role = "CONTENT_MANAGER";
    render(<Shell section="books">Page</Shell>);
    expect(screen.getByRole("link", { name: "Books" })).toBeVisible();
    expect(
      screen.queryByRole("link", { name: "Payments" }),
    ).not.toBeInTheDocument();
  });
  it("mobile navigation toggles accessibly", async () => {
    render(<Shell section="">Page</Shell>);
    const button = screen.getByRole("button", { name: "Toggle navigation" });
    await userEvent.click(button);
    expect(button).toHaveAttribute("aria-expanded", "true");
  });
  it("dashboard loading then real counts", async () => {
    session.api.request.mockResolvedValue({
      publishedBooks: 7,
      pendingPayments: 2,
    });
    render(<Overview />);
    expect(screen.getByRole("status")).toBeInTheDocument();
    expect(await screen.findByText("7")).toBeVisible();
    expect(screen.queryByText(/revenue/i)).not.toBeInTheDocument();
  });
  it("dashboard error can retry", async () => {
    session.api.request
      .mockRejectedValueOnce(new ApiError(503))
      .mockResolvedValue({ publishedBooks: 3 });
    render(<Overview />);
    await userEvent.click(
      await screen.findByRole("button", { name: "Try again" }),
    );
    expect(await screen.findByText("3")).toBeVisible();
  });
  it.each([
    "payments",
    "books",
    "categories",
    "users",
    "orders",
    "entitlements",
    "audit",
  ])("renders paginated %s empty state", async (kind) => {
    render(<Records kind={kind} />);
    expect(await screen.findByText("No records to show")).toBeVisible();
    expect(session.api.request).toHaveBeenCalledWith(
      expect.stringContaining("pageSize=12"),
      "GET",
      undefined,
      expect.any(AbortSignal),
    );
  });
  it("payments filter and detail link", async () => {
    session.api.request.mockResolvedValue(
      page([
        {
          id,
          status: "PENDING",
          method: "BKASH",
          amount: "100",
          currency: "BDT",
          createdAt: "2026-01-01",
          order: { id: "order" },
        },
      ]),
    );
    render(<Records kind="payments" />);
    expect(await screen.findByRole("link", { name: /View/ })).toHaveAttribute(
      "href",
      "/payments/" + id,
    );
    fireEvent.change(screen.getByLabelText("Status"), {
      target: { value: "APPROVED" },
    });
    await waitFor(() =>
      expect(session.api.request).toHaveBeenLastCalledWith(
        expect.stringContaining("status=APPROVED"),
        "GET",
        undefined,
        expect.any(AbortSignal),
      ),
    );
  });
  it("approval requires confirmation and disables duplicates", async () => {
    let finish!: (value: unknown) => void;
    session.api.request.mockImplementation((path: string, method: string) =>
      method === "POST"
        ? new Promise((r) => {
            finish = r;
          })
        : Promise.resolve({
            id,
            status: "PENDING",
            method: "BKASH",
            amount: "100",
            currency: "BDT",
            transactionReference: "SAFEFIXTURE",
          }),
    );
    render(<Detail kind="payments" id={id} />);
    await userEvent.click(
      await screen.findByRole("button", { name: "Approve payment" }),
    );
    expect(
      session.api.request.mock.calls.filter((c) => c[1] === "POST"),
    ).toHaveLength(0);
    await userEvent.click(screen.getByRole("button", { name: "Confirm" }));
    expect(screen.getByRole("button", { name: "Saving…" })).toBeDisabled();
    finish({ id, status: "APPROVED" });
    expect(
      await screen.findByText("Change confirmed by EEELibrary."),
    ).toBeVisible();
    expect(
      session.api.request.mock.calls.filter((c) => c[1] === "POST"),
    ).toHaveLength(1);
  });
  it("reject sends allowlisted reason and retains safe conflict feedback", async () => {
    session.api.request.mockImplementation((_path: string, method: string) =>
      method === "POST"
        ? Promise.reject(new ApiError(409))
        : Promise.resolve({
            id,
            status: "PENDING",
            method: "NAGAD",
            amount: "90",
            currency: "BDT",
          }),
    );
    render(<Detail kind="payments" id={id} />);
    await userEvent.click(
      await screen.findByRole("button", { name: "Reject payment" }),
    );
    await userEvent.selectOptions(
      screen.getByLabelText("Rejection reason"),
      "AMOUNT_MISMATCH",
    );
    await userEvent.click(screen.getByRole("button", { name: "Confirm" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("conflicts");
    expect(session.api.request).toHaveBeenCalledWith(
      "/admin/payments/" + id + "/reject",
      "POST",
      { reason: "AMOUNT_MISMATCH" },
    );
  });
  it("user status needs explicit confirmation", async () => {
    session.api.request.mockResolvedValue({
      id,
      status: "ACTIVE",
      displayName: "Reader",
    });
    render(<Detail kind="users" id={id} />);
    await userEvent.click(
      await screen.findByRole("button", { name: "Change status" }),
    );
    expect(screen.getByText(/ACTIVE.*DISABLED/)).toBeInTheDocument();
    await userEvent.click(screen.getByRole("button", { name: "Confirm" }));
    await waitFor(() =>
      expect(session.api.request).toHaveBeenCalledWith(
        "/admin/users/" + id + "/status",
        "PATCH",
        { status: "DISABLED" },
      ),
    );
  });
  it("creates category metadata only", async () => {
    const saved = vi.fn();
    session.api.request.mockResolvedValue({ id });
    render(<MetadataForm kind="categories" onSaved={saved} />);
    await userEvent.type(screen.getByLabelText("Name"), "Power Systems");
    await userEvent.click(
      screen.getByRole("button", { name: "Save category" }),
    );
    await waitFor(() => expect(saved).toHaveBeenCalled());
    expect(session.api.request).toHaveBeenCalledWith(
      "/admin/categories",
      "POST",
      { name: "Power Systems", description: "", isActive: true, sortOrder: 0 },
    );
  });
  it("edits category without changing slug", async () => {
    session.api.request.mockResolvedValue({ id });
    render(
      <MetadataForm
        kind="categories"
        initial={{ id, name: "Circuits", sortOrder: 1, isActive: true }}
        onSaved={vi.fn()}
      />,
    );
    await userEvent.click(
      screen.getByRole("button", { name: "Save category" }),
    );
    await waitFor(() =>
      expect(session.api.request).toHaveBeenCalledWith(
        "/admin/categories/" + id,
        "PATCH",
        expect.not.objectContaining({ slug: expect.anything() }),
      ),
    );
  });
  it("creates a draft book with decimal string and no private fields", async () => {
    session.api.request.mockImplementation((path: string, method: string) =>
      Promise.resolve(
        method === "POST"
          ? { id }
          : page([{ id, name: "Circuits", isActive: true }]),
      ),
    );
    render(<MetadataForm kind="books" onSaved={vi.fn()} />);
    fireEvent.change(screen.getByLabelText("Title"), {
      target: { value: "Circuit Theory" },
    });
    fireEvent.change(screen.getByLabelText("Description"), {
      target: { value: "Study guide" },
    });
    await screen.findByRole("option", { name: "Circuits" });
    await userEvent.selectOptions(screen.getByLabelText("Category"), id);
    await userEvent.click(screen.getByRole("button", { name: "Save book" }));
    await waitFor(() =>
      expect(session.api.request).toHaveBeenCalledWith(
        "/admin/books",
        "POST",
        expect.objectContaining({
          price: "0",
          status: "DRAFT",
          currency: "BDT",
        }),
      ),
    );
  });
  it("publication change asks for confirmation", async () => {
    render(
      <MetadataForm
        kind="books"
        initial={{
          id,
          title: "Circuits",
          description: "Guide",
          price: "0",
          categoryId: id,
          status: "DRAFT",
          category: { name: "Circuits" },
        }}
        onSaved={vi.fn()}
      />,
    );
    await userEvent.selectOptions(
      screen.getByLabelText("Publication status"),
      "PUBLISHED",
    );
    await userEvent.click(screen.getByRole("button", { name: "Save book" }));
    expect(await screen.findByRole("dialog")).toHaveTextContent(
      "Confirm publication change",
    );
    expect(session.api.request.mock.calls.some((c) => c[1] === "PATCH")).toBe(
      false,
    );
  });
  it.each([320, 360, 390, 1440])(
    "keeps navigation and records usable at width %i",
    async (width) => {
      Object.defineProperty(window, "innerWidth", {
        configurable: true,
        value: width,
      });
      render(
        <Shell section="books">
          <Records kind="books" />
        </Shell>,
      );
      expect(await screen.findByText("No records to show")).toBeInTheDocument();
      expect(screen.getByRole("navigation")).toBeInTheDocument();
    },
  );
});

describe("read-only admin records and metadata updates", () => {
  it("saves a book edit without private fields or slug changes", async () => {
    session.api.request.mockImplementation((_path: string, method: string) =>
      Promise.resolve(
        method === "PATCH"
          ? { id }
          : page([{ id, name: "Circuits", isActive: true }]),
      ),
    );
    render(
      <MetadataForm
        kind="books"
        initial={{
          id,
          title: "Circuits",
          description: "Guide",
          price: "100.00",
          categoryId: id,
          status: "DRAFT",
        }}
        onSaved={vi.fn()}
      />,
    );
    await screen.findByRole("option", { name: "Circuits" });
    fireEvent.change(screen.getByLabelText("Title"), {
      target: { value: "Revised Circuits" },
    });
    await userEvent.click(screen.getByRole("button", { name: "Save book" }));
    await waitFor(() =>
      expect(session.api.request).toHaveBeenCalledWith(
        "/admin/books/" + id,
        "PATCH",
        expect.objectContaining({ title: "Revised Circuits", price: "100.00" }),
      ),
    );
    const body = session.api.request.mock.calls.find(
      (call) => call[1] === "PATCH",
    )?.[2] as Record<string, unknown>;
    expect(body).not.toHaveProperty("slug");
    expect(body).not.toHaveProperty("coverObjectKey");
  });
  it("order detail shows payment status without lifecycle edit buttons", async () => {
    session.api.request.mockResolvedValue({
      id,
      status: "PAYMENT_SUBMITTED",
      amount: "100.00",
      currency: "BDT",
      payments: [{ status: "PENDING" }],
    });
    render(<Detail kind="orders" id={id} />);
    expect(await screen.findByText("Latest payment")).toBeVisible();
    expect(screen.getByText("PENDING")).toBeVisible();
    expect(
      screen.queryByRole("button", { name: /approve|change status/i }),
    ).not.toBeInTheDocument();
  });
  it("entitlements have no grant or revoke controls", async () => {
    session.api.request.mockResolvedValue({
      id,
      status: "ACTIVE",
      orderId: id,
    });
    render(<Detail kind="entitlements" id={id} />);
    expect(await screen.findByText("Entitlement details")).toBeVisible();
    expect(
      screen.queryByRole("button", { name: /grant|revoke|delete/i }),
    ).not.toBeInTheDocument();
  });
  it("audit table is read only and shows trusted actor", async () => {
    session.api.request.mockResolvedValue(
      page([
        {
          id,
          action: "USER_STATUS_CHANGED",
          targetType: "User",
          targetId: id,
          createdAt: "2026-01-01",
          adminActor: { displayName: "Trusted operator" },
        },
      ]),
    );
    render(<Records kind="audit" />);
    expect(await screen.findByText("USER_STATUS_CHANGED")).toBeVisible();
    expect(screen.getByText("Trusted operator")).toBeVisible();
    expect(
      screen.queryByRole("button", { name: /edit|delete/i }),
    ).not.toBeInTheDocument();
  });
  it("metadata double submission sends only one mutation", async () => {
    let finish!: (value: unknown) => void;
    session.api.request.mockImplementation(
      () =>
        new Promise((r) => {
          finish = r;
        }),
    );
    render(<MetadataForm kind="categories" onSaved={vi.fn()} />);
    fireEvent.change(screen.getByLabelText("Name"), {
      target: { value: "Controlled" },
    });
    const button = screen.getByRole("button", { name: "Save category" });
    await userEvent.dblClick(button);
    expect(session.api.request).toHaveBeenCalledTimes(1);
    expect(screen.getByRole("button", { name: "Saving\u2026" })).toBeDisabled();
    finish({ id });
    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Save category" }),
      ).toBeEnabled(),
    );
  });
});

describe("record lifecycle regressions", () => {
  it("switching category editors resets values for the new record", async () => {
    session.api.request.mockResolvedValue(
      page([
        { id: "first", name: "First category", isActive: true },
        { id: "second", name: "Second category", isActive: true },
      ]),
    );
    render(<Records kind="categories" />);
    await screen.findByText("First category");
    await userEvent.click(screen.getAllByRole("button", { name: "Edit" })[0]);
    expect(screen.getByLabelText("Name")).toHaveValue("First category");
    await userEvent.click(screen.getAllByRole("button", { name: "Edit" })[1]);
    expect(screen.getByLabelText("Name")).toHaveValue("Second category");
  });
  it("ignores a stale payment filter response even when transport ignores abort", async () => {
    let finish!: (value: unknown) => void;
    session.api.request.mockImplementation((path: string) =>
      path.includes("status=PENDING")
        ? new Promise((resolve) => {
            finish = resolve;
          })
        : Promise.resolve(
            page([
              {
                id,
                status: "APPROVED",
                method: "BKASH",
                amount: "100",
                currency: "BDT",
                order: { id, book: { title: "Current result" } },
              },
            ]),
          ),
    );
    render(<Records kind="payments" />);
    await waitFor(() => expect(session.api.request).toHaveBeenCalledTimes(1));
    await userEvent.selectOptions(screen.getByLabelText("Status"), "APPROVED");
    expect(await screen.findByText("Current result")).toBeVisible();
    finish(
      page([
        {
          id: "old",
          status: "PENDING",
          order: { book: { title: "Stale result" } },
        },
      ]),
    );
    await waitFor(() =>
      expect(screen.queryByText("Stale result")).not.toBeInTheDocument(),
    );
    expect(screen.getByText("Current result")).toBeVisible();
  });
});
