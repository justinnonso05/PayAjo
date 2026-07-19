"use client";

import { Lock } from "lucide-react";
import { useState } from "react";
import { Modal } from "@/components/app/modal";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";
import type { Group } from "@/lib/types";

export function EditGroupModal({ group, onClose, onSaved }: { group: Group; onClose: () => void; onSaved: (group: Group) => void }) {
  // Once a group is active, the backend locks anything that would break the
  // math or scheduling for members already mid-rotation — contribution
  // amount, cycle frequency, payout day/month, and payout time. Name and
  // member cap stay editable throughout.
  const isFinancialsLocked = group.status === "active";

  const [name, setName] = useState(group.name);
  const [amount, setAmount] = useState(String(group.contribution_amount));
  const [payoutTime, setPayoutTime] = useState("");
  const [memberCap, setMemberCap] = useState(group.member_cap ? String(group.member_cap) : "");
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async () => {
    const parsedAmount = parseFloat(amount);
    if (!name.trim() || (!isFinancialsLocked && (!parsedAmount || parsedAmount <= 0))) {
      setError("Enter a valid group name and amount");
      return;
    }

    setIsSubmitting(true);
    setError(null);
    try {
      const res = await api.patch(
        endpoints.group(group.id),
        {
          name: name.trim(),
          member_cap: memberCap.trim() ? parseInt(memberCap, 10) : null,
          // Once active, the backend rejects any change to these — so
          // they're just never sent rather than surfacing a confusing
          // "silent" failure.
          ...(isFinancialsLocked ? {} : { contribution_amount: parsedAmount }),
          ...(!isFinancialsLocked && payoutTime ? { payout_time: `${payoutTime}:00Z` } : {}),
        },
        authHeaders(),
      );
      onSaved(res.data as Group);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal title="Edit Group" onClose={onClose}>
      <div className="space-y-4">
        {isFinancialsLocked && (
          <div className="flex items-start gap-2.5 rounded-2xl bg-brand-pale p-3.5">
            <Lock size={15} className="mt-0.5 shrink-0 text-brand-accent" />
            <p className="text-xs leading-relaxed text-brand-dark/70">
              This group is active, so the contribution amount and payout time are locked to keep payouts fair for everyone already in the rotation. Finish
              this round, then start a new group to change them.
            </p>
          </div>
        )}
        <Field label="Group Name">
          <input value={name} onChange={(e) => setName(e.target.value)} className="w-full rounded-xl border border-brand-dark/15 px-4 py-3 text-sm outline-none focus:border-brand-dark" />
        </Field>
        <Field label="Contribution Amount">
          <div className={`flex items-center rounded-xl border border-brand-dark/15 px-4 py-3 ${isFinancialsLocked ? "bg-soft-gray" : ""}`}>
            <span className="mr-1 text-sm text-brand-dark/50">₦</span>
            <input
              type="number"
              value={amount}
              disabled={isFinancialsLocked}
              onChange={(e) => setAmount(e.target.value)}
              className="w-full text-sm outline-none disabled:text-brand-dark/40"
            />
            {isFinancialsLocked && <Lock size={14} className="text-brand-dark/30" />}
          </div>
        </Field>
        <Field label="Payout Time (optional)">
          <div className={`flex items-center rounded-xl border border-brand-dark/15 ${isFinancialsLocked ? "bg-soft-gray" : ""}`}>
            <input
              type="time"
              value={payoutTime}
              disabled={isFinancialsLocked}
              onChange={(e) => setPayoutTime(e.target.value)}
              className="w-full px-4 py-3 text-sm outline-none disabled:text-brand-dark/40"
            />
            {isFinancialsLocked && <Lock size={14} className="mr-4 text-brand-dark/30" />}
          </div>
        </Field>
        <Field label="Maximum Members (optional)">
          <input
            type="number"
            value={memberCap}
            onChange={(e) => setMemberCap(e.target.value)}
            className="w-full rounded-xl border border-brand-dark/15 px-4 py-3 text-sm outline-none focus:border-brand-dark"
          />
        </Field>

        {error && <p className="text-xs font-semibold text-red-500">{error}</p>}

        <button
          type="button"
          onClick={handleSubmit}
          disabled={isSubmitting}
          className="w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark transition-transform hover:scale-[1.02] active:scale-95 disabled:opacity-60"
        >
          {isSubmitting ? "Saving…" : "Save Changes"}
        </button>
      </div>
    </Modal>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="mb-1.5 block text-xs font-bold text-brand-dark">{label}</label>
      {children}
    </div>
  );
}
