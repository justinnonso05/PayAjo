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

// Matches the backend's payout_day_of_week convention: Monday = 0 ... Sunday = 6.
const WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

export default function CreateGroupPage() {
  const router = useRouter();
  const [serverError, setServerError] = useState<string | null>(null);
  const [payoutDayError, setPayoutDayError] = useState<string | null>(null);
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
  const payoutDayOfWeek = watch("payoutDayOfWeek");

  const onSubmit = async (values: CreateGroupFormValues) => {
    if (values.cycleFrequency === "weekly" && values.payoutDayOfWeek === undefined) {
      setPayoutDayError("Please choose a payout day.");
      return;
    }
    setPayoutDayError(null);
    setServerError(null);
    try {
      await api.post(
        endpoints.groups,
        {
          name: values.name,
          contribution_amount: values.contributionAmount,
          cycle_frequency: values.cycleFrequency,
          shortfall_policy: "hold",
          ...(values.cycleFrequency === "weekly" && values.payoutDayOfWeek !== undefined
            ? { payout_day_of_week: values.payoutDayOfWeek }
            : {}),
          ...(values.cycleFrequency !== "weekly" && values.payoutDayOfMonth?.trim()
            ? { payout_day_of_month: parseInt(values.payoutDayOfMonth, 10) }
            : {}),
          ...(values.cycleFrequency === "yearly" && values.payoutMonth?.trim() ? { payout_month: parseInt(values.payoutMonth, 10) } : {}),
          ...(values.payoutTime ? { payout_time: `${values.payoutTime}:00Z` } : {}),
          ...(values.memberCap?.trim() ? { member_cap: parseInt(values.memberCap, 10) } : {}),
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

        {cycleFrequency === "weekly" && (
          <div>
            <span className="mb-1.5 block text-xs font-bold text-brand-dark">Payout Day</span>
            <div className="flex flex-wrap gap-2">
              {WEEKDAYS.map((day, index) => (
                <button
                  key={day}
                  type="button"
                  onClick={() => {
                    setValue("payoutDayOfWeek", index, { shouldValidate: true });
                    setPayoutDayError(null);
                  }}
                  className={`rounded-full border px-3.5 py-2 text-xs font-bold transition-colors ${
                    payoutDayOfWeek === index
                      ? "border-brand-accent bg-brand-pale text-brand-dark"
                      : "border-brand-dark/15 bg-white text-brand-dark/60"
                  }`}
                >
                  {day}
                </button>
              ))}
            </div>
            {payoutDayError && <p className="mt-1.5 text-xs font-semibold text-red-500">{payoutDayError}</p>}
          </div>
        )}

        {(cycleFrequency === "monthly" || cycleFrequency === "yearly") && (
          <div className="flex gap-3">
            {cycleFrequency === "yearly" && (
              <TextField
                label="Payout Month (1-12)"
                type="number"
                placeholder="1"
                {...register("payoutMonth")}
              />
            )}
            <TextField
              label="Payout Day of Month (1-28)"
              type="number"
              placeholder="1"
              {...register("payoutDayOfMonth")}
            />
          </div>
        )}

        <TextField label="Payout Time (optional)" type="time" {...register("payoutTime")} />
        <TextField label="Maximum Members (optional)" type="number" placeholder="10" {...register("memberCap")} />

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
