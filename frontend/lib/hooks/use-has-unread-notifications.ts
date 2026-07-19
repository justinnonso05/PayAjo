"use client";

import { useNotifications } from "./use-notifications";

export function useHasUnreadNotifications(): boolean {
  const { items } = useNotifications();
  return items.some((n) => !n.is_read);
}
