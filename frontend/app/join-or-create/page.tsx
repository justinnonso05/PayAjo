"use client";

import { Link2, PlusCircle } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { AuthCard } from "@/components/auth/auth-card";
import { getToken } from "@/lib/auth";

export default function JoinOrCreatePage() {
  const router = useRouter();
  const [selected, setSelected] = useState<"create" | "join" | null>(null);

  useEffect(() => {
    if (!getToken()) router.replace("/login");
  }, [router]);

  const handleContinue = () => {
    if (!selected) return;
    router.push(selected === "create" ? "/create-group" : "/join-group");
  };

  return (
    <AuthCard title="Join or Create" subtitle="PayAjo is built around saving together. Choose how you'd like to get started.">
      <div className="grid grid-cols-2 gap-4">
        {[
          { key: "create" as const, icon: PlusCircle, title: "Create Group", subtitle: "Start a new pool" },
          { key: "join" as const, icon: Link2, title: "Join Group", subtitle: "Use invite code" },
        ].map(({ key, icon: Icon, title, subtitle }) => {
          const isSelected = selected === key;
          return (
            <button
              key={key}
              type="button"
              onClick={() => setSelected(key)}
              className={`flex flex-col items-center gap-3 rounded-2xl border-2 px-4 py-8 text-center transition-all ${
                isSelected ? "scale-[1.03] border-brand-accent bg-brand-pale" : "border-brand-dark/10 bg-white hover:border-brand-dark/20"
              }`}
            >
              <span className={`flex h-11 w-11 items-center justify-center rounded-full ${isSelected ? "bg-brand" : "bg-soft-gray"}`}>
                <Icon size={20} className="text-brand-accent" />
              </span>
              <span>
                <span className="block font-display text-sm font-bold text-brand-dark">{title}</span>
                <span className="mt-0.5 block text-xs font-semibold text-brand-dark/50">{subtitle}</span>
              </span>
            </button>
          );
        })}
      </div>

      <button
        type="button"
        disabled={!selected}
        onClick={handleContinue}
        className="mt-8 w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark transition-transform hover:scale-[1.02] active:scale-95 disabled:cursor-not-allowed disabled:bg-soft-gray disabled:text-brand-dark/30 disabled:hover:scale-100"
      >
        Continue
      </button>

      <button
        type="button"
        onClick={() => router.push("/home")}
        className="mt-3.5 w-full text-center text-xs font-bold text-brand-dark/50 hover:text-brand-dark transition-colors"
      >
        Skip for now
      </button>
    </AuthCard>
  );
}
