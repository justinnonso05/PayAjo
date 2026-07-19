"use client";

import { Bell, Home, User, Wallet } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useHasUnreadNotifications } from "@/lib/hooks/use-has-unread-notifications";

const NAV_ITEMS = [
  { href: "/home", label: "Home", icon: Home },
  { href: "/wallet", label: "Wallet", icon: Wallet },
  { href: "/notifications", label: "Alerts", icon: Bell },
  { href: "/profile", label: "Profile", icon: User },
];

export function MobileNav() {
  const pathname = usePathname();
  const hasUnread = useHasUnreadNotifications();

  return (
    <nav className="fixed inset-x-0 bottom-0 z-40 flex items-center justify-around border-t border-brand-dark/5 bg-white/95 px-2 py-2.5 backdrop-blur-xl lg:hidden">
      {NAV_ITEMS.map(({ href, label, icon: Icon }) => {
        const active = pathname === href || pathname.startsWith(`${href}/`);
        return (
          <Link
            key={href}
            href={href}
            className={`flex flex-col items-center gap-1 rounded-xl px-4 py-1.5 text-[11px] font-bold transition-colors ${
              active ? "text-brand-accent" : "text-brand-dark/40"
            }`}
          >
            <span className="relative">
              <Icon size={20} />
              {href === "/notifications" && hasUnread && <span className="absolute -right-0.5 -top-0.5 h-2 w-2 rounded-full bg-red-500" />}
            </span>
            {label}
          </Link>
        );
      })}
    </nav>
  );
}
