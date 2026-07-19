"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { MobileNav } from "@/components/app/mobile-nav";
import { Sidebar } from "@/components/app/sidebar";
import { useProfile } from "@/lib/hooks/use-profile";
import { getToken } from "@/lib/auth";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const { profile } = useProfile();

  useEffect(() => {
    if (!getToken()) router.replace("/login");
  }, [router]);

  return (
    <div className="min-h-screen bg-soft-gray">
      <Sidebar profile={profile} />
      <main className="pb-24 lg:ml-64 lg:pb-0">{children}</main>
      <MobileNav />
    </div>
  );
}
