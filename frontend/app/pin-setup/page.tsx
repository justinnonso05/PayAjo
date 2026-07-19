"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { AuthCard } from "@/components/auth/auth-card";
import { PinInput } from "@/components/auth/pin-input";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders, getToken } from "@/lib/auth";

export default function PinSetupPage() {
  const router = useRouter();
  const [stage, setStage] = useState<"create" | "confirm">("create");
  const [firstPin, setFirstPin] = useState("");
  const [digits, setDigits] = useState("");
  const [shakeKey, setShakeKey] = useState(0);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [serverError, setServerError] = useState<string | null>(null);

  useEffect(() => {
    if (!getToken()) router.replace("/login");
  }, [router]);

  const handleCreateComplete = (pin: string) => {
    setFirstPin(pin);
    setStage("confirm");
    setDigits("");
  };

  const handleConfirmComplete = async (pin: string) => {
    if (pin !== firstPin) {
      setShakeKey((k) => k + 1);
      setServerError("PINs don't match. Try again.");
      setTimeout(() => setDigits(""), 300);
      return;
    }

    setServerError(null);
    setIsSubmitting(true);
    try {
      await api.post(endpoints.setupPin, { pin }, authHeaders());
      router.push("/home");
    } catch (err) {
      setServerError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
      setDigits("");
      setStage("create");
      setFirstPin("");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <AuthCard
      title={stage === "create" ? "Set your 4-digit transaction PIN" : "Confirm your PIN"}
      subtitle={
        stage === "create"
          ? "You'll only be asked for this once. Use it to approve contributions and withdrawals."
          : "Enter your PIN again to confirm."
      }
    >
      <PinInput
        value={digits}
        onChange={setDigits}
        onComplete={stage === "create" ? handleCreateComplete : handleConfirmComplete}
        disabled={isSubmitting}
        shakeKey={shakeKey}
      />

      {serverError && <p className="mt-4 text-center text-sm font-semibold text-red-500">{serverError}</p>}

      <button
        type="button"
        onClick={() => router.push("/home")}
        className="mx-auto mt-8 block text-sm font-bold text-brand-dark/50 hover:text-brand-dark"
      >
        Not now
      </button>
    </AuthCard>
  );
}
