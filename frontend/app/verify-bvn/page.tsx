"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { ShieldCheck } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { AuthCard } from "@/components/auth/auth-card";
import { TextField } from "@/components/auth/text-field";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders, getToken } from "@/lib/auth";
import { bvnSchema, type BvnFormValues } from "@/lib/schemas";

export default function VerifyBvnPage() {
  const router = useRouter();
  const [serverError, setServerError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<BvnFormValues>({ resolver: zodResolver(bvnSchema) });

  useEffect(() => {
    if (!getToken()) router.replace("/login");
  }, [router]);

  const onSubmit = async (values: BvnFormValues) => {
    setServerError(null);
    try {
      await api.post(endpoints.mockKycVerify, { bvn: values.bvn }, authHeaders());
      router.push("/join-or-create");
    } catch (err) {
      setServerError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
    }
  };

  return (
    <AuthCard title="Verify your identity" subtitle="One quick step before you can create or join a group.">
      <div className="mb-6 flex items-center gap-3 rounded-2xl bg-brand-pale px-4 py-3.5">
        <ShieldCheck size={18} className="shrink-0 text-brand-accent" />
        <p className="text-xs font-semibold text-brand-dark/70">Your BVN is used only to confirm your identity and is never shared.</p>
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        <TextField
          label="Bank Verification Number (BVN)"
          placeholder="12345678901"
          inputMode="numeric"
          maxLength={11}
          {...register("bvn")}
          error={errors.bvn}
        />

        {serverError && <p className="text-sm font-semibold text-red-500">{serverError}</p>}

        <button
          type="submit"
          disabled={isSubmitting}
          className="w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark transition-transform hover:scale-[1.02] active:scale-95 disabled:opacity-60 disabled:hover:scale-100"
        >
          {isSubmitting ? "Verifying…" : "Verify Identity"}
        </button>
      </form>
    </AuthCard>
  );
}
