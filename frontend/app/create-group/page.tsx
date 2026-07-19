"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { AuthCard } from "@/components/auth/auth-card";
import { TextField } from "@/components/auth/text-field";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders, getToken } from "@/lib/auth";
import { createGroupSchema, type CreateGroupFormValues } from "@/lib/schemas";
import type { z } from "zod";

const FREQUENCIES: { value: CreateGroupFormValues["cycleFrequency"]; label: string }[] = [
  { value: "weekly", label: "Weekly" },
  { value: "monthly", label: "Monthly" },
  { value: "yearly", label: "Yearly" },
];

export default function CreateGroupPage() {
  const router = useRouter();
  const [serverError, setServerError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<z.input<typeof createGroupSchema>, unknown, CreateGroupFormValues>({
    resolver: zodResolver(createGroupSchema),
    defaultValues: { cycleFrequency: "weekly" },
  });

  useEffect(() => {
    if (!getToken()) router.replace("/login");
  }, [router]);

  const cycleFrequency = watch("cycleFrequency");

  const onSubmit = async (values: CreateGroupFormValues) => {
    setServerError(null);
    try {
      await api.post(
        endpoints.groups,
        {
          name: values.name,
          contribution_amount: values.contributionAmount,
          cycle_frequency: values.cycleFrequency,
          shortfall_policy: "hold",
        },
        authHeaders(),
      );
      router.push("/pin-setup");
    } catch (err) {
      setServerError(err instanceof ApiError ? err.message : "Something went wrong. Please try again.");
    }
  };

  return (
    <AuthCard title="Create a Group" subtitle="Set up your savings circle in a few seconds.">
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        <TextField label="Group name" placeholder="Market Women Circle" {...register("name")} error={errors.name} />
        <TextField
          label="Contribution amount (₦)"
          type="number"
          placeholder="5000"
          {...register("contributionAmount")}
          error={errors.contributionAmount}
        />

        <div>
          <span className="mb-1.5 block text-xs font-bold text-brand-dark">Cycle frequency</span>
          <div className="grid grid-cols-3 gap-2">
            {FREQUENCIES.map((f) => (
              <button
                key={f.value}
                type="button"
                onClick={() => setValue("cycleFrequency", f.value, { shouldValidate: true })}
                className={`rounded-xl border py-2.5 text-xs font-bold transition-colors ${
                  cycleFrequency === f.value
                    ? "border-brand-accent bg-brand-pale text-brand-dark"
                    : "border-brand-dark/15 bg-white text-brand-dark/60"
                }`}
              >
                {f.label}
              </button>
            ))}
          </div>
        </div>

        {serverError && <p className="text-sm font-semibold text-red-500">{serverError}</p>}

        <button
          type="submit"
          disabled={isSubmitting}
          className="w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark transition-transform hover:scale-[1.02] active:scale-95 disabled:opacity-60 disabled:hover:scale-100"
        >
          {isSubmitting ? "Creating group…" : "Create Group"}
        </button>
      </form>
    </AuthCard>
  );
}
