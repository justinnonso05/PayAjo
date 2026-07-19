"use client";

import { useCallback, useEffect, useState } from "react";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";
import type { Group, GroupMember, PendingMember } from "@/lib/types";
import { useCurrentUserId } from "./use-current-user-id";

export function useGroup(groupId: string) {
  const currentUserId = useCurrentUserId();
  const [group, setGroup] = useState<Group | null>(null);
  const [members, setMembers] = useState<GroupMember[]>([]);
  const [pendingMembers, setPendingMembers] = useState<PendingMember[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isLoadingPending, setIsLoadingPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const isAdmin = !!currentUserId && group?.admin_user_id === currentUserId;

  const refreshMembers = useCallback(async () => {
    const res = await api.get(endpoints.groupMembers(groupId), authHeaders());
    setMembers((res.data as GroupMember[]) ?? []);
  }, [groupId]);

  const refreshPending = useCallback(async () => {
    setIsLoadingPending(true);
    try {
      const res = await api.get(endpoints.pendingMembers(groupId), authHeaders());
      setPendingMembers((res.data as PendingMember[]) ?? []);
    } catch {
      // Pending-members is admin-only; a non-admin 403 here is expected, not an error to surface.
    } finally {
      setIsLoadingPending(false);
    }
  }, [groupId]);

  const refresh = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [groupRes] = await Promise.all([api.get(endpoints.group(groupId), authHeaders()), refreshMembers()]);
      setGroup(groupRes.data as Group);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Couldn't load this group.");
    } finally {
      setIsLoading(false);
    }
  }, [groupId, refreshMembers]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- refresh() is async, setState happens post-await
    refresh();
  }, [refresh]);

  useEffect(() => {
    if (isAdmin) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- refreshPending() is async, setState happens post-await
      refreshPending();
    }
  }, [isAdmin, refreshPending]);

  const approveMember = useCallback(
    async (userId: string) => {
      await api.post(endpoints.approveMember(groupId, userId), {}, authHeaders());
      await Promise.all([refreshPending(), refreshMembers()]);
    },
    [groupId, refreshPending, refreshMembers],
  );

  const startGroup = useCallback(async () => {
    const res = await api.post(endpoints.startGroup(groupId), { randomize: true }, authHeaders());
    setGroup(res.data as Group);
  }, [groupId]);

  const rotateInviteCode = useCallback(async () => {
    const res = await api.post(endpoints.rotateInviteCode(groupId), {}, authHeaders());
    setGroup(res.data as Group);
  }, [groupId]);

  return {
    group,
    members,
    pendingMembers,
    isLoading,
    isLoadingPending,
    isAdmin,
    error,
    refresh,
    refreshMembers,
    approveMember,
    startGroup,
    rotateInviteCode,
    setGroup,
  };
}
