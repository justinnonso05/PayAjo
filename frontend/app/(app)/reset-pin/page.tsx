"use client";

import { CheckCircle2, Mail } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { PinInput } from "@/components/auth/pin-input";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";

type Stage = "request" | "otp" | "newPin" | "confirmPin" | "success";

export default function ResetPinPage() {
  const router = useRouter();
  const [stage, setStage] = useState<Stage>("request");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [otp, setOtp] = useState("");
  const [isResending, setIsResending] = useState(false);

  const [newPinDigits, setNewPinDigits] = useState("");
  const [newPin, setNewPin] = useState("");
  const [confirmDigits, setConfirmDigits] = useState("");
  const [shakeKey, setShakeKey] = useState(0);

  const sendCode = async () => {
    setIsSubmitting(true);
    setError(null);
    try {
      await api.post(endpoints.requestPinReset, {}, authHeaders());
      setStage("otp");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  const resend = async () => {
    setIsResending(true);
    try {
      await api.post(endpoints.requestPinReset, {}, authHeaders());
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
    } finally {
      setIsResending(false);
    }
  };

  const continueFromOtp = () => {
    if (otp.trim().length < 4) {
      setError("Enter the code from your email");
      return;
    }
    setError(null);
    setStage("newPin");
  };

  const handleNewPinComplete = (pin: string) => {
    setNewPin(pin);
    setStage("confirmPin");
    setNewPinDigits("");
    setConfirmDigits("");
  };

  const handleConfirmComplete = async (pin: string) => {
    if (pin !== newPin) {
      setShakeKey((k) => k + 1);
      setError("PINs don't match. Try again.");
      setTimeout(() => setConfirmDigits(""), 300);
      return;
    }

    setIsSubmitting(true);
    setError(null);
    try {
      await api.post(endpoints.resetPin, { otp_code: otp.trim(), new_pin: pin }, authHeaders());
      setStage("success");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
      setConfirmDigits("");
      setStage("newPin");
    } finally {
      setIsSubmitting(false);
    }
  };

  if (stage === "success") {
    return (
      <div className="mx-auto flex max-w-md flex-col items-center px-6 py-16 text-center">
        <span className="flex h-16 w-16 items-center justify-center rounded-full bg-brand-pale">
          <CheckCircle2 size={30} className="text-brand-accent" />
        </span>
        <h1 className="mt-6 font-display text-xl font-bold text-brand-dark">PIN Updated Successfully</h1>
        <p className="mt-2 text-sm text-brand-dark/55">Your transaction PIN has been changed. Use it next time you approve a payment.</p>
        <button type="button" onClick={() => router.push("/home")} className="mt-8 w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark">
          Done
        </button>
      </div>
    );
  }

  if (stage === "request") {
    return (
      <div className="mx-auto max-w-md px-6 py-12 sm:py-16">
        <span className="flex h-14 w-14 items-center justify-center rounded-full bg-brand-pale">
          <Mail size={22} className="text-brand-accent" />
        </span>
        <h1 className="mt-5 font-display text-2xl font-bold text-brand-dark">Reset Your PIN</h1>
        <p className="mt-2 text-sm leading-relaxed text-brand-dark/55">
          We&apos;ll send a one-time code to your registered email to verify it&apos;s you before setting a new PIN.
        </p>
        {error && <p className="mt-4 text-sm font-semibold text-red-500">{error}</p>}
        <button
          type="button"
          onClick={sendCode}
          disabled={isSubmitting}
          className="mt-8 w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark disabled:opacity-60"
        >
          {isSubmitting ? "Sending…" : "Send Code"}
        </button>
      </div>
    );
  }

  if (stage === "otp") {
    return (
      <div className="mx-auto max-w-md px-6 py-12 sm:py-16">
        <h1 className="font-display text-2xl font-bold text-brand-dark">Enter Code</h1>
        <p className="mt-2 text-sm text-brand-dark/55">Enter the code we emailed you.</p>
        <input
          type="text"
          inputMode="numeric"
          maxLength={6}
          value={otp}
          onChange={(e) => setOtp(e.target.value.replace(/\D/g, ""))}
          placeholder="••••••"
          className="mt-8 w-full rounded-xl border border-brand-dark/15 bg-white px-4 py-4 text-center font-display text-2xl font-bold tracking-[0.5em] text-brand-dark outline-none focus:border-brand-dark"
        />
        <button type="button" onClick={resend} disabled={isResending} className="mx-auto mt-3 block text-sm font-bold text-brand-accent">
          {isResending ? "Sending…" : "Didn't get it? Resend code"}
        </button>
        {error && <p className="mt-4 text-center text-sm font-semibold text-red-500">{error}</p>}
        <button type="button" onClick={continueFromOtp} className="mt-8 w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark">
          Continue
        </button>
      </div>
    );
  }

  if (stage === "newPin") {
    return (
      <div className="mx-auto max-w-md px-6 py-12 sm:py-16 text-center">
        <h1 className="font-display text-2xl font-bold text-brand-dark">Enter New PIN</h1>
        <p className="mt-2 text-sm text-brand-dark/55">Choose a new 4-digit PIN for your account.</p>
        <div className="mt-8">
          <PinInput value={newPinDigits} onChange={setNewPinDigits} onComplete={handleNewPinComplete} />
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-md px-6 py-12 sm:py-16 text-center">
      <h1 className="font-display text-2xl font-bold text-brand-dark">Confirm your PIN</h1>
      <p className="mt-2 text-sm text-brand-dark/55">Enter your new PIN again to confirm.</p>
      <div className="mt-8">
        <PinInput value={confirmDigits} onChange={setConfirmDigits} onComplete={handleConfirmComplete} disabled={isSubmitting} shakeKey={shakeKey} />
      </div>
      {error && <p className="mt-4 text-sm font-semibold text-red-500">{error}</p>}
    </div>
  );
}
