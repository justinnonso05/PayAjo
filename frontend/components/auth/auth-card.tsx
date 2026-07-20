import Image from "next/image";
import Link from "next/link";
import type { ReactNode } from "react";

export function AuthCard({
  title,
  subtitle,
  children,
  footer,
}: {
  title: string;
  subtitle: string;
  children: ReactNode;
  footer?: ReactNode;
}) {
  return (
    <main className="relative flex min-h-screen items-center justify-center overflow-hidden px-6 py-16">
      <div className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute -top-32 left-1/2 h-[420px] w-[420px] -translate-x-1/2 rounded-full bg-brand/25 blur-3xl" />
      </div>

      <div className="w-full max-w-md">
        <Link href="/" className="mb-8 flex items-center justify-center gap-2">
          <Image src="/images/logo.png" alt="PayAjo" width={32} height={32} className="h-8 w-8 rounded-full object-cover" />
          <span className="font-display text-lg font-bold text-brand-dark">PayAjo</span>
        </Link>

        <div className="rounded-card border border-brand-dark/5 bg-white p-8 shadow-[0_20px_60px_rgba(29,49,8,0.08)] sm:p-10">
          <h1 className="font-display text-2xl font-bold text-brand-dark">{title}</h1>
          <p className="mt-1.5 text-sm text-brand-dark/55">{subtitle}</p>

          <div className="mt-8">{children}</div>
        </div>

        {footer && <p className="mt-6 text-center text-sm text-brand-dark/55">{footer}</p>}
      </div>
    </main>
  );
}
