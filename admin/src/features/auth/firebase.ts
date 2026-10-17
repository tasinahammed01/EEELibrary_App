"use client";
import { getApp, getApps, initializeApp } from "firebase/app";
import {
  browserSessionPersistence,
  getAuth,
  onAuthStateChanged,
  setPersistence,
  signInWithEmailAndPassword,
  signOut,
} from "firebase/auth";
import type { Identity } from "../../lib/api";
const config = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};
export const configured = Object.values(config).every(
  (value) => typeof value === "string" && value.trim().length > 0,
);
function auth() {
  if (!configured) throw new Error("Firebase web configuration is required.");
  return getAuth(getApps().length ? getApp() : initializeApp(config));
}
export const firebaseGateway = {
  subscribe(next: (identity: Identity | null) => void, onError?: () => void) {
    return onAuthStateChanged(auth(), next, onError);
  },
  async login(email: string, password: string) {
    const a = auth();
    await setPersistence(a, browserSessionPersistence);
    return (await signInWithEmailAndPassword(a, email, password)).user;
  },
  async logout() {
    await signOut(auth());
  },
};

// Only classify fixed SDK codes; never render an exception message or config value.
export function isFirebaseConfigurationError(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    [
      "auth/invalid-api-key",
      "auth/api-key-not-valid.-please-pass-a-valid-api-key.",
      "auth/invalid-auth-domain",
      "auth/operation-not-allowed",
      "auth/app-not-authorized",
      "auth/unauthorized-domain",
      "auth/configuration-not-found",
    ].includes(String(error.code))
  );
}
