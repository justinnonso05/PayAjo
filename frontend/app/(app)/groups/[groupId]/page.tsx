"use client";

import { BellRing, Calendar, Copy, Pencil, Share2, ShieldCheck, UserPlus, Users, Zap } from "lucide-react";
import Link from "next/link";
import { use, useCallback, useEffect, useState } from "react";
import { Modal } from "@/components/app/modal";
import { StatusPill } from "@/components/app/status-pill";
import { SuccessModal } from "@/components/app/success-modal";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";
import { hasPaidCurrentRound } from "@/lib/contribution-status";
import { formatAmount, formatShortDate } from "@/lib/format";
import { useCurrentUserId } from "@/lib/hooks/use-current-user-id";
import { useGroup } from "@/lib/hooks/use-group";
import { useRotations } from "@/lib/hooks/use-rotations";
import { useWalletTransactions } from "@/lib/hooks/use-wallet-transactions";
import type { CycleDelegationRequest, CycleSwapRequest, GroupMember, GroupRotationEntry } from "@/lib/types";
import { AutoDebitCard } from "./auto-debit-card";
import { CycleActionModal } from "./cycle-action-modal";
import { EditGroupModal } from "./edit-group-modal";
import { PendingCycleRequestsCard } from "./pending-cycle-requests-card";
import { SendInviteModal } from "./send-invite-modal";
import { StartGroupModal } from "./start-group-modal";

