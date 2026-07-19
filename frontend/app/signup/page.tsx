"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { AuthCard } from "@/components/auth/auth-card";
import { TextField } from "@/components/auth/text-field";
import { api, ApiError, endpoints } from "@/lib/api";
import { saveTokenFromResponse } from "@/lib/auth";
import { registerSchema, type RegisterFormValues } from "@/lib/schemas";

export default function SignupPage() {
  const router = useRouter();
  const [serverError, setServerError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<RegisterFormValues>({ resolver: zodResolver(registerSchema) });

  const onSubmit = async (values: RegisterFormValues) => {
    setServerError(null);
    try {
      const response = await api.post(endpoints.register, {
        email: values.email,
        username: values.username,
        first_name: values.firstName,
        last_name: values.lastName,
        password: values.password,
        phone: values.phone,
      });
      saveTokenFromResponse(response.data);
      router.push("/verify-bvn");
    } catch (err) {
      setServerError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
    }
  };

  return (
    <AuthCard
      title="Create your account"
      subtitle="Start saving with people you trust."
      footer={
        <>
          Already have an account?{" "}
          <Link href="/login" className="font-bold text-brand-dark hover:text-brand-accent">
            Sign in
          </Link>
        </>
      }
    >
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        <div className="grid grid-cols-2 gap-4">
          <TextField label="First name" placeholder="Amara" {...register("firstName")} error={errors.firstName} />
          <TextField label="Last name" placeholder="Okafor" {...register("lastName")} error={errors.lastName} />
        </div>
        <TextField label="Username" placeholder="amara_o" {...register("username")} error={errors.username} />
        <TextField label="Email" type="email" placeholder="amara@email.com" {...register("email")} error={errors.email} />
        <TextField label="Phone number" type="tel" placeholder="08012345678" {...register("phone")} error={errors.phone} />
        <TextField label="Password" type="password" placeholder="••••••••" {...register("password")} error={errors.password} />

        {serverError && <p className="text-sm font-semibold text-red-500">{serverError}</p>}

        <button
          type="submit"
          disabled={isSubmitting}
          className="w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark transition-transform hover:scale-[1.02] active:scale-95 disabled:opacity-60 disabled:hover:scale-100"
        >
          {isSubmitting ? "Creating account…" : "Create Account"}
        </button>
      </form>
    </AuthCard>
  );
}
