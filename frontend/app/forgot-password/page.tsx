"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { AuthCard } from "@/components/auth/auth-card";
import { TextField } from "@/components/auth/text-field";
import { api, ApiError, endpoints } from "@/lib/api";
import { forgotPasswordSchema, type ForgotPasswordFormValues } from "@/lib/schemas";

export default function ForgotPasswordPage() {
  const router = useRouter();
  const [serverError, setServerError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<ForgotPasswordFormValues>({ resolver: zodResolver(forgotPasswordSchema) });

  const onSubmit = async (values: ForgotPasswordFormValues) => {
    setServerError(null);
    try {
      await api.post(endpoints.forgotPassword, values);
      router.push(`/reset-password?email=${encodeURIComponent(values.email)}`);
    } catch (err) {
      setServerError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
    }
  };

  return (
    <AuthCard title="Forgot password?" subtitle="Enter the email on your account and we'll send a one-time code to reset your password.">
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        <TextField label="Email" type="email" placeholder="amara@email.com" {...register("email")} error={errors.email} />

        {serverError && <p className="text-sm font-semibold text-red-500">{serverError}</p>}

        <button
          type="submit"
          disabled={isSubmitting}
          className="w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark transition-transform hover:scale-[1.02] active:scale-95 disabled:opacity-60 disabled:hover:scale-100"
        >
          {isSubmitting ? "Sending…" : "Send Code"}
        </button>
      </form>
    </AuthCard>
  );
}
