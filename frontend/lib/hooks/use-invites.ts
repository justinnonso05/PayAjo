"use client";

import { useCallback, useEffect, useState } from "react";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";
import type { GroupInvite } from "@/lib/types";

export type InviteWithGroupName = { invite: GroupInvite; groupName: string };

export function useInvites() {
  const [invites, setInvites] = useState<InviteWithGroupName[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const res = await api.get(endpoints.myInvites, authHeaders());
      const all = ((res.data as GroupInvite[]) ?? []).filter((i) => i.status === "pending");

      const withNames = await Promise.all(
        all.map(async (invite) => {
          try {
            const groupRes = await api.get(endpoints.group(invite.group_id), authHeaders());
            return { invite, groupName: (groupRes.data as { name?: string })?.name ?? "A savings group" };
          } catch {
            return { invite, groupName: "A savings group" };
          }
        }),
      );

      setInvites(withNames);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Couldn't load your invites.");
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- refresh() is async, setState happens post-await
    refresh();
  }, [refresh]);

  const respond = useCallback(
    async (inviteId: string, accept: boolean) => {
      await api.post(endpoints.respondInvite(inviteId, accept), {}, authHeaders());
      await refresh();
    },
    [refresh],
  );

  return { invites, isLoading, error, refresh, respond };
}
