"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { AuthCard } from "@/components/auth/auth-card";
import { TextField } from "@/components/auth/text-field";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders, saveTokenFromResponse } from "@/lib/auth";
import { loginSchema, type LoginFormValues } from "@/lib/schemas";

export default function LoginPage() {
  const router = useRouter();
  const [serverError, setServerError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormValues>({ resolver: zodResolver(loginSchema) });

  const onSubmit = async (values: LoginFormValues) => {
    setServerError(null);
    try {
      const response = await api.post(endpoints.login, values);
      saveTokenFromResponse(response.data);

      const me = await api.get(endpoints.me, authHeaders());
      const profile = me.data as { kyc_status?: boolean; has_pin?: boolean } | undefined;

      if (!profile?.kyc_status) {
        router.push("/verify-bvn");
      } else if (!profile?.has_pin) {
        router.push("/pin-setup");
      } else {
        router.push("/home");
      }
    } catch (err) {
      setServerError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
    }
  };

  return (
    <AuthCard
      title="Welcome back"
      subtitle="Sign in to your AjoPay account."
      footer={
        <>
          New to AjoPay?{" "}
          <Link href="/signup" className="font-bold text-brand-dark hover:text-brand-accent">
            Create an account
          </Link>
        </>
      }
    >
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        <TextField label="Email" type="email" placeholder="amara@email.com" {...register("email")} error={errors.email} />
        <TextField label="Password" type="password" placeholder="••••••••" {...register("password")} error={errors.password} />

        {serverError && <p className="text-sm font-semibold text-red-500">{serverError}</p>}

        <button
          type="submit"
          disabled={isSubmitting}
          className="w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark transition-transform hover:scale-[1.02] active:scale-95 disabled:opacity-60 disabled:hover:scale-100"
        >
          {isSubmitting ? "Signing in…" : "Sign In"}
        </button>
      </form>
    </AuthCard>
  );
}
