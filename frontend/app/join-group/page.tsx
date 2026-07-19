"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { AuthCard } from "@/components/auth/auth-card";
import { TextField } from "@/components/auth/text-field";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders, getToken } from "@/lib/auth";
import { joinGroupSchema, type JoinGroupFormValues } from "@/lib/schemas";

export default function JoinGroupPage() {
  const router = useRouter();
  const [serverError, setServerError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<JoinGroupFormValues>({ resolver: zodResolver(joinGroupSchema) });

  useEffect(() => {
    if (!getToken()) router.replace("/login");
  }, [router]);

  const onSubmit = async (values: JoinGroupFormValues) => {
    setServerError(null);
    try {
      await api.post(endpoints.joinGroup, { invite_code: values.inviteCode }, authHeaders());
      router.push("/pin-setup");
    } catch (err) {
      setServerError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
    }
  };

  return (
    <AuthCard title="Join a Group" subtitle="Enter the invite code shared with you.">
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        <TextField
          label="Invite code"
          placeholder="e.g. AJP-4F2C9"
          className="uppercase tracking-widest"
          {...register("inviteCode")}
          error={errors.inviteCode}
        />

        {serverError && <p className="text-sm font-semibold text-red-500">{serverError}</p>}

        <button
          type="submit"
          disabled={isSubmitting}
          className="w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark transition-transform hover:scale-[1.02] active:scale-95 disabled:opacity-60 disabled:hover:scale-100"
        >
          {isSubmitting ? "Joining group…" : "Join Group"}
        </button>
      </form>
    </AuthCard>
  );
}