export default function GroupDetailsPage({ params }: { params: Promise<{ groupId: string }> }) {
  const { groupId } = use(params);
  const {
    group,
    members,
    pendingMembers,
    isLoading,
    isLoadingPending,
    isAdmin,
    error,
    approveMember,
    startGroup,
    rotateInviteCode,
    setGroup,
    setMembers,
  } = useGroup(groupId);
  const { items: transactions } = useWalletTransactions();
  const { rotations, isLoading: isLoadingRotations } = useRotations(groupId);
  const currentUserId = useCurrentUserId();

  const [isBusy, setIsBusy] = useState(false);
  const [busyError, setBusyError] = useState<string | null>(null);
  const [showMembers, setShowMembers] = useState(false);
  const [showEdit, setShowEdit] = useState(false);
  const [showInvite, setShowInvite] = useState(false);
  const [showInviteSuccess, setShowInviteSuccess] = useState(false);
  const [cycleAction, setCycleAction] = useState<{ entry: GroupRotationEntry; isDelegate: boolean } | null>(null);
  const [showStartGroup, setShowStartGroup] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [remindingUserId, setRemindingUserId] = useState<string | null>(null);
  const [pendingSwaps, setPendingSwaps] = useState<CycleSwapRequest[]>([]);
  const [pendingDelegations, setPendingDelegations] = useState<CycleDelegationRequest[]>([]);

  const loadPendingCycleRequests = useCallback(async () => {
    if (group?.status !== "active") return;
    try {
      const res = await api.get(endpoints.pendingSwaps(groupId), authHeaders());
      setPendingSwaps((res.data as CycleSwapRequest[]) ?? []);
    } catch {
      setPendingSwaps([]);
    }
    if (isAdmin) {
      try {
        const res = await api.get(endpoints.pendingDelegations(groupId), authHeaders());
        setPendingDelegations((res.data as CycleDelegationRequest[]) ?? []);
      } catch {
        // Admin-only; a 403 here just means "nothing to show" for a non-admin edge case.
        setPendingDelegations([]);
      }
    }
  }, [group?.status, groupId, isAdmin]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- loadPendingCycleRequests() is async, setState happens post-await
    loadPendingCycleRequests();
  }, [loadPendingCycleRequests]);

  const showToast = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(null), 3000);
  };

  if (isLoading) return <div className="mx-auto max-w-3xl px-6 py-10"><div className="h-96 animate-pulse rounded-card bg-white" /></div>;
  if (error || !group) return <div className="mx-auto max-w-3xl px-6 py-10 text-sm text-brand-dark/50">{error || "Couldn't load this group."}</div>;

  const currentMember = members.find((m) => m.user_id === currentUserId);
  // Prefer the backend's ground-truth `has_paid_current_cycle`; fall back
  // to the wallet-history heuristic only if the membership hasn't loaded yet.
  const hasPaid = currentMember ? currentMember.has_paid_current_cycle : hasPaidCurrentRound(group, transactions);
  const admin = members.find((m) => m.is_admin);

  const handleApprove = async (userId: string) => {
    setIsBusy(true);
    try {
      await approveMember(userId);
      showToast("Member approved");
    } catch (err) {
      setBusyError(err instanceof Error ? err.message : "Something went wrong.");
    } finally {
      setIsBusy(false);
    }
  };

  const handleStartGroup = async (options: { randomize: boolean; manualOrder?: string[] }) => {
    await startGroup(options);
    setShowStartGroup(false);
    showToast("Group started!");
  };

  const handleRotateCode = async () => {
    if (!confirm("Generate a new invite code? The current code will stop working immediately.")) return;
    setIsBusy(true);
    try {
      await rotateInviteCode();
      showToast("New invite code generated");
    } catch (err) {
      setBusyError(err instanceof Error ? err.message : "Something went wrong.");
    } finally {
      setIsBusy(false);
    }
  };

  const copyInviteCode = () => {
    if (!group.invite_code) return;
    navigator.clipboard.writeText(group.invite_code);
    showToast("Invite code copied");
  };

  const shareInviteLink = () => {
    if (!group.invite_code) return;
    navigator.clipboard.writeText(`Join my AjoPay group with code ${group.invite_code}`);
    showToast("Invite message copied. Paste it anywhere to share.");
  };

  const handleSendReminders = async () => {
    setIsBusy(true);
    setBusyError(null);
    try {
      await api.post(endpoints.sendRemindersBulk(groupId), {}, authHeaders());
      showToast("Reminders sent to everyone who still owes this round");
    } catch (err) {
      setBusyError(err instanceof ApiError ? err.message : "Something went wrong.");
    } finally {
      setIsBusy(false);
    }
  };

  const handleRemindMember = async (userId: string, name: string) => {
    setRemindingUserId(userId);
    try {
      await api.post(endpoints.sendMemberReminder(groupId, userId), {}, authHeaders());
      showToast(`Reminder sent to ${name}`);
    } catch (err) {
      setBusyError(err instanceof ApiError ? err.message : "Something went wrong.");
    } finally {
      setRemindingUserId(null);
    }
  };

  const handleTriggerScheduler = async () => {
    if (
      !confirm(
        "Run payout check? This manually runs the payout scheduler across ALL groups, not just this one — it's a testing/demo shortcut, not something you'd normally need to press.",
      )
    ) {
      return;
    }
    setIsBusy(true);
    setBusyError(null);
    try {
      const res = await api.post(endpoints.triggerScheduler, {}, authHeaders());
      const updated = await api.get(endpoints.group(groupId), authHeaders());
      setGroup(updated.data as typeof group);
      showToast(typeof res.data === "string" ? res.data : "Payout scheduler triggered.");
    } catch (err) {
      setBusyError(err instanceof ApiError ? err.message : "Could not run payout check.");
    } finally {
      setIsBusy(false);
    }
  };

  return (
    <div className="mx-auto max-w-3xl px-6 py-8 sm:px-10 sm:py-10">
      <div className="flex items-start justify-between gap-3">
        <h1 className="font-display text-2xl font-bold text-brand-dark">{group.name}</h1>
        {isAdmin && (
          <button type="button" onClick={() => setShowEdit(true)} className="flex h-9 w-9 items-center justify-center rounded-full text-brand-dark/50 hover:bg-white">
            <Pencil size={16} />
          </button>
        )}
      </div>

      <div className="mt-2 flex flex-wrap gap-2">
        <StatusPill label={group.status} tone={group.status === "active" ? "success" : "neutral"} />
        {group.status === "active" && hasPaid && <StatusPill label="Paid this round" tone="success" />}
        {isAdmin && <StatusPill label="You're the Admin" tone="info" />}
      </div>

      {toast && <div className="mt-4 rounded-xl bg-brand-dark px-4 py-2.5 text-sm font-semibold text-white">{toast}</div>}
      {busyError && <p className="mt-4 text-sm font-semibold text-red-500">{busyError}</p>}

      {isAdmin && (
        <div className="mt-6 rounded-card border border-brand-pale bg-white p-5 shadow-sm">
          <div className="flex items-center gap-2">
            <ShieldCheck size={16} className="text-brand-accent" />
            <p className="text-sm font-bold text-brand-dark">Admin Tools</p>
          </div>

          {isLoadingPending ? (
            <div className="mt-4 h-10 animate-pulse rounded-xl bg-soft-gray" />
          ) : pendingMembers.length > 0 ? (
            <div className="mt-4 space-y-3 border-b border-brand-dark/5 pb-4">
              <p className="text-xs font-bold text-brand-dark/40">Pending Requests ({pendingMembers.length})</p>
              {pendingMembers.map((p) => (
                <div key={p.id} className="flex items-center gap-3">
                  <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-brand-pale">
                    <Users size={14} className="text-brand-accent" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-xs font-bold text-brand-dark">{p.first_name || p.last_name ? `${p.first_name} ${p.last_name}`.trim() : `@${p.username}`}</p>
                    <p className="text-[11px] text-brand-dark/40">Requested {formatShortDate(p.joined_at)}</p>
                  </div>
                  <button
                    type="button"
                    disabled={isBusy}
                    onClick={() => handleApprove(p.user_id)}
                    className="rounded-full bg-brand-pale px-3.5 py-1.5 text-xs font-bold text-brand-accent disabled:opacity-50"
                  >
                    Approve
                  </button>
                </div>
              ))}
            </div>
          ) : null}

          <div className="mt-4 flex gap-3">
            {group.status === "gathering" && (
              <button
                type="button"
                disabled={isBusy}
                onClick={() => setShowStartGroup(true)}
                className="flex-1 rounded-full border border-brand-accent py-2.5 text-xs font-bold text-brand-accent disabled:opacity-50"
              >
                Start Group
              </button>
            )}
            <button
              type="button"
              disabled={isBusy}
              onClick={handleRotateCode}
              className="flex-1 rounded-full border border-brand-dark/15 py-2.5 text-xs font-bold text-brand-dark disabled:opacity-50"
            >
              New Invite Code
            </button>
          </div>
          <button
            type="button"
            disabled={isBusy}
            onClick={() => setShowInvite(true)}
            className="mt-3 flex w-full items-center justify-center gap-2 rounded-full py-2.5 text-xs font-bold text-brand-accent disabled:opacity-50"
          >
            <UserPlus size={14} />
            Invite Someone Directly
          </button>
          {group.status === "active" && (
            <button
              type="button"
              disabled={isBusy}
              onClick={handleSendReminders}
              className="flex w-full items-center justify-center gap-2 rounded-full py-2.5 text-xs font-bold text-amber-600 disabled:opacity-50"
            >
              <BellRing size={14} />
              Remind Everyone Who Owes
            </button>
          )}
          <button
            type="button"
            disabled={isBusy}
            onClick={handleTriggerScheduler}
            className="flex w-full items-center justify-center gap-2 rounded-full py-2.5 text-xs font-bold text-blue-500 disabled:opacity-50"
          >
            <Zap size={14} />
            Run Payout Check (Demo)
          </button>
        </div>
      )}

      <div className="mt-6 divide-y divide-brand-dark/5 rounded-card bg-white p-5 shadow-sm">
        <Row label="Contribution Amount" value={`₦${formatAmount(group.contribution_amount)}`} />
        <Row label="Frequency" value={group.cycle_frequency ?? "—"} />
        <Row label="Members" value={`${members.length}${group.member_cap ? ` / ${group.member_cap}` : ""}`} />
        <Row label="Current Round" value={`${group.current_cycle_number}`} />
        <Row label="Pool Balance (this round)" value={`₦${formatAmount(group.pool_balance)}`} />
        <Row label="Next Payout" value={group.next_payout_date ? formatShortDate(group.next_payout_date) : "TBD"} />
        <Row label="Admin" value={admin ? `${admin.first_name} ${admin.last_name}`.trim() : "—"} />
      </div>

      <div className="mt-6 rounded-card bg-white p-5 shadow-sm">
        <p className="text-xs font-bold text-brand-dark/40">Invite Code</p>
        <div className="mt-1.5 flex items-center gap-2">
          <p className="flex-1 font-display text-xl font-bold tracking-widest text-brand-dark">{group.invite_code ?? "—"}</p>
          <button type="button" onClick={copyInviteCode} className="flex h-9 w-9 items-center justify-center rounded-full text-brand-dark/50 hover:bg-soft-gray">
            <Copy size={16} />
          </button>
          <button type="button" onClick={shareInviteLink} className="flex h-9 w-9 items-center justify-center rounded-full text-brand-dark/50 hover:bg-soft-gray">
            <Share2 size={16} />
          </button>
        </div>
      </div>

      {group.member_cap && (
        <div className="mt-6 rounded-card bg-white p-5 shadow-sm">
          <p className="text-xs font-bold text-brand-dark/40">Rules</p>
          <ul className="mt-2.5 space-y-2">
            <li className="flex gap-2.5 text-xs leading-relaxed text-brand-dark/60">
              <span className="mt-1.5 h-1 w-1 shrink-0 rounded-full bg-brand-accent" />
              Group is capped at {group.member_cap} members.
            </li>
          </ul>
        </div>
      )}

      {group.status === "active" && (pendingSwaps.length > 0 || pendingDelegations.length > 0) && (
        <PendingCycleRequestsCard
          groupId={groupId}
          swaps={pendingSwaps}
          delegations={pendingDelegations}
          members={members}
          currentUserId={currentUserId}
          isAdmin={isAdmin}
          onChanged={loadPendingCycleRequests}
        />
      )}

      {group.status === "active" && (
        <div className="mt-6 rounded-card bg-white p-5 shadow-sm">
          <p className="text-xs font-bold text-brand-dark/40">Payout Schedule</p>
          <div className="mt-3">
            {isLoadingRotations ? (
              <div className="h-14 animate-pulse rounded-xl bg-soft-gray" />
            ) : rotations.length === 0 ? (
              <p className="text-xs text-brand-dark/40">No rotation order yet.</p>
            ) : (
              <div className="divide-y divide-brand-dark/5">
                {rotations.map((r) => {
                  const isMine = r.user_id === currentUserId;
                  const canAct = isMine && !r.is_completed;
                  return (
                    <div key={r.cycle_number} className="py-2.5">
                      <div className="flex items-center gap-3">
                        <span
                          className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-[11px] font-bold text-brand-dark ${
                            r.is_current ? "bg-brand" : r.is_completed ? "bg-brand-pale" : "bg-soft-gray"
                          }`}
                        >
                          {r.cycle_number}
                        </span>
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-sm font-semibold text-brand-dark">{`${r.first_name} ${r.last_name}`.trim() || `@${r.username}`}</p>
                          {r.payout_date && (
                            <p className="flex items-center gap-1 text-[11px] text-brand-dark/40">
                              <Calendar size={10} /> {formatShortDate(r.payout_date)}
                            </p>
                          )}
                        </div>
                        <StatusPill label={r.is_current ? "Next" : r.is_completed ? "Paid Out" : "Upcoming"} tone={r.is_current ? "success" : r.is_completed ? "info" : "neutral"} />
                      </div>
                      {canAct && (
                        <div className="mt-1.5 flex gap-4 pl-10">
                          <button
                            type="button"
                            onClick={() => setCycleAction({ entry: r, isDelegate: true })}
                            className="text-xs font-bold text-brand-accent"
                          >
                            Delegate
                          </button>
                          <button
                            type="button"
                            onClick={() => setCycleAction({ entry: r, isDelegate: false })}
                            className="text-xs font-bold text-blue-500"
                          >
                            Swap
                          </button>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      )}

      {group.status === "active" && currentMember && (
        <AutoDebitCard
          groupId={groupId}
          member={currentMember}
          onUpdated={(updated) => setMembers((prev) => prev.map((m) => (m.user_id === updated.user_id ? updated : m)))}
        />
      )}

      <div className="mt-8 space-y-3">
        <Link
          href={group.status === "active" && !hasPaid ? `/groups/${groupId}/contribute` : "#"}
          aria-disabled={!(group.status === "active" && !hasPaid)}
          className={`block w-full rounded-full py-3.5 text-center text-sm font-bold transition-transform ${
            group.status === "active" && !hasPaid
              ? "bg-brand text-brand-dark hover:scale-[1.01] active:scale-95"
              : "pointer-events-none bg-brand/40 text-brand-dark/60"
          }`}
        >
          {group.status !== "active" ? "Contribute (group not started)" : hasPaid ? "Already Contributed" : "Contribute"}
        </Link>
        <button type="button" onClick={() => setShowMembers(true)} className="w-full rounded-full border border-brand-dark/15 py-3.5 text-sm font-bold text-brand-dark">
          View Members
        </button>
        <Link href={`/groups/${groupId}/chat`} className="block w-full rounded-full border border-brand-dark/15 py-3.5 text-center text-sm font-bold text-brand-dark">
          Open Group Chat
        </Link>
      </div>

      {showMembers && (
        <Modal title={`Members (${members.length})`} onClose={() => setShowMembers(false)}>
          <div className="max-h-96 divide-y divide-brand-dark/5 overflow-y-auto">
            {membersSortedForList(members, group.status).map((m) => {
              // "Active" is the default, expected state — only worth a badge when
              // the role or status says something you wouldn't already assume.
              const roleLabel = m.is_admin ? "Admin" : m.status !== "active" ? m.status : null;
              return (
                <div key={m.id} className="py-3">
                  <div className="flex items-center gap-3">
                    <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand-pale font-display text-sm font-bold text-brand-accent">
                      {m.first_name?.[0]?.toUpperCase() ?? "?"}
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-bold text-brand-dark">{`${m.first_name} ${m.last_name}`.trim()}</p>
                      <p className="text-xs text-brand-dark/40">@{m.username}</p>
                    </div>
                    {roleLabel && <StatusPill label={roleLabel} tone={m.is_admin ? "info" : "warning"} />}
                  </div>
                  {group.status === "active" && (
                    <div className="mt-2 flex items-center gap-2 pl-[50px]">
                      <StatusPill label={m.has_paid_current_cycle ? "Paid" : "Owes"} tone={m.has_paid_current_cycle ? "success" : "danger"} />
                      <div className="flex-1" />
                      {isAdmin && !m.is_admin && (
                        <button
                          type="button"
                          disabled={remindingUserId === m.user_id}
                          onClick={() => handleRemindMember(m.user_id, `${m.first_name} ${m.last_name}`.trim())}
                          className="flex items-center gap-1 text-xs font-bold text-amber-600 hover:text-amber-700 disabled:opacity-40"
                        >
                          <BellRing size={13} />
                          Remind
                        </button>
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </Modal>
      )}

      {showEdit && (
        <EditGroupModal
          group={group}
          onClose={() => setShowEdit(false)}
          onSaved={(updated) => {
            setGroup(updated);
            setShowEdit(false);
            showToast("Group updated");
          }}
        />
      )}

      {showInvite && (
        <SendInviteModal
          groupId={groupId}
          onClose={() => setShowInvite(false)}
          onSent={() => {
            setShowInvite(false);
            setShowInviteSuccess(true);
          }}
        />
      )}

      {showInviteSuccess && (
        <SuccessModal
          title="Invite Sent"
          subtitle="They'll see it under their invites and can join the group once they accept."
          onPrimary={() => setShowInviteSuccess(false)}
        />
      )}

      {showStartGroup && <StartGroupModal members={members} onClose={() => setShowStartGroup(false)} onStart={handleStartGroup} />}

      {cycleAction && (
        <CycleActionModal
          groupId={groupId}
          myEntry={cycleAction.entry}
          otherEntries={rotations.filter((r) => r.user_id !== currentUserId && !r.is_completed)}
          isDelegate={cycleAction.isDelegate}
          onClose={() => setCycleAction(null)}
          onSent={() => {
            setCycleAction(null);
            showToast(cycleAction.isDelegate ? "Delegation request sent" : "Swap request sent");
          }}
        />
      )}
    </div>
  );
}

/** For an active group, members who still owe this round sort first — that's the list an admin actually wants when deciding who to remind. */
function membersSortedForList(members: GroupMember[], groupStatus: string): GroupMember[] {
  if (groupStatus !== "active") return members;
  return [...members].sort((a, b) => Number(a.has_paid_current_cycle) - Number(b.has_paid_current_cycle));
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between py-3">
      <span className="text-xs font-semibold text-brand-dark/50">{label}</span>
      <span className="font-display text-sm font-bold text-brand-dark">{value}</span>
    </div>
  );
}
