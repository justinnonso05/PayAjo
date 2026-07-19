"use client";

import { useState } from "react";
import { PinConfirmModal } from "@/components/app/pin-confirm-modal";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";
import type { GroupMember } from "@/lib/types";

const DAY_OPTIONS = [1, 2, 3];

/** Lets a member turn on auto-debit for their own contribution to this group —
 * mirrors the mobile app's equivalent card. Every change is PIN-confirmed
 * since it authorizes the backend to pull money from the wallet on its own. */
export function AutoDebitCard({
  groupId,
  member,
  onUpdated,
}: {
  groupId: string;
  member: GroupMember;
  onUpdated: (member: GroupMember) => void;
}) {
  const [daysBefore, setDaysBefore] = useState(member.auto_debit_days_before);
  const [pending, setPending] = useState<{ enabled: boolean; daysBefore: number } | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const enabled = member.auto_debit_enabled;

  const handleConfirm = async (pin: string) => {
    if (!pending) return;
    setIsSaving(true);
    setError(null);
    try {
      const res = await api.post(
        endpoints.autoDebit(groupId),
        { enabled: pending.enabled, days_before: pending.daysBefore, pin },
        authHeaders(),
      );
      onUpdated(res.data as GroupMember);
      setDaysBefore(pending.daysBefore);
      setPending(null);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="mt-6 rounded-card bg-white p-5 shadow-sm">
      <div className="flex items-center justify-between gap-3">
        <p className="text-xs font-bold text-brand-dark/40">Auto-Debit</p>
        <button
          type="button"
          role="switch"
          aria-checked={enabled}
          disabled={isSaving}
          onClick={() => setPending({ enabled: !enabled, daysBefore })}
          className={`relative h-6 w-11 shrink-0 rounded-full transition-colors disabled:opacity-50 ${enabled ? "bg-brand-accent" : "bg-soft-gray"}`}
        >
          <span
            className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-transform ${enabled ? "translate-x-[22px]" : "translate-x-0.5"}`}
          />
        </button>
      </div>
      <p className="mt-1.5 text-xs leading-relaxed text-brand-dark/55">
        Automatically pay this group&apos;s contribution from your wallet before each payout.
      </p>

      {enabled && (
        <div className="mt-4">
          <p className="text-[11px] font-bold text-brand-dark/40">Debit this many days before payout</p>
          <div className="mt-2 flex gap-2">
            {DAY_OPTIONS.map((days) => (
              <button
                key={days}
                type="button"
                disabled={isSaving}
                onClick={() => setPending({ enabled: true, daysBefore: days })}
                className={`rounded-full border px-3.5 py-1.5 text-xs font-bold disabled:opacity-50 ${
                  daysBefore === days ? "border-brand-accent bg-brand-pale text-brand-accent" : "border-brand-dark/15 text-brand-dark/60"
                }`}
              >
                {days} day{days === 1 ? "" : "s"}
              </button>
            ))}
          </div>
        </div>
      )}

      {error && <p className="mt-3 text-xs font-semibold text-red-500">{error}</p>}

      {pending && (
        <PinConfirmModal
          title={pending.enabled ? "Enable Auto-Debit" : "Turn Off Auto-Debit"}
          subtitle={
            pending.enabled
              ? `Confirm with your PIN. We'll pay this group's contribution from your wallet automatically, ${pending.daysBefore} day${pending.daysBefore === 1 ? "" : "s"} before payout, as long as you haven't already paid.`
              : "Confirm with your PIN to stop automatic contributions for this group."
          }
          onConfirm={handleConfirm}
          onClose={() => setPending(null)}
        />
      )}
    </div>
  );
}
