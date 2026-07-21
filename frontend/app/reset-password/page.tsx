"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";
import { useForm } from "react-hook-form";
import { AuthCard } from "@/components/auth/auth-card";
import { TextField } from "@/components/auth/text-field";
import { api, ApiError, endpoints } from "@/lib/api";
import { resetPasswordSchema, type ResetPasswordFormValues } from "@/lib/schemas";

function ResetPasswordForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const email = searchParams.get("email") ?? "";
  const [serverError, setServerError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<ResetPasswordFormValues>({ resolver: zodResolver(resetPasswordSchema) });

  const onSubmit = async (values: ResetPasswordFormValues) => {
    setServerError(null);
    try {
      await api.post(endpoints.resetPassword, {
        email,
        otp_code: values.otpCode,
        new_password: values.newPassword,
      });
      router.push("/login?reset=1");
    } catch (err) {
      setServerError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
    }
  };

  const resend = async () => {
    if (!email) return;
    setServerError(null);
    try {
      await api.post(endpoints.forgotPassword, { email });
    } catch (err) {
      setServerError(err instanceof ApiError ? err.message : "Couldn't resend the code. Please try again.");
    }
  };

  return (
    <AuthCard title="Reset your password" subtitle={email ? `Enter the code sent to ${email} and choose a new password.` : "Enter the code from your email and choose a new password."}>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        <TextField label="Code" inputMode="numeric" placeholder="123456" {...register("otpCode")} error={errors.otpCode} />
        <button type="button" onClick={resend} className="text-xs font-bold text-brand-accent hover:text-brand-dark">
          Didn&apos;t get it? Resend code
        </button>
        <TextField label="New password" type="password" placeholder="At least 8 characters" {...register("newPassword")} error={errors.newPassword} />
        <TextField label="Confirm password" type="password" placeholder="Re-enter your new password" {...register("confirmPassword")} error={errors.confirmPassword} />

        {serverError && <p className="text-sm font-semibold text-red-500">{serverError}</p>}

        <button
          type="submit"
          disabled={isSubmitting}
          className="w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark transition-transform hover:scale-[1.02] active:scale-95 disabled:opacity-60 disabled:hover:scale-100"
        >
          {isSubmitting ? "Resetting…" : "Reset Password"}
        </button>
      </form>
    </AuthCard>
  );
}

export default function ResetPasswordPage() {
  return (
    <Suspense fallback={null}>
      <ResetPasswordForm />
    </Suspense>
  );
}
