"use client";
import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { AdminApi, adminFrom, type Admin, type Identity } from "../../lib/api";
import {
  configured,
  firebaseGateway,
  isFirebaseConfigurationError,
} from "./firebase";
export interface Gateway {
  subscribe(
    next: (identity: Identity | null) => void,
    onError?: () => void,
  ): () => void;
  login(email: string, password: string): Promise<Identity | void>;
  logout(): Promise<void>;
}
export type SessionState = "loading" | "guest" | "ready" | "denied" | "error";
interface Session {
  state: SessionState;
  problem: "configuration" | "backend" | "session" | null;
  admin: Admin | null;
  api: AdminApi | null;
  login(email: string, password: string): Promise<void>;
  logout(): Promise<void>;
  retry(): void;
}
const Context = createContext<Session | null>(null);
export function SessionProvider({
  children,
  gateway = firebaseGateway,
  enabled = configured,
  base = process.env.NEXT_PUBLIC_API_BASE_URL || "http://127.0.0.1:3000/api/v1",
}: {
  children: ReactNode;
  gateway?: Gateway;
  enabled?: boolean;
  base?: string;
}) {
  const current = useRef<Identity | null>(null),
    version = useRef(0),
    mounted = useRef(false);
  const [state, setState] = useState<SessionState>("loading");
  const [problem, setProblem] = useState<Session["problem"]>(null);
  const [admin, setAdmin] = useState<Admin | null>(null);
  const [api, setApi] = useState<AdminApi | null>(null);
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    let alive = true;
    mounted.current = true;
    let stop = () => {};
    const reject = (status: number) => {
      if (status === 401) {
        current.current = null;
        version.current++;
        setAdmin(null);
        setProblem("session");
        setState("guest");
      }
    };
    try {
      if (!enabled) throw new Error();
      const client = new AdminApi(base, () => current.current, reject);
      setApi(client);
      stop = gateway.subscribe(
        (identity) => {
          if (!alive) return;
          current.current = identity;
          const epoch = ++version.current;
          setAdmin(null);
          setProblem(null);
          setState(identity ? "loading" : "guest");
          if (identity)
            void client
              .request("/admin/me")
              .then((value) => {
                if (alive && epoch === version.current) {
                  setAdmin(adminFrom(value));
                  setState("ready");
                }
              })
              .catch((error: unknown) => {
                if (alive && epoch === version.current) {
                  setProblem("backend");
                  setState(
                    error instanceof Error &&
                      "status" in error &&
                      error.status === 403
                      ? "denied"
                      : "error",
                  );
                }
              });
        },
        () => {
          if (!alive) return;
          current.current = null;
          version.current++;
          setAdmin(null);
          setProblem("configuration");
          setState("error");
        },
      );
    } catch {
      setProblem("configuration");
      setState("error");
    }
    return () => {
      alive = false;
      mounted.current = false;
      current.current = null;
      stop();
    };
  }, [gateway, enabled, base, attempt]);
  async function login(email: string, password: string) {
    if (!enabled || problem === "configuration")
      throw new Error("Sign-in unavailable");
    current.current = null;
    const epoch = ++version.current;
    setAdmin(null);
    setProblem(null);
    setState("guest");
    try {
      const identity = await gateway.login(email, password);
      // Same-UID reauthentication may not emit onAuthStateChanged. Re-subscribe
      // to bootstrap through /admin/me; a Firebase result never grants access.
      if (identity && mounted.current && epoch === version.current)
        setAttempt((value) => value + 1);
    } catch (error) {
      if (
        mounted.current &&
        epoch === version.current &&
        isFirebaseConfigurationError(error)
      ) {
        setProblem("configuration");
        setState("error");
      }
      throw new Error("Sign-in failed");
    }
  }
  async function logout() {
    current.current = null;
    version.current++;
    setAdmin(null);
    setProblem(null);
    setState("guest");
    await gateway.logout();
  }
  return (
    <Context.Provider
      value={{
        state,
        problem,
        admin,
        api,
        login,
        logout,
        retry: () => setAttempt((a) => a + 1),
      }}
    >
      {children}
    </Context.Provider>
  );
}
export function useSession() {
  const s = useContext(Context);
  if (!s) throw new Error("Session provider required");
  return s;
}
