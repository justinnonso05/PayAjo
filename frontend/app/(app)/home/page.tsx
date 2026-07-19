"use client";

import {
  ArrowDownRight,
  ArrowUpRight,
  Calendar,
  ChevronRight,
  Copy,
  History,
  Info,
  Mail,
  MessageCircle,
  PlusCircle,
  Send,
  UserPlus,
  Users,
} from "lucide-react";
import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { EmptyState } from "@/components/app/empty-state";
import { SectionHeader } from "@/components/app/section-header";
import { StatusPill } from "@/components/app/status-pill";
import { formatAmount, formatFriendlyDate, formatShortDate, greeting } from "@/lib/format";
import { useGroups, type GroupSummary } from "@/lib/hooks/use-groups";
import { useInvites } from "@/lib/hooks/use-invites";
import { useProfile } from "@/lib/hooks/use-profile";
import { useWalletTransactions } from "@/lib/hooks/use-wallet-transactions";
import { isCreditTransaction } from "@/lib/types";

export default function HomePage() {
  const { profile } = useProfile();
  const { summaries, hasGroup, isLoading } = useGroups();
  const { items: transactions } = useWalletTransactions();
  const { invites } = useInvites();
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [mountedGreeting, setMountedGreeting] = useState("");

  useEffect(() => {
    // Computed client-side only to avoid an SSR/CSR hydration mismatch (server has no local time-of-day).
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setMountedGreeting(greeting());
  }, []);

  const clampedIndex = summaries.length === 0 ? 0 : Math.min(selectedIndex, summaries.length - 1);
  const selected = summaries[clampedIndex];

  return (
    <div className="mx-auto max-w-5xl px-6 py-8 sm:px-10 sm:py-10">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-brand-dark/50">{mountedGreeting || "Hello"},</p>
          <p className="font-display text-2xl font-bold text-brand-dark">{profile?.first_name || "there"} 👋</p>
        </div>
      </div>

      {invites.length > 0 && (
        <Link href="/invites" className="mt-5 flex items-center gap-3 rounded-2xl bg-blue-50 px-4 py-3.5 transition-colors hover:bg-blue-100">
          <Mail size={18} className="shrink-0 text-blue-500" />
          <p className="flex-1 text-sm font-bold text-brand-dark">
            {invites.length === 1 ? "You've been invited to a group" : `You've been invited to ${invites.length} groups`}
          </p>
          <ChevronRight size={16} className="text-blue-500" />
        </Link>
      )}

      <div className="mt-6">
        {isLoading && !hasGroup ? (
          <div className="h-56 animate-pulse rounded-card bg-white" />
        ) : hasGroup ? (
          <div>
            <div className="grid gap-4 sm:grid-cols-2">
              {summaries.map((summary, i) => (
                <button key={summary.group.id} type="button" onClick={() => setSelectedIndex(i)} className="text-left">
                  <GroupCard summary={summary} selected={i === clampedIndex} />
                </button>
              ))}
              <Link
                href="/join-or-create"
                className="flex min-h-[180px] flex-col items-center justify-center gap-3 rounded-card border border-dashed border-brand-dark/15 bg-white text-center transition-colors hover:border-brand-accent/40"
              >
                <span className="flex h-11 w-11 items-center justify-center rounded-full bg-brand-pale">
                  <PlusCircle size={20} className="text-brand-accent" />
                </span>
                <span className="font-display text-sm font-bold text-brand-dark">Join or Create Another Group</span>
              </Link>
            </div>
          </div>
        ) : (
          <div className="rounded-card bg-white shadow-sm">
            <EmptyState
              icon={Users}
              title="No active groups."
              subtitle="Join a group with an invite code, or start your own savings circle."
              action={
                <Link
                  href="/join-or-create"
                  className="mt-2 rounded-full bg-brand px-6 py-2.5 text-sm font-bold text-brand-dark transition-transform hover:scale-105 active:scale-95"
                >
                  Join or Create a Group
                </Link>
              }
            />
          </div>
        )}
      </div>

      {profile?.personal_reserved_account_number && (
        <div className="mt-6">
          <ReservedAccountCard bank={profile.personal_reserved_account_bank} number={profile.personal_reserved_account_number} />
        </div>
      )}

      <div className="mt-8 space-y-3">
        <SectionHeader title="Quick Actions" />
        <QuickActions groupId={selected?.group.id ?? null} isAdmin={selected?.membership.is_admin ?? false} />
      </div>

      {selected && (
        <div className="mt-8 space-y-3">
          <SectionHeader title="Upcoming Contributions" />
          <UpcomingContributions summary={selected} />
        </div>
      )}

      <div className="mt-8 space-y-3">
        <SectionHeader title="Recent Activity" />
        {transactions.length === 0 ? (
          <div className="rounded-card bg-white shadow-sm">
            <EmptyState icon={History} title="No activity yet." subtitle="Your contributions and payouts will show up here." />
          </div>
        ) : (
          <div className="divide-y divide-brand-dark/5 rounded-card bg-white shadow-sm">
            {transactions.slice(0, 5).map((tx) => {
              const credit = isCreditTransaction(tx);
              return (
                <div key={tx.id} className="flex items-center gap-3 px-5 py-4">
                  <span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full ${credit ? "bg-brand-pale" : "bg-amber-50"}`}>
                    {credit ? <ArrowDownRight size={16} className="text-brand-accent" /> : <ArrowUpRight size={16} className="text-amber-600" />}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-bold text-brand-dark">{tx.narration || tx.type}</p>
                    <p className="text-xs text-brand-dark/40">{formatShortDate(tx.created_at)}</p>
                  </div>
                  <p className={`text-sm font-bold ${credit ? "text-brand-accent" : "text-brand-dark"}`}>
                    {credit ? "+" : "-"}₦{formatAmount(tx.amount)}
                  </p>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

function GroupCard({ summary, selected }: { summary: GroupSummary; selected: boolean }) {
  const { membership, group, memberCount } = summary;
  const progress =
    group.member_cap && group.member_cap > 0 ? Math.min(1, group.pool_balance / (membership.contribution_amount * group.member_cap)) : null;

  return (
    <div
      className={`rounded-card bg-gradient-to-br from-brand to-brand-accent p-6 shadow-lg transition-all ${
        selected ? "ring-2 ring-brand-dark ring-offset-2 ring-offset-soft-gray" : ""
      }`}
    >
      <div className="flex items-start justify-between gap-3">
        <p className="truncate font-display text-lg font-bold text-brand-dark">{membership.group_name}</p>
        <span className="shrink-0 rounded-lg bg-white/50 px-2.5 py-1 text-[11px] font-bold text-brand-dark">Round {group.current_cycle_number}</span>
      </div>
      <p className="mt-1 text-sm font-semibold text-brand-dark/75">
        ₦{formatAmount(membership.contribution_amount)} • {membership.cycle_frequency ?? "—"}
      </p>

      <div className="mt-4 flex gap-6">
        <div>
          <p className="text-[11px] font-semibold text-brand-dark/70">Members</p>
          <p className="font-display text-sm font-bold text-brand-dark">{memberCount}</p>
        </div>
        <div>
          <p className="text-[11px] font-semibold text-brand-dark/70">Next payout</p>
          <p className="font-display text-sm font-bold text-brand-dark">{group.next_payout_date ? formatShortDate(group.next_payout_date) : "TBD"}</p>
        </div>
      </div>

      {progress !== null && (
        <div className="mt-4">
          <div className="h-2 overflow-hidden rounded-full bg-white/40">
            <div className="h-full rounded-full bg-brand-dark" style={{ width: `${progress * 100}%` }} />
          </div>
          <p className="mt-1.5 text-[11px] font-semibold text-brand-dark/70">₦{formatAmount(group.pool_balance)} raised so far</p>
        </div>
      )}

      <Link href={`/groups/${group.id}`} className="mt-4 flex items-center gap-1 text-xs font-bold text-brand-dark hover:underline">
        View details <ChevronRight size={14} />
      </Link>
    </div>
  );
}

function ReservedAccountCard({ bank, number }: { bank?: string | null; number: string }) {
  return (
    <div className="flex items-center gap-4 rounded-card bg-white p-5 shadow-sm">
      <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-blue-50">
        <Send size={18} className="text-blue-500" />
      </span>
      <div className="min-w-0 flex-1">
        <p className="text-[11px] font-bold uppercase text-brand-dark/40">Reserved Account</p>
        <p className="text-xs text-brand-dark/60">{bank || "—"}</p>
        <p className="font-display text-base font-bold text-brand-dark">{number}</p>
      </div>
      <button
        type="button"
        onClick={() => navigator.clipboard.writeText(number)}
        className="flex h-9 w-9 items-center justify-center rounded-full text-brand-dark/50 hover:bg-soft-gray"
        aria-label="Copy account number"
      >
        <Copy size={16} />
      </button>
    </div>
  );
}

function QuickActions({ groupId, isAdmin }: { groupId: string | null; isAdmin: boolean }) {
  const actions = [
    { icon: Send, label: "Contribute", href: groupId ? `/groups/${groupId}/contribute` : "/join-or-create", bg: "bg-brand-pale", fg: "text-brand-accent" },
    {
      icon: isAdmin ? UserPlus : Users,
      label: isAdmin ? "Invite Members" : "Members",
      href: groupId ? `/groups/${groupId}` : "/join-or-create",
      bg: "bg-blue-50",
      fg: "text-blue-500",
    },
    { icon: MessageCircle, label: "Group Chat", href: groupId ? `/groups/${groupId}/chat` : "/join-or-create", bg: "bg-amber-50", fg: "text-amber-600" },
    { icon: Info, label: "Group Details", href: groupId ? `/groups/${groupId}` : "/join-or-create", bg: "bg-soft-gray", fg: "text-brand-dark/60" },
  ];

  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
      {actions.map(({ icon: Icon, label, href, bg, fg }) => (
        <Link key={label} href={href} className="flex items-center gap-2.5 rounded-2xl bg-white px-3.5 py-3 shadow-sm transition-transform hover:-translate-y-0.5">
          <span className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full ${bg}`}>
            <Icon size={16} className={fg} />
          </span>
          <span className="truncate text-xs font-bold text-brand-dark">{label}</span>
        </Link>
      ))}
    </div>
  );
}

function UpcomingContributions({ summary }: { summary: GroupSummary }) {
  const { group, membership } = summary;
  // Lazy-initialized once per mount — the sanctioned way to capture an
  // impure "now" value without re-reading it (and re-triggering the
  // purity lint) on every render.
  const [now] = useState(() => Date.now());
  const dates = useMemo(() => {
    const anchor = group.next_payout_date ? new Date(group.next_payout_date) : new Date(now + 7 * 24 * 60 * 60 * 1000);
    const result: Date[] = [anchor];
    for (let i = 1; i < 3; i++) {
      const prev = result[result.length - 1];
      const next = new Date(prev);
      if (group.cycle_frequency === "monthly") next.setMonth(next.getMonth() + 1);
      else if (group.cycle_frequency === "yearly") next.setFullYear(next.getFullYear() + 1);
      else next.setDate(next.getDate() + 7);
      result.push(next);
    }
    return result;
  }, [group.next_payout_date, group.cycle_frequency, now]);

  return (
    <div className="divide-y divide-brand-dark/5 rounded-card bg-white shadow-sm">
      {dates.map((date, i) => (
        <div key={i} className="flex items-center gap-3 px-5 py-4">
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-pale">
            <Calendar size={16} className="text-brand-accent" />
          </span>
          <div className="min-w-0 flex-1">
            <p className="text-sm font-bold text-brand-dark">{formatFriendlyDate(date)}</p>
            <p className="text-xs text-brand-dark/50">₦{formatAmount(membership.contribution_amount)}</p>
          </div>
          <StatusPill label={i === 0 ? "Pending" : "Upcoming"} tone={i === 0 ? "warning" : "neutral"} />
        </div>
      ))}
    </div>
  );
}
