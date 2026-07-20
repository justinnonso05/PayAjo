"use client";

import { ArrowLeftRight } from "lucide-react";
import { useState } from "react";
import { PinConfirmModal } from "@/components/app/pin-confirm-modal";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";
import type { CycleDelegationRequest, CycleSwapRequest, GroupMember } from "@/lib/types";

type PendingAction =
  | { kind: "respond-swap"; swap: CycleSwapRequest; accept: boolean }
  | { kind: "approve-swap"; swap: CycleSwapRequest; approve: boolean }
  | { kind: "approve-delegation"; delegation: CycleDelegationRequest; approve: boolean };

export function PendingCycleRequestsCard({
  groupId,
  swaps,
  delegations,
  members,
  currentUserId,
  isAdmin,
  onChanged,
}: {
  groupId: string;
  swaps: CycleSwapRequest[];
  delegations: CycleDelegationRequest[];
  members: GroupMember[];
  currentUserId: string | null;
  isAdmin: boolean;
  onChanged: () => void;
}) {
  const [pendingAction, setPendingAction] = useState<PendingAction | null>(null);
  const [error, setError] = useState<string | null>(null);

  const memberName = (userId: string) => {
    const m = members.find((m) => m.user_id === userId);
    return m ? `${m.first_name} ${m.last_name}`.trim() : "Member";
  };

  const handleConfirm = async (pin: string) => {
    if (!pendingAction) return;
    setError(null);
    try {
      if (pendingAction.kind === "respond-swap") {
        await api.post(endpoints.respondSwap(groupId, pendingAction.swap.id), { accept: pendingAction.accept, pin }, authHeaders());
      } else if (pendingAction.kind === "approve-swap") {
        await api.post(endpoints.approveSwap(groupId, pendingAction.swap.id), { approve: pendingAction.approve, pin }, authHeaders());
      } else {
        await api.post(endpoints.approveDelegation(groupId, pendingAction.delegation.id), { approve: pendingAction.approve, pin }, authHeaders());
      }
      setPendingAction(null);
      onChanged();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
    }
  };

  if (swaps.length === 0 && delegations.length === 0) return null;

  return (
    <div className="mt-6 rounded-card border border-brand-pale bg-white p-5 shadow-sm">
      <div className="flex items-center gap-2">
        <ArrowLeftRight size={16} className="text-brand-accent" />
        <p className="text-sm font-bold text-brand-dark">Pending Requests</p>
      </div>

      <div className="mt-4 space-y-3">
        {swaps.map((swap) => {
          const isTargetingMe = swap.target_member_id === currentUserId && swap.status === "pending_counterpart";
          const needsAdminApproval = isAdmin && swap.status === "pending_admin_approval";

          if (!isTargetingMe && !needsAdminApproval) {
            return (
              <div key={swap.id} className="rounded-2xl bg-soft-gray p-3 text-xs leading-relaxed text-brand-dark/60">
                {memberName(swap.initiator_member_id)} wants to swap cycle {swap.initiator_cycle_number} with {memberName(swap.target_member_id)}&apos;s cycle{" "}
                {swap.target_cycle_number} — awaiting response.
              </div>
            );
          }

          return (
            <div key={swap.id} className="rounded-2xl bg-soft-gray p-3">
              <p className="text-xs font-semibold leading-relaxed text-brand-dark">
                {needsAdminApproval
                  ? `Swap needs your approval: ${memberName(swap.initiator_member_id)} (cycle ${swap.initiator_cycle_number}) ↔ ${memberName(swap.target_member_id)} (cycle ${swap.target_cycle_number})`
                  : `${memberName(swap.initiator_member_id)} wants to swap their cycle ${swap.initiator_cycle_number} for your cycle ${swap.target_cycle_number}.`}
              </p>
              <div className="mt-2.5 flex gap-2.5">
                <button
                  type="button"
                  onClick={() =>
                    setPendingAction(isTargetingMe ? { kind: "respond-swap", swap, accept: true } : { kind: "approve-swap", swap, approve: true })
                  }
                  className="rounded-full bg-brand-pale px-3.5 py-1.5 text-xs font-bold text-brand-accent"
                >
                  Accept
                </button>
                <button
                  type="button"
                  onClick={() =>
                    setPendingAction(isTargetingMe ? { kind: "respond-swap", swap, accept: false } : { kind: "approve-swap", swap, approve: false })
                  }
                  className="rounded-full bg-red-50 px-3.5 py-1.5 text-xs font-bold text-red-500"
                >
                  Decline
                </button>
              </div>
            </div>
          );
        })}

        {delegations.map((delegation) => (
          <div key={delegation.id} className="rounded-2xl bg-soft-gray p-3">
            <p className="text-xs font-semibold leading-relaxed text-brand-dark">
              Delegation needs your approval: {memberName(delegation.from_member_id)} → {memberName(delegation.to_member_id)} for cycle {delegation.cycle_number}.
            </p>
            <div className="mt-2.5 flex gap-2.5">
              <button
                type="button"
                onClick={() => setPendingAction({ kind: "approve-delegation", delegation, approve: true })}
                className="rounded-full bg-brand-pale px-3.5 py-1.5 text-xs font-bold text-brand-accent"
              >
                Approve
              </button>
              <button
                type="button"
                onClick={() => setPendingAction({ kind: "approve-delegation", delegation, approve: false })}
                className="rounded-full bg-red-50 px-3.5 py-1.5 text-xs font-bold text-red-500"
              >
                Decline
              </button>
            </div>
          </div>
        ))}
      </div>

      {error && <p className="mt-3 text-xs font-semibold text-red-500">{error}</p>}

      {pendingAction && (
        <PinConfirmModal
          title={pendingAction.kind === "approve-delegation" ? "Confirm Delegation Decision" : "Confirm Swap Decision"}
          subtitle="Confirm with your PIN."
          onConfirm={handleConfirm}
          onClose={() => setPendingAction(null)}
        />
      )}
    </div>
  );
}
