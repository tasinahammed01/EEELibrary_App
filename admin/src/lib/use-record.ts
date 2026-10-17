"use client";
import { useEffect, useState } from "react";
import { useSession } from "../features/auth/session";
export function useRecord(path: string) {
  const { api } = useSession();
  const [revision, setRevision] = useState(0);
  const [state, setState] = useState<{
    path: string;
    revision: number;
    value: unknown;
    error: string;
  }>({ path, revision: -1, value: null, error: "" });
  useEffect(() => {
    const controller = new AbortController();
    if (api)
      void api
        .request(path, "GET", undefined, controller.signal)
        .then((value) => {
          if (!controller.signal.aborted)
            setState({ path, revision, value, error: "" });
        })
        .catch((error: unknown) => {
          if (!controller.signal.aborted)
            setState({
              path,
              revision,
              value: null,
              error:
                error instanceof Error ? error.message : "Service unavailable.",
            });
        });
    return () => controller.abort();
  }, [path, api, revision]);
  const current = state.path === path && state.revision === revision;
  return {
    value: current ? state.value : null,
    error: current ? state.error : "",
    loading: !current,
    reload: () => setRevision((r) => r + 1),
  };
}
