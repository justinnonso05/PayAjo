"use client";

import { useCallback, useEffect, useState } from "react";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";
import type { WalletTransaction } from "@/lib/types";

export function useWalletTransactions() {
  const [items, setItems] = useState<WalletTransaction[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const res = await api.get(endpoints.walletTransactions, authHeaders());
      const list = ((res.data as WalletTransaction[]) ?? []).slice();
      list.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
      setItems(list);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Couldn't load your transactions.");
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  return { items, isLoading, error, refresh };
}
