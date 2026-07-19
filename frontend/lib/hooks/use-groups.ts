"use client";

import { useCallback, useEffect, useState } from "react";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";
import type { Group, GroupMembership } from "@/lib/types";

export type GroupSummary = {
  membership: GroupMembership;
  group: Group;
  memberCount: number;
};

/** Mirrors mobile's HomeController: loads every group the user belongs to, in parallel, with member counts. */
export function useGroups() {
  const [summaries, setSummaries] = useState<GroupSummary[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const res = await api.get(endpoints.myGroups, authHeaders());
      const memberships = (res.data as GroupMembership[]) ?? [];

      const results = await Promise.all(
        memberships.map(async (membership) => {
          const [groupRes, membersRes] = await Promise.all([
            api.get(endpoints.group(membership.group_id), authHeaders()),
            api.get(endpoints.groupMembers(membership.group_id), authHeaders()),
          ]);
          const group = groupRes.data as Group;
          const members = (membersRes.data as unknown[]) ?? [];
          return { membership, group, memberCount: members.length };
        }),
      );

      setSummaries(results);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Couldn't load your groups.");
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- refresh() is async, setState happens post-await
    refresh();
  }, [refresh]);

  return { summaries, hasGroup: summaries.length > 0, isLoading, error, refresh };
}
