"use client";

import { Bell, Check, Copy, Home, LogOut, User, Wallet } from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useState } from "react";
import { clearToken } from "@/lib/auth";
import { useHasUnreadNotifications } from "@/lib/hooks/use-has-unread-notifications";
import type { Profile } from "@/lib/types";

const NAV_ITEMS = [
  { href: "/home", label: "Home", icon: Home },
  { href: "/wallet", label: "Wallet", icon: Wallet },
  { href: "/notifications", label: "Notifications", icon: Bell },
  { href: "/profile", label: "Profile", icon: User },
];

export function Sidebar({ profile }: { profile: Profile | null }) {
  const pathname = usePathname();
  const router = useRouter();
  const hasUnread = useHasUnreadNotifications();
  const [copiedUsername, setCopiedUsername] = useState(false);

  const handleLogout = () => {
    clearToken();
    router.push("/");
  };

  const handleCopyUsername = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (!profile?.username) return;
    navigator.clipboard.writeText(profile.username);
    setCopiedUsername(true);
    setTimeout(() => setCopiedUsername(false), 2000);
  };

  return (
    <aside className="fixed inset-y-0 left-0 z-40 hidden w-64 flex-col border-r border-brand-dark/5 bg-white px-5 py-6 lg:flex">
      <Link href="/home" className="flex items-center gap-2 px-2">
        <Image src="/images/logo.png" alt="AjoPay" width={32} height={32} className="h-8 w-8 rounded-full object-cover" />
        <span className="font-display text-lg font-bold text-brand-dark">AjoPay</span>
      </Link>

      <nav className="mt-10 flex flex-col gap-1">
        {NAV_ITEMS.map(({ href, label, icon: Icon }) => {
          const active = pathname === href || pathname.startsWith(`${href}/`);
          return (
            <Link
              key={href}
              href={href}
              className={`flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-bold transition-colors ${
                active ? "bg-brand-pale text-brand-dark" : "text-brand-dark/50 hover:bg-soft-gray hover:text-brand-dark"
              }`}
            >
              <span className="relative">
                <Icon size={18} />
                {href === "/notifications" && hasUnread && <span className="absolute -right-0.5 -top-0.5 h-2 w-2 rounded-full bg-red-500" />}
              </span>
              {label}
            </Link>
          );
        })}
      </nav>

      <div className="mt-auto flex flex-col gap-3">
        {profile && (
          <Link
            href="/profile"
            className="flex items-center gap-3 rounded-xl bg-soft-gray px-3 py-3 transition-colors hover:bg-black/5"
          >
            {profile.avatar_url ? (
              // eslint-disable-next-line @next/next/no-img-element -- remote user uploaded avatar URL
              <img
                src={profile.avatar_url}
                alt={`${profile.first_name} ${profile.last_name}`}
                className="h-9 w-9 shrink-0 rounded-full object-cover"
              />
            ) : (
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand font-display text-sm font-bold text-brand-dark">
                {profile.first_name?.[0]?.toUpperCase() ?? "?"}
              </span>
            )}
            <div className="min-w-0 flex-1">
              <p className="truncate text-xs font-bold text-brand-dark">
                {profile.first_name} {profile.last_name}
              </p>
              <div className="flex items-center gap-1.5">
                <p className="truncate text-[11px] text-brand-dark/50">@{profile.username}</p>
                <button
                  type="button"
                  onClick={handleCopyUsername}
                  title="Copy username"
                  className="rounded p-0.5 text-brand-dark/40 transition-colors hover:bg-black/10 hover:text-brand-dark"
                >
                  {copiedUsername ? <Check size={12} className="text-brand-accent" /> : <Copy size={12} />}
                </button>
              </div>
            </div>
          </Link>
        )}
        <button
          type="button"
          onClick={handleLogout}
          className="flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-bold text-brand-dark/50 transition-colors hover:bg-soft-gray hover:text-brand-dark"
        >
          <LogOut size={18} />
          Log out
        </button>
      </div>
    </aside>
  );
}
