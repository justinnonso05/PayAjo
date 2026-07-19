"use client";

import { ArrowDownRight, ArrowUpRight, Bolt, Building2, CheckCircle2, Copy, Info, PlusCircle, Receipt, RefreshCcw } from "lucide-react";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { EmptyState } from "@/components/app/empty-state";
import { Modal } from "@/components/app/modal";
import { PinConfirmModal } from "@/components/app/pin-confirm-modal";
import { SectionHeader } from "@/components/app/section-header";
import { SuccessModal } from "@/components/app/success-modal";
import { TransactionReceiptModal } from "@/components/app/transaction-receipt-modal";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";
import { formatAmount, formatShortDate } from "@/lib/format";
import { useProfile } from "@/lib/hooks/use-profile";
import { useWalletTransactions } from "@/lib/hooks/use-wallet-transactions";
import { isCreditTransaction, type UserByAccount } from "@/lib/types";

export default function WalletPage() {
  const { profile, refresh: refreshProfile } = useProfile();
  const { items: transactions, refresh: refreshTransactions } = useWalletTransactions();
  const [showAddMoney, setShowAddMoney] = useState(false);
  const [showWithdraw, setShowWithdraw] = useState(false);
  const [showTransfer, setShowTransfer] = useState(false);
  const [showNoPayoutBank, setShowNoPayoutBank] = useState(false);
  const [openTransactionId, setOpenTransactionId] = useState<string | null>(null);

  const balance = parseFloat(profile?.wallet_balance ?? "0") || 0;

  const handleWithdrawClick = () => {
    if (!profile?.payout_bank_account_number) {
      setShowNoPayoutBank(true);
      return;
    }
    setShowWithdraw(true);
  };

  return (
    <div className="mx-auto max-w-5xl px-6 py-8 sm:px-10 sm:py-10">
      <h1 className="font-display text-2xl font-bold text-brand-dark">Wallet</h1>

      <div className="mt-6 rounded-card bg-gradient-to-br from-brand-dark to-[#2e5211] p-7 shadow-[0_20px_50px_rgba(29,49,8,0.3)]">
        <p className="text-xs font-bold uppercase tracking-wider text-white/60">Wallet Balance</p>
        <p className="mt-2 font-display text-4xl font-extrabold text-white">₦{formatAmount(balance)}</p>

        <div className="mt-6 grid grid-cols-3 gap-3">
          <button type="button" onClick={() => setShowAddMoney(true)} className="flex flex-col items-center gap-1.5 rounded-2xl bg-white/15 py-3 text-white transition-colors hover:bg-white/25">
            <PlusCircle size={18} />
            <span className="text-xs font-bold">Add Money</span>
          </button>
          <button type="button" onClick={handleWithdrawClick} className="flex flex-col items-center gap-1.5 rounded-2xl bg-white/15 py-3 text-white transition-colors hover:bg-white/25">
            <ArrowUpRight size={18} />
            <span className="text-xs font-bold">Withdraw</span>
          </button>
          <button
            type="button"
            onClick={() => setShowTransfer(true)}
            className="flex flex-col items-center gap-1.5 rounded-2xl bg-white/15 py-3 text-white transition-colors hover:bg-white/25"
          >
            <RefreshCcw size={18} />
            <span className="text-xs font-bold">Transfer</span>
          </button>
        </div>
      </div>

      {profile?.personal_reserved_account_number && (
        <>
          <div className="mt-8 space-y-3">
            <SectionHeader title="Virtual Account" />
            <div className="flex items-center gap-4 rounded-card bg-white p-5 shadow-sm">
              <div className="min-w-0 flex-1">
                <p className="text-xs text-brand-dark/50">{profile.personal_reserved_account_bank || "—"}</p>
                <p className="font-display text-lg font-bold text-brand-dark">{profile.personal_reserved_account_number}</p>
                <p className="text-xs text-brand-dark/40">{profile.personal_reserved_account_name || "—"}</p>
              </div>
              <button
                type="button"
                onClick={() => navigator.clipboard.writeText(profile.personal_reserved_account_number!)}
                className="flex h-9 w-9 items-center justify-center rounded-full text-brand-dark/50 hover:bg-soft-gray"
              >
                <Copy size={16} />
              </button>
            </div>
          </div>

          <div className="mt-8 space-y-3">
            <SectionHeader title="Funding Methods" />
            <div className="space-y-3">
              <MethodTile
                icon={Building2}
                title="Fund wallet via bank transfer"
                subtitle="Send money to your personal virtual account above. It lands in your wallet automatically."
              />
            </div>
          </div>
        </>
      )}

      <div className="mt-8 space-y-3">
        <SectionHeader title="Transaction History" />
        {transactions.length === 0 ? (
          <div className="rounded-card bg-white shadow-sm">
            <EmptyState icon={Receipt} title="No transactions yet." subtitle="Deposits, withdrawals, and contributions will show up here." />
          </div>
        ) : (
          <div className="divide-y divide-brand-dark/5 rounded-card bg-white shadow-sm">
            {transactions.map((tx) => {
              const credit = isCreditTransaction(tx);
              return (
                <button
                  key={tx.id}
                  type="button"
                  onClick={() => setOpenTransactionId(tx.id)}
                  className="flex w-full items-center gap-3 px-5 py-4 text-left transition-colors hover:bg-soft-gray"
                >
                  <span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full ${credit ? "bg-brand-pale" : "bg-amber-50"}`}>
                    {credit ? <ArrowDownRight size={16} className="text-brand-accent" /> : <ArrowUpRight size={16} className="text-amber-600" />}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-bold text-brand-dark">{tx.narration || tx.type}</p>
                    <p className="text-xs text-brand-dark/40">{formatShortDate(tx.created_at)}</p>
                  </div>
                  <p className={`text-sm font-bold ${credit ? "text-brand-accent" : "text-brand-dark"}`}>
                    {credit ? "+" : "-"}₦{formatAmount(Math.abs(tx.amount))}
                  </p>
                </button>
              );
            })}
          </div>
        )}
      </div>

      {showAddMoney && (
        <Modal title="Add Money" onClose={() => setShowAddMoney(false)}>
          <p className="text-sm text-brand-dark/55">Transfer any amount to this account. It lands in your wallet automatically once the bank confirms it.</p>
          {profile?.personal_reserved_account_number ? (
            <div className="mt-5 rounded-2xl bg-brand-pale p-4">
              <p className="text-xs font-semibold text-brand-dark/70">{profile.personal_reserved_account_bank || "—"}</p>
              <div className="mt-1.5 flex items-center justify-between">
                <p className="font-display text-2xl font-bold tracking-wide text-brand-dark">{profile.personal_reserved_account_number}</p>
                <button
                  type="button"
                  onClick={() => navigator.clipboard.writeText(profile.personal_reserved_account_number!)}
                  className="flex h-9 w-9 items-center justify-center rounded-full text-brand-accent hover:bg-white/50"
                >
                  <Copy size={16} />
                </button>
              </div>
              {profile.personal_reserved_account_name && <p className="mt-1 text-xs text-brand-dark/50">{profile.personal_reserved_account_name}</p>}
            </div>
          ) : (
            <p className="mt-5 text-sm text-brand-dark/40">No virtual account on file yet.</p>
          )}
          <div className="mt-4 flex items-start gap-2">
            <Info size={14} className="mt-0.5 shrink-0 text-brand-dark/40" />
            <p className="text-xs leading-relaxed text-brand-dark/50">This is your personal account. Money sent here always goes to your AjoPay wallet, not a specific group.</p>
          </div>
        </Modal>
      )}

      {showNoPayoutBank && (
        <Modal title="Set up a payout bank first" onClose={() => setShowNoPayoutBank(false)}>
          <p className="text-sm text-brand-dark/55">Withdrawals need a bank account on file. This only takes a minute to set up.</p>
          <div className="mt-5 flex justify-end gap-3">
            <button type="button" onClick={() => setShowNoPayoutBank(false)} className="rounded-full px-4 py-2 text-sm font-bold text-brand-dark/50">
              Cancel
            </button>
            <Link
              href="/wallet/payout-bank"
              className="rounded-full bg-brand px-5 py-2 text-sm font-bold text-brand-dark transition-transform hover:scale-105"
            >
              Set Up
            </Link>
          </div>
        </Modal>
      )}

      {openTransactionId && (
        <TransactionReceiptModal transactionId={openTransactionId} onClose={() => setOpenTransactionId(null)} />
      )}

      {showWithdraw && profile && (
        <WithdrawFlow
          balance={balance}
          onClose={() => setShowWithdraw(false)}
          onSuccess={async () => {
            setShowWithdraw(false);
            await Promise.all([refreshProfile(), refreshTransactions()]);
          }}
        />
      )}

      {showTransfer && (
        <TransferFlow
          balance={balance}
          onClose={() => setShowTransfer(false)}
          onSuccess={async () => {
            setShowTransfer(false);
            await Promise.all([refreshProfile(), refreshTransactions()]);
          }}
        />
      )}
    </div>
  );
}

function MethodTile({ icon: Icon, title, subtitle }: { icon: typeof Bolt; title: string; subtitle: string }) {
  return (
    <div className="flex items-start gap-3 rounded-card bg-white p-4 shadow-sm">
      <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand-pale">
        <Icon size={16} className="text-brand-accent" />
      </span>
      <div>
        <p className="text-sm font-bold text-brand-dark">{title}</p>
        <p className="mt-0.5 text-xs leading-relaxed text-brand-dark/50">{subtitle}</p>
      </div>
    </div>
  );
}

function WithdrawFlow({ balance, onClose, onSuccess }: { balance: number; onClose: () => void; onSuccess: () => void }) {
  const [stage, setStage] = useState<"amount" | "pin" | "success">("amount");
  const [amount, setAmount] = useState("");
  const [error, setError] = useState<string | null>(null);

  const handleContinue = () => {
    const value = parseFloat(amount);
    if (!value || value <= 0) return;
    setError(null);
    setStage("pin");
  };

  const handleConfirm = async (pin: string) => {
    const value = parseFloat(amount);
    try {
      await api.post(endpoints.walletWithdraw, { amount: value, pin }, authHeaders());
      setStage("success");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
      setStage("amount");
    }
  };

  if (stage === "success") {
    return (
      <SuccessModal
        title="Withdrawal Successful"
        subtitle={`₦${formatAmount(parseFloat(amount) || 0)} is on its way to your payout bank.`}
        onPrimary={onSuccess}
      />
    );
  }

  if (stage === "pin") {
    return (
      <PinConfirmModal
        title="Confirm Withdrawal"
        subtitle={`Enter your PIN to withdraw ₦${formatAmount(parseFloat(amount) || 0)}.`}
        onConfirm={handleConfirm}
        onClose={onClose}
      />
    );
  }

  return (
    <Modal title="Withdraw" onClose={onClose}>
      <p className="text-sm text-brand-dark/55">Available balance: ₦{formatAmount(balance)}</p>
      <div className="mt-4">
        <div className="flex items-center rounded-xl border border-brand-dark/15 bg-white px-4 py-3">
          <span className="mr-1 text-sm font-bold text-brand-dark/50">₦</span>
          <input
            type="number"
            autoFocus
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.00"
            className="w-full text-sm text-brand-dark outline-none"
          />
        </div>
        {error && <p className="mt-2 text-xs font-semibold text-red-500">{error}</p>}
      </div>
      <button
        type="button"
        onClick={handleContinue}
        disabled={!amount || parseFloat(amount) <= 0}
        className="mt-5 w-full rounded-full bg-brand py-3 text-sm font-bold text-brand-dark transition-transform hover:scale-[1.02] active:scale-95 disabled:opacity-50 disabled:hover:scale-100"
      >
        Continue
      </button>
    </Modal>
  );
}

function TransferFlow({ balance, onClose, onSuccess }: { balance: number; onClose: () => void; onSuccess: () => void }) {
  const [stage, setStage] = useState<"form" | "pin" | "success">("form");
  const [accountNumber, setAccountNumber] = useState("");
  const [recipient, setRecipient] = useState<UserByAccount | null>(null);
  const [lookupStatus, setLookupStatus] = useState<"idle" | "searching" | "found" | "notFound">("idle");
  const [amount, setAmount] = useState("");
  const [narration, setNarration] = useState("");
  const [error, setError] = useState<string | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const requestIdRef = useRef(0);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    // eslint-disable-next-line react-hooks/set-state-in-effect -- synchronizing local UI state to the accountNumber prop, not an async data fetch
    setRecipient(null);
    setError(null);

    if (accountNumber.length !== 10) {
      setLookupStatus("idle");
      return;
    }

    setLookupStatus("searching");
    debounceRef.current = setTimeout(async () => {
      const thisRequest = ++requestIdRef.current;
      try {
        const res = await api.get(endpoints.walletLookup(accountNumber), authHeaders());
        if (thisRequest !== requestIdRef.current) return;
        setRecipient(res.data as UserByAccount);
        setLookupStatus("found");
      } catch {
        if (thisRequest !== requestIdRef.current) return;
        setLookupStatus("notFound");
      }
    }, 400);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [accountNumber]);

  const handleContinue = () => {
    const value = parseFloat(amount);
    if (!value || value <= 0) return;
    if (value > balance) {
      setError("That's more than your wallet balance.");
      return;
    }
    setError(null);
    setStage("pin");
  };

  const handleConfirm = async (pin: string) => {
    if (!recipient) return;
    const value = parseFloat(amount);
    try {
      await api.post(
        endpoints.walletTransfer,
        { recipient_account_number: recipient.personal_reserved_account_number, amount: value, pin, narration: narration.trim() || undefined },
        authHeaders(),
      );
      setStage("success");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
      setStage("form");
    }
  };

  const recipientName = recipient ? `${recipient.first_name} ${recipient.last_name}`.trim() || `@${recipient.username}` : "";

  if (stage === "success") {
    return (
      <SuccessModal
        title="Transfer Sent"
        subtitle={`₦${formatAmount(parseFloat(amount) || 0)} was sent to ${recipientName}.`}
        onPrimary={onSuccess}
      />
    );
  }

  if (stage === "pin") {
    return (
      <PinConfirmModal
        title="Confirm Transfer"
        subtitle={`Enter your PIN to send ₦${formatAmount(parseFloat(amount) || 0)} to ${recipientName}.`}
        onConfirm={handleConfirm}
        onClose={onClose}
      />
    );
  }

  return (
    <Modal title="Transfer" onClose={onClose}>
      <p className="text-sm text-brand-dark/55">Send money to another AjoPay user instantly.</p>
      <label className="mb-1.5 mt-4 block text-xs font-bold text-brand-dark">Recipient Account Number</label>
      <div className="relative">
        <input
          type="text"
          inputMode="numeric"
          maxLength={10}
          autoFocus
          value={accountNumber}
          onChange={(e) => setAccountNumber(e.target.value.replace(/\D/g, "").slice(0, 10))}
          placeholder="0123456789"
          className="w-full rounded-xl border border-brand-dark/15 bg-white px-4 py-3 pr-10 text-sm text-brand-dark outline-none focus:border-brand-dark"
        />
        {lookupStatus === "searching" && (
          <div className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 animate-spin rounded-full border-2 border-brand-accent border-t-transparent" />
        )}
        {lookupStatus === "found" && <CheckCircle2 size={18} className="absolute right-3 top-1/2 -translate-y-1/2 text-brand-accent" />}
      </div>

      {lookupStatus === "notFound" && <p className="mt-2 text-xs font-semibold text-red-500">No AjoPay account found with that number.</p>}

      {lookupStatus === "found" && recipient && (
        <div className="mt-3 flex items-center gap-2.5 rounded-2xl bg-brand-pale p-3.5">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand font-display text-sm font-bold text-brand-dark">
            {recipient.first_name?.[0]?.toUpperCase() ?? "?"}
          </span>
          <p className="text-sm font-bold text-brand-dark">{recipientName}</p>
        </div>
      )}

      {lookupStatus === "found" && (
        <>
          <p className="mt-5 text-sm text-brand-dark/55">Available balance: ₦{formatAmount(balance)}</p>
          <div className="mt-2 flex items-center rounded-xl border border-brand-dark/15 bg-white px-4 py-3">
            <span className="mr-1 text-sm font-bold text-brand-dark/50">₦</span>
            <input
              type="number"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.00"
              className="w-full text-sm text-brand-dark outline-none"
            />
          </div>
          <input
            type="text"
            value={narration}
            onChange={(e) => setNarration(e.target.value)}
            placeholder="What's it for? (optional)"
            className="mt-3 w-full rounded-xl border border-brand-dark/15 bg-white px-4 py-3 text-sm text-brand-dark outline-none placeholder:text-brand-dark/30"
          />
        </>
      )}

      {error && <p className="mt-3 text-xs font-semibold text-red-500">{error}</p>}

      <button
        type="button"
        onClick={handleContinue}
        disabled={lookupStatus !== "found" || !amount || parseFloat(amount) <= 0}
        className="mt-5 w-full rounded-full bg-brand py-3 text-sm font-bold text-brand-dark transition-transform hover:scale-[1.02] active:scale-95 disabled:opacity-50 disabled:hover:scale-100"
      >
        Continue
      </button>
    </Modal>
  );
}
