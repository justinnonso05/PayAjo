"use client";

import { Copy, Pencil, Share2, ShieldCheck, UserPlus, Users } from "lucide-react";
import Link from "next/link";
import { use, useState } from "react";
import { Modal } from "@/components/app/modal";
import { StatusPill } from "@/components/app/status-pill";
import { hasPaidCurrentRound } from "@/lib/contribution-status";
import { formatAmount, formatShortDate } from "@/lib/format";
import { useGroup } from "@/lib/hooks/use-group";
import { useWalletTransactions } from "@/lib/hooks/use-wallet-transactions";
import { SHORTFALL_POLICY_DESCRIPTIONS } from "@/lib/types";
import { EditGroupModal } from "./edit-group-modal";
import { SendInviteModal } from "./send-invite-modal";

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
  } = useGroup(groupId);
  const { items: transactions } = useWalletTransactions();

  const [isBusy, setIsBusy] = useState(false);
  const [busyError, setBusyError] = useState<string | null>(null);
  const [showMembers, setShowMembers] = useState(false);
  const [showEdit, setShowEdit] = useState(false);
  const [showInvite, setShowInvite] = useState(false);
  const [toast, setToast] = useState<string | null>(null);

  const showToast = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(null), 3000);
  };

  if (isLoading) return <div className="mx-auto max-w-3xl px-6 py-10"><div className="h-96 animate-pulse rounded-card bg-white" /></div>;
  if (error || !group) return <div className="mx-auto max-w-3xl px-6 py-10 text-sm text-brand-dark/50">{error || "Couldn't load this group."}</div>;

  const hasPaid = hasPaidCurrentRound(group, transactions);
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

  const handleStartGroup = async () => {
    if (!confirm("Start this group? This locks in the payout rotation order and begins the first contribution cycle. This cannot be undone.")) return;
    setIsBusy(true);
    try {
      await startGroup();
      showToast("Group started!");
    } catch (err) {
      setBusyError(err instanceof Error ? err.message : "Something went wrong.");
    } finally {
      setIsBusy(false);
    }
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
                onClick={handleStartGroup}
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
        </div>
      )}

      <div className="mt-6 divide-y divide-brand-dark/5 rounded-card bg-white p-5 shadow-sm">
        <Row label="Contribution Amount" value={`₦${formatAmount(group.contribution_amount)}`} />
        <Row label="Frequency" value={group.cycle_frequency ?? "—"} />
        <Row label="Members" value={`${members.length}${group.member_cap ? ` / ${group.member_cap}` : ""}`} />
        <Row label="Current Round" value={`${group.current_cycle_number}`} />
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

      <div className="mt-6 rounded-card bg-white p-5 shadow-sm">
        <p className="text-xs font-bold text-brand-dark/40">Rules</p>
        <ul className="mt-2.5 space-y-2">
          <li className="flex gap-2.5 text-xs leading-relaxed text-brand-dark/60">
            <span className="mt-1.5 h-1 w-1 shrink-0 rounded-full bg-brand-accent" />
            {group.shortfall_policy ? SHORTFALL_POLICY_DESCRIPTIONS[group.shortfall_policy] : "Shortfall policy not set."}
          </li>
          {group.member_cap && (
            <li className="flex gap-2.5 text-xs leading-relaxed text-brand-dark/60">
              <span className="mt-1.5 h-1 w-1 shrink-0 rounded-full bg-brand-accent" />
              Group is capped at {group.member_cap} members.
            </li>
          )}
        </ul>
      </div>

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
        <button
          type="button"
          onClick={() => alert(isAdmin ? "As the admin, you need to transfer group ownership to another member before you can leave." : "Leaving a group is coming soon")}
          className="w-full rounded-full bg-red-50 py-3.5 text-sm font-bold text-red-500"
        >
          Leave Group
        </button>
      </div>

      {showMembers && (
        <Modal title={`Members (${members.length})`} onClose={() => setShowMembers(false)}>
          <div className="max-h-96 divide-y divide-brand-dark/5 overflow-y-auto">
            {members.map((m) => (
              <div key={m.id} className="flex items-center gap-3 py-3">
                <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand-pale font-display text-sm font-bold text-brand-accent">
                  {m.first_name?.[0]?.toUpperCase() ?? "?"}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-bold text-brand-dark">{`${m.first_name} ${m.last_name}`.trim()}</p>
                  <p className="text-xs text-brand-dark/40">@{m.username}</p>
                </div>
                {m.is_admin ? (
                  <StatusPill label="Admin" tone="info" />
                ) : (
                  <StatusPill label={m.status === "active" ? "Active" : m.status} tone={m.status === "active" ? "success" : "warning"} />
                )}
              </div>
            ))}
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
            showToast("Invite sent");
          }}
        />
      )}
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between py-3">
      <span className="text-xs font-semibold text-brand-dark/50">{label}</span>
      <span className="font-display text-sm font-bold text-brand-dark">{value}</span>
    </div>
  );
}
