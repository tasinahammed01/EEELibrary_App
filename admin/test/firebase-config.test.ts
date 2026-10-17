import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
beforeEach(() => {
  vi.resetModules();
  vi.stubEnv("NEXT_PUBLIC_FIREBASE_API_KEY", "controlled-public-key");
  vi.stubEnv("NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN", "controlled.example.test");
  vi.stubEnv("NEXT_PUBLIC_FIREBASE_PROJECT_ID", "controlled-project");
  vi.stubEnv("NEXT_PUBLIC_FIREBASE_APP_ID", "1:123:web:controlled");
});
afterEach(() => vi.unstubAllEnvs());
describe("Firebase web configuration boundaries", () => {
  it("accepts all four public web settings", async () => {
    expect((await import("../src/features/auth/firebase")).configured).toBe(
      true,
    );
  });
  it.each([
    "NEXT_PUBLIC_FIREBASE_API_KEY",
    "NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN",
    "NEXT_PUBLIC_FIREBASE_PROJECT_ID",
    "NEXT_PUBLIC_FIREBASE_APP_ID",
  ])("missing %s fails before SDK initialization", async (key) => {
    vi.stubEnv(key, "");
    const settings = await import("../src/features/auth/firebase");
    expect(settings.configured).toBe(false);
    expect(() => settings.firebaseGateway.subscribe(vi.fn())).toThrow(
      "Firebase web configuration is required.",
    );
  });
  it("rejects whitespace-only config", async () => {
    vi.stubEnv("NEXT_PUBLIC_FIREBASE_API_KEY", "   ");
    expect((await import("../src/features/auth/firebase")).configured).toBe(
      false,
    );
  });
  it.each([
    "auth/invalid-api-key",
    "auth/api-key-not-valid.-please-pass-a-valid-api-key.",
    "auth/operation-not-allowed",
    "auth/unauthorized-domain",
    "auth/configuration-not-found",
  ])("classifies %s safely", async (code) => {
    expect(
      (
        await import("../src/features/auth/firebase")
      ).isFirebaseConfigurationError({ code, message: "not displayed" }),
    ).toBe(true);
  });
  it.each([
    "auth/invalid-credential",
    "auth/wrong-password",
    "auth/network-request-failed",
  ])("does not confuse %s with setup failure", async (code) => {
    expect(
      (
        await import("../src/features/auth/firebase")
      ).isFirebaseConfigurationError({ code }),
    ).toBe(false);
  });
});
