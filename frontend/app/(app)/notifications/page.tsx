"use client";

import {
  AlarmClock,
  Bell,
  BellOff,
  Calendar,
  CheckCircle2,
  Megaphone,
  PartyPopper,
  UserPlus,
  WifiOff,
  X,
} from "lucide-react";
import { EmptyState } from "@/components/app/empty-state";
import { dayBucket, formatTime } from "@/lib/format";
import { useNotifications } from "@/lib/hooks/use-notifications";
import type { AppNotification } from "@/lib/types";

function iconForType(type: string) {
  const t = type.toLowerCase();
  if (t.includes("payout")) return PartyPopper;
  if (t.includes("contribution") || t.includes("payment")) return CheckCircle2;
  if (t.includes("withdraw")) return Calendar;
  if (t.includes("member") || t.includes("join")) return UserPlus;
  if (t.includes("announcement") || t.includes("admin")) return Megaphone;
  if (t.includes("reminder")) return AlarmClock;
  return Bell;
}

const BUCKET_ORDER = ["Today", "Yesterday", "Earlier"] as const;

export default function NotificationsPage() {
  const { items, isLoading, error, markRead, markAllRead, dismiss } = useNotifications();

  const hasUnread = items.some((n) => !n.is_read);
  const buckets: Record<string, AppNotification[]> = { Today: [], Yesterday: [], Earlier: [] };
  for (const n of items) buckets[dayBucket(n.created_at)].push(n);

  return (
    <div className="mx-auto max-w-2xl px-6 py-8 sm:px-10 sm:py-10">
      <div className="flex items-center justify-between">
        <h1 className="font-display text-2xl font-bold text-brand-dark">Notifications</h1>
        {hasUnread && (
          <button type="button" onClick={markAllRead} className="text-sm font-bold text-brand-accent">
            Mark all read
          </button>
        )}
      </div>

      <div className="mt-6">
        {isLoading && items.length === 0 ? (
          <div className="space-y-3">
            {[0, 1, 2, 3].map((i) => (
              <div key={i} className="h-16 animate-pulse rounded-2xl bg-white" />
            ))}
          </div>
        ) : error && items.length === 0 ? (
          <div className="rounded-card bg-white shadow-sm">
            <EmptyState icon={WifiOff} title="Couldn't load notifications" subtitle={error} />
          </div>
        ) : items.length === 0 ? (
          <div className="rounded-card bg-white shadow-sm">
            <EmptyState icon={BellOff} title="You're all caught up." subtitle="We'll let you know when there's something new." />
          </div>
        ) : (
          BUCKET_ORDER.map(
            (key) =>
              buckets[key].length > 0 && (
                <div key={key} className="mb-6">
                  <p className="mb-2.5 text-xs font-bold text-brand-dark/40">{key}</p>
                  <div className="space-y-2.5">
                    {buckets[key].map((n) => {
                      const Icon = iconForType(n.type);
                      return (
                        <div key={n.id} className="group flex items-start gap-3 rounded-2xl bg-white p-3.5 shadow-sm">
                          <button type="button" onClick={() => markRead(n.id)} className="flex flex-1 items-start gap-3 text-left">
                            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-pale">
                              <Icon size={18} className="text-brand-accent" />
                            </span>
                            <div className="min-w-0 flex-1">
                              <p className="text-sm font-bold text-brand-dark">{n.title}</p>
                              <p className="mt-0.5 text-xs leading-relaxed text-brand-dark/55">{n.message}</p>
                              <p className="mt-1.5 text-[11px] text-brand-dark/35">{formatTime(n.created_at)}</p>
                            </div>
                          </button>
                          {!n.is_read && <span className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-brand-accent" />}
                          <button
                            type="button"
                            onClick={() => dismiss(n.id)}
                            className="opacity-0 transition-opacity group-hover:opacity-100"
                            aria-label="Dismiss"
                          >
                            <X size={14} className="text-brand-dark/30" />
                          </button>
                        </div>
                      );
                    })}
                  </div>
                </div>
              ),
          )
        )}
      </div>
    </div>
  );
}
