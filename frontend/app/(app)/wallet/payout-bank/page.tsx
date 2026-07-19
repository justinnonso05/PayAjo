"use client";

import { CheckCircle2, ChevronDown, Search } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { SuccessModal } from "@/components/app/success-modal";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";
import type { Bank, BankValidationResult } from "@/lib/types";

export default function PayoutBankPage() {
  const router = useRouter();
  const [stage, setStage] = useState<"details" | "otp" | "success">("details");
  const [banks, setBanks] = useState<Bank[]>([]);
  const [isLoadingBanks, setIsLoadingBanks] = useState(true);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [bankQuery, setBankQuery] = useState("");
  const [selectedBank, setSelectedBank] = useState<Bank | null>(null);
  const [accountNumber, setAccountNumber] = useState("");
  const [validated, setValidated] = useState<BankValidationResult | null>(null);
  const [isValidating, setIsValidating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [otp, setOtp] = useState("");
  const [isResending, setIsResending] = useState(false);
  const [isConfirming, setIsConfirming] = useState(false);
  const [otpError, setOtpError] = useState<string | null>(null);

  useEffect(() => {
    api
      .get(endpoints.banks, authHeaders())
      .then((res) => {
        const list = ((res.data as Bank[]) ?? []).slice().sort((a, b) => a.name.localeCompare(b.name));
        setBanks(list);
      })
      .catch((err) => setError(err instanceof ApiError ? err.message : "Couldn't load banks."))
      .finally(() => setIsLoadingBanks(false));
  }, []);

  const canValidate = selectedBank !== null && accountNumber.length === 10;

  const handleValidate = async () => {
    if (!selectedBank || accountNumber.length !== 10) return;
    setIsValidating(true);
    setError(null);
    try {
      const res = await api.get(endpoints.validateBankAccount(accountNumber, selectedBank.code), authHeaders());
      setValidated(res.data as BankValidationResult);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Couldn't validate this account.");
    } finally {
      setIsValidating(false);
    }
  };

  const handleContinue = async () => {
    if (!selectedBank || !validated) return;
    setError(null);
    try {
      await api.post(endpoints.requestPayoutBankOtp, {}, authHeaders());
      setStage("otp");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
    }
  };

  const handleResend = async () => {
    setIsResending(true);
    try {
      await api.post(endpoints.requestPayoutBankOtp, {}, authHeaders());
    } catch (err) {
      setOtpError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
    } finally {
      setIsResending(false);
    }
  };

  const handleConfirm = async () => {
    if (!selectedBank || !validated || otp.trim().length < 4) {
      setOtpError("Enter the code from your email");
      return;
    }
    setIsConfirming(true);
    setOtpError(null);
    try {
      await api.post(
        endpoints.setPayoutBank,
        { bank_account_number: validated.accountNumber, bank_code: selectedBank.code, otp_code: otp.trim() },
        authHeaders(),
      );
      setStage("success");
    } catch (err) {
      setOtpError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
    } finally {
      setIsConfirming(false);
    }
  };

  const filteredBanks = banks.filter((b) => b.name.toLowerCase().includes(bankQuery.toLowerCase()));

  if (stage === "success" && selectedBank && validated) {
    return (
      <SuccessModal
        title="Payout Bank Set"
        subtitle={`Withdrawals will now go straight to ${validated.accountName} at ${selectedBank.name}.`}
        onPrimary={() => router.push("/wallet")}
      />
    );
  }

  if (stage === "otp" && selectedBank && validated) {
    return (
      <div className="mx-auto max-w-md px-6 py-12 sm:py-16">
        <h1 className="font-display text-2xl font-bold text-brand-dark">Confirm It&apos;s You</h1>
        <p className="mt-2 text-sm text-brand-dark/55">
          Enter the code we emailed you to confirm {validated.accountName} ({selectedBank.name}) as your payout account.
        </p>

        <input
          type="text"
          inputMode="numeric"
          maxLength={6}
          value={otp}
          onChange={(e) => setOtp(e.target.value.replace(/\D/g, ""))}
          placeholder="••••••"
          className="mt-8 w-full rounded-xl border border-brand-dark/15 bg-white px-4 py-4 text-center font-display text-2xl font-bold tracking-[0.5em] text-brand-dark outline-none focus:border-brand-dark"
        />

        <button type="button" onClick={handleResend} disabled={isResending} className="mx-auto mt-3 block text-sm font-bold text-brand-accent">
          {isResending ? "Sending…" : "Didn't get it? Resend code"}
        </button>

        {otpError && <p className="mt-4 text-center text-sm font-semibold text-red-500">{otpError}</p>}

        <button
          type="button"
          onClick={handleConfirm}
          disabled={isConfirming}
          className="mt-8 w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark transition-transform hover:scale-[1.02] active:scale-95 disabled:opacity-60"
        >
          {isConfirming ? "Confirming…" : "Confirm"}
        </button>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-md px-6 py-12 sm:py-16">
      <h1 className="font-display text-2xl font-bold text-brand-dark">Where should withdrawals go?</h1>
      <p className="mt-2 text-sm text-brand-dark/55">Set this once. Every withdrawal after this goes straight to this account, no need to re-enter it.</p>

      <div className="mt-8 space-y-5">
        <div>
          <label className="mb-1.5 block text-xs font-bold text-brand-dark">Bank</label>
          <button
            type="button"
            disabled={isLoadingBanks}
            onClick={() => setPickerOpen(true)}
            className="flex w-full items-center justify-between rounded-xl border border-brand-dark/15 bg-white px-4 py-3.5 text-left text-sm"
          >
            <span className={selectedBank ? "font-bold text-brand-dark" : "text-brand-dark/30"}>
              {isLoadingBanks ? "Loading banks…" : selectedBank?.name ?? "Select a bank"}
            </span>
            <ChevronDown size={16} className="text-brand-dark/30" />
          </button>
        </div>

        <div>
          <label className="mb-1.5 block text-xs font-bold text-brand-dark">Account Number</label>
          <input
            type="text"
            inputMode="numeric"
            maxLength={10}
            value={accountNumber}
            onChange={(e) => {
              setAccountNumber(e.target.value.replace(/\D/g, "").slice(0, 10));
              setValidated(null);
            }}
            placeholder="0123456789"
            className="w-full rounded-xl border border-brand-dark/15 bg-white px-4 py-3.5 text-sm text-brand-dark outline-none focus:border-brand-dark"
          />
        </div>

        {validated ? (
          <div className="flex items-center gap-2.5 rounded-2xl bg-brand-pale px-4 py-3.5">
            <CheckCircle2 size={18} className="shrink-0 text-brand-accent" />
            <p className="text-sm font-bold text-brand-dark">{validated.accountName}</p>
          </div>
        ) : (
          <button
            type="button"
            disabled={!canValidate || isValidating}
            onClick={handleValidate}
            className="w-full rounded-full border border-brand-dark/15 py-3 text-sm font-bold text-brand-dark disabled:opacity-40"
          >
            {isValidating ? "Verifying…" : "Verify Account"}
          </button>
        )}

        {error && <p className="text-xs font-semibold text-red-500">{error}</p>}

        <button
          type="button"
          disabled={!validated}
          onClick={handleContinue}
          className="w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark transition-transform hover:scale-[1.02] active:scale-95 disabled:bg-soft-gray disabled:text-brand-dark/30 disabled:hover:scale-100"
        >
          Continue
        </button>
      </div>

      {pickerOpen && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-brand-dark/40 backdrop-blur-sm sm:items-center" onClick={() => setPickerOpen(false)}>
          <div className="max-h-[70vh] w-full max-w-md rounded-t-card bg-white p-6 shadow-2xl sm:rounded-card" onClick={(e) => e.stopPropagation()}>
            <h3 className="font-display text-lg font-bold text-brand-dark">Select Bank</h3>
            <div className="mt-3 flex items-center gap-2 rounded-xl border border-brand-dark/15 px-3 py-2.5">
              <Search size={15} className="text-brand-dark/30" />
              <input
                type="text"
                autoFocus
                value={bankQuery}
                onChange={(e) => setBankQuery(e.target.value)}
                placeholder="Search banks…"
                className="w-full text-sm text-brand-dark outline-none"
              />
            </div>
            <div className="mt-3 max-h-80 divide-y divide-brand-dark/5 overflow-y-auto">
              {filteredBanks.map((bank) => (
                <button
                  key={bank.code}
                  type="button"
                  onClick={() => {
                    setSelectedBank(bank);
                    setValidated(null);
                    setPickerOpen(false);
                  }}
                  className="w-full py-3 text-left text-sm text-brand-dark hover:text-brand-accent"
                >
                  {bank.name}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
