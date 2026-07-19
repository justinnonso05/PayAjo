"use client";

import { CheckCircle2 } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { Modal } from "@/components/app/modal";
import { api, ApiError, endpoints } from "@/lib/api";
import { authHeaders } from "@/lib/auth";
import type { UserSearchResult } from "@/lib/types";

type Status = "idle" | "searching" | "found" | "notFound";

export function SendInviteModal({ groupId, onClose, onSent }: { groupId: string; onClose: () => void; onSent: () => void }) {
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState<Status>("idle");
  const [result, setResult] = useState<UserSearchResult | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const requestIdRef = useRef(0);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    const trimmed = query.trim();
    if (!trimmed) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- synchronizing local UI state to the query prop, not an async data fetch
      setStatus("idle");
      setResult(null);
      return;
    }
    setStatus("searching");
    debounceRef.current = setTimeout(async () => {
      const thisRequest = ++requestIdRef.current;
      try {
        const res = await api.get(endpoints.searchUser(trimmed), authHeaders());
        if (thisRequest !== requestIdRef.current) return;
        setResult(res.data as UserSearchResult);
        setStatus("found");
      } catch {
        if (thisRequest !== requestIdRef.current) return;
        setResult(null);
        setStatus("notFound");
      }
    }, 450);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [query]);

  const handleSubmit = async () => {
    if (!result) return;
    setIsSubmitting(true);
    setError(null);
    try {
      await api.post(endpoints.sendInvite(groupId), { email_or_username: result.username }, authHeaders());
      onSent();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Something went wrong sending the invite. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  const isHighRisk = result && result.risk_score >= 50;

  return (
    <Modal title="Invite Someone" onClose={onClose}>
      <p className="text-sm text-brand-dark/55">They&apos;ll see this invite next time they open AjoPay.</p>

      <div className="mt-5">
        <label className="mb-1.5 block text-xs font-bold text-brand-dark">Email or Username</label>
        <input
          autoFocus
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="e.g. amara or amara@email.com"
          className="w-full rounded-xl border border-brand-dark/15 px-4 py-3 text-sm outline-none focus:border-brand-dark"
        />
      </div>

      {status === "notFound" && <p className="mt-3 text-xs font-semibold text-red-500">No AjoPay user found with that email or username.</p>}

      {status === "found" && result && (
        <div className="mt-4 flex items-center gap-3 rounded-2xl bg-brand-pale p-3.5">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand">
            <CheckCircle2 size={16} className="text-brand-dark" />
          </span>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-bold text-brand-dark">{`${result.first_name} ${result.last_name}`.trim() || `@${result.username}`}</p>
            <p className="text-xs text-brand-dark/60">@{result.username}</p>
          </div>
          {isHighRisk && <span className="rounded-full bg-red-50 px-2.5 py-1 text-[10px] font-bold text-red-500">High risk</span>}
        </div>
      )}

      {error && <p className="mt-3 text-xs font-semibold text-red-500">{error}</p>}

      <button
        type="button"
        disabled={status !== "found" || isSubmitting}
        onClick={handleSubmit}
        className="mt-6 w-full rounded-full bg-brand py-3.5 text-sm font-bold text-brand-dark transition-transform hover:scale-[1.02] active:scale-95 disabled:opacity-40 disabled:hover:scale-100"
      >
        {isSubmitting ? "Sending…" : "Send Invite"}
      </button>
    </Modal>
  );
}
