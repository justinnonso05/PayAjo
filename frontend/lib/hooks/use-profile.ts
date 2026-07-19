"use client";

import { useCallback, useEffect, useState } from "react";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";
import type { Profile } from "@/lib/types";

/** Fetch-once-per-mount source of truth for the current user's profile, shared by the sidebar, Home, and Wallet. */
export function useProfile() {
  const [profile, setProfile] = useState<Profile | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const res = await api.get(endpoints.me, authHeaders());
      setProfile((res.data as Profile) ?? null);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Couldn't load your profile.");
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  return { profile, isLoading, error, refresh };
}
