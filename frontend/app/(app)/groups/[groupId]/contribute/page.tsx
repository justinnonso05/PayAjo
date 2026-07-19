"use client";

import { CheckCircle2, Hourglass } from "lucide-react";
import { useRouter } from "next/navigation";
import { use, useEffect, useState } from "react";
import { PinConfirmModal } from "@/components/app/pin-confirm-modal";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";
import { hasPaidCurrentRound } from "@/lib/contribution-status";
import { formatAmount } from "@/lib/format";
import { useProfile } from "@/lib/hooks/use-profile";
import { useWalletTransactions } from "@/lib/hooks/use-wallet-transactions";
import type { DirectPaymentDetails, Group } from "@/lib/types";

export default function ContributePage({ params }: { params: Promise<{ groupId: string }> }) {
  const { groupId } = use(params);
  const router = useRouter();
  const { profile } = useProfile();
  const { items: transactions, refresh: refreshTransactions } = useWalletTransactions();

  const [group, setGroup] = useState<Group | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showPin, setShowPin] = useState(false);
  const [isGeneratingDirectPayment, setIsGeneratingDirectPayment] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  useEffect(() => {
    api
      .get(endpoints.group(groupId), authHeaders())
      .then((res) => setGroup(res.data as Group))
      .catch((err) => setError(err instanceof ApiError ? err.message : "Couldn't load this group."))
      .finally(() => setIsLoading(false));
  }, [groupId]);

  if (isLoading) return <div className="mx-auto max-w-md px-6 py-10"><div className="h-72 animate-pulse rounded-card bg-white" /></div>;
  if (error || !group) return <div className="mx-auto max-w-md px-6 py-10 text-sm text-brand-dark/50">{error || "Couldn't load this group."}</div>;

  const balance = parseFloat(profile?.wallet_balance ?? "0") || 0;
  const isGroupActive = group.status === "active";
  const hasPaid = hasPaidCurrentRound(group, transactions);
  const canPay = balance >= group.contribution_amount;

  const handlePayByBankTransfer = async () => {
    setIsGeneratingDirectPayment(true);
    setActionError(null);
    try {
      const res = await api.post(endpoints.generateDirectPayment(groupId), {}, authHeaders());
      sessionStorage.setItem(`direct-payment-${groupId}`, JSON.stringify(res.data as DirectPaymentDetails));
      router.push(`/groups/${groupId}/direct-payment`);
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
    } finally {
      setIsGeneratingDirectPayment(false);
    }
  };

  const handlePinConfirm = async (pin: string) => {
    try {
      await api.post(endpoints.payFromWallet(groupId), { pin }, authHeaders());
      await refreshTransactions();
      setShowPin(false);
      router.push(`/groups/${groupId}`);
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
      setShowPin(false);
    }
  };

  return (
    <div className="mx-auto max-w-md px-6 py-8 sm:py-10">
      <h1 className="font-display text-xl font-bold text-brand-dark">Contribute</h1>

      <div className="mt-6 rounded-card bg-gradient-to-br from-brand to-brand-accent p-6">
        <p className="text-xs font-semibold text-brand-dark/70">{group.name}</p>
        <p className="mt-1 font-display text-3xl font-extrabold text-brand-dark">₦{formatAmount(group.contribution_amount)}</p>
        <p className="text-xs font-semibold text-brand-dark/70">Round {group.current_cycle_number} • {group.cycle_frequency ?? "—"}</p>
      </div>

      <div className="mt-6">
        {hasPaid ? (
          <Notice icon="check" text="You've already contributed for this round. No need to pay again." />
        ) : !isGroupActive ? (
          <Notice icon="hourglass" text="This group hasn't started yet. The admin needs to start the rotation before contributions can be made." />
        ) : (
          <div className="flex items-center justify-between rounded-card bg-white px-5 py-4 shadow-sm">
            <span className="text-sm font-semibold text-brand-dark/50">Wallet balance</span>
            <span className="font-display text-sm font-bold text-brand-dark">₦{formatAmount(balance)}</span>
          </div>
        )}
      </div>

      {actionError && <p className="mt-4 text-sm font-semibold text-red-500">{actionError}</p>}

      {!hasPaid && isGroupActive && (
        <div className="mt-8 space-y-3">
          {canPay && (
            <button
              type="button"
              onClick={() => setShowPin(true)}
              className="w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark transition-transform hover:scale-[1.02] active:scale-95"
            >
              Pay from Wallet
            </button>
          )}
          <button
            type="button"
            disabled={isGeneratingDirectPayment}
            onClick={handlePayByBankTransfer}
            className={`w-full rounded-full py-3.5 text-sm font-bold transition-transform disabled:opacity-60 ${
              canPay ? "border border-brand-dark/15 text-brand-dark" : "bg-brand text-brand-dark hover:scale-[1.02] active:scale-95"
            }`}
          >
            {isGeneratingDirectPayment ? "Generating…" : "Pay by Bank Transfer"}
          </button>
          {!canPay && (
            <p className="text-center text-xs text-brand-dark/50">You don&apos;t have enough in your wallet for this contribution yet.</p>
          )}
        </div>
      )}

      {showPin && (
        <PinConfirmModal
          title="Confirm Contribution"
          subtitle={`Enter your PIN to pay ₦${formatAmount(group.contribution_amount)} from your wallet.`}
          onConfirm={handlePinConfirm}
          onClose={() => setShowPin(false)}
        />
      )}
    </div>
  );
}

function Notice({ icon, text }: { icon: "check" | "hourglass"; text: string }) {
  const Icon = icon === "check" ? CheckCircle2 : Hourglass;
  return (
    <div className="flex items-center gap-3 rounded-card bg-brand-pale px-5 py-4">
      <Icon size={18} className="shrink-0 text-brand-accent" />
      <p className="text-sm font-semibold text-brand-dark">{text}</p>
    </div>
  );
}
