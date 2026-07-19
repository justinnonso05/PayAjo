"use client";

import { useProfile } from "./use-profile";

/** Thin wrapper so call sites that only need the id don't have to know about the full profile shape. */
export function useCurrentUserId(): string | null {
  const { profile } = useProfile();
  return profile?.id ?? null;
}
