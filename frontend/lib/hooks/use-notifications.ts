"use client";

import { useCallback, useEffect, useState } from "react";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";
import type { AppNotification } from "@/lib/types";

export function useNotifications() {
  const [items, setItems] = useState<AppNotification[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const res = await api.get(endpoints.notifications, authHeaders());
      const list = ((res.data as AppNotification[]) ?? []).slice();
      list.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
      setItems(list);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Couldn't load notifications.");
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- refresh() is async, setState happens post-await
    refresh();
  }, [refresh]);

  const markRead = useCallback(async (id: string) => {
    setItems((prev) => {
      const target = prev.find((n) => n.id === id);
      if (!target || target.is_read) return prev;
      return prev.map((n) => (n.id === id ? { ...n, is_read: true } : n));
    });
    try {
      await api.post(endpoints.markNotificationsRead, { notification_ids: [id] }, authHeaders());
    } catch {
      // Best-effort — keep the optimistic read state either way.
    }
  }, []);

  const markAllRead = useCallback(async () => {
    let unreadIds: string[] = [];
    setItems((prev) => {
      unreadIds = prev.filter((n) => !n.is_read).map((n) => n.id);
      return prev.map((n) => ({ ...n, is_read: true }));
    });
    if (unreadIds.length === 0) return;
    try {
      await api.post(endpoints.markNotificationsRead, { notification_ids: unreadIds }, authHeaders());
    } catch {
      // Best-effort.
    }
  }, []);

  const dismiss = useCallback((id: string) => {
    setItems((prev) => prev.filter((n) => n.id !== id));
  }, []);

  return { items, isLoading, error, refresh, markRead, markAllRead, dismiss };
}
