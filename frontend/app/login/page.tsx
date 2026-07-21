"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { AuthCard } from "@/components/auth/auth-card";
import { TextField } from "@/components/auth/text-field";
import { api, ApiError, endpoints, resetUnauthorizedGuard } from "@/lib/api";
import { authHeaders, getLastEmail, saveLastEmail, saveTokenFromResponse } from "@/lib/auth";
import { loginSchema, type LoginFormValues } from "@/lib/schemas";

export default function LoginPage() {
  const router = useRouter();
  const [serverError, setServerError] = useState<string | null>(null);
  const [sessionExpired, setSessionExpired] = useState(false);
  const [passwordReset, setPasswordReset] = useState(false);
  const {
    register,
    handleSubmit,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormValues>({ resolver: zodResolver(loginSchema) });

  useEffect(() => {
    const cachedEmail = getLastEmail();
    if (cachedEmail) setValue("email", cachedEmail);
    if (window.sessionStorage.getItem("payajo_session_expired")) {
      window.sessionStorage.removeItem("payajo_session_expired");
      // eslint-disable-next-line react-hooks/set-state-in-effect -- one-time hydration from sessionStorage, not a render-loop
      setSessionExpired(true);
    }
    if (new URLSearchParams(window.location.search).get("reset") === "1") {
      setPasswordReset(true);
    }
  }, [setValue]);

  const onSubmit = async (values: LoginFormValues) => {
    setServerError(null);
    try {
      const response = await api.post(endpoints.login, values);
      saveTokenFromResponse(response.data);
      saveLastEmail(values.email);
      // A previous session's 401 may have latched the "already handling an
      // expired session" guard — a fresh successful login clears it.
      resetUnauthorizedGuard();

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
      subtitle="Sign in to your PayAjo account."
      footer={
        <>
          New to PayAjo?{" "}
          <Link href="/signup" className="font-bold text-brand-dark hover:text-brand-accent">
            Create an account
          </Link>
        </>
      }
    >
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        {sessionExpired && (
          <p className="rounded-xl bg-amber-50 px-3.5 py-2.5 text-xs font-semibold text-amber-700">Your session expired. Please log in again.</p>
        )}
        {passwordReset && (
          <p className="rounded-xl bg-brand-pale px-3.5 py-2.5 text-xs font-semibold text-brand-accent">Your password was reset. Sign in with your new password.</p>
        )}
        <TextField label="Email" type="email" placeholder="amara@email.com" {...register("email")} error={errors.email} />
        <div>
          <TextField label="Password" type="password" placeholder="••••••••" {...register("password")} error={errors.password} />
          <Link href="/forgot-password" className="mt-1.5 block text-right text-xs font-bold text-brand-accent hover:text-brand-dark">
            Forgot password?
          </Link>
        </div>

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
