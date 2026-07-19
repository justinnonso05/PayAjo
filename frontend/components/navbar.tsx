"use client";

import { AnimatePresence, motion } from "framer-motion";
import { Menu, X } from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { useEffect, useState } from "react";

const NAV_LINKS = [
  { label: "Features", href: "#features" },
  { label: "How it Works", href: "#how-it-works" },
  { label: "Security", href: "#security" },
  { label: "FAQ", href: "#faq" },
];

export function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header className="fixed inset-x-0 top-0 z-50">
      <div
        className={`mx-auto mt-3 flex max-w-6xl items-center justify-between rounded-full px-5 py-3 transition-all duration-300 sm:mt-4 sm:px-6 ${
          scrolled
            ? "border border-black/5 bg-white/70 shadow-[0_8px_30px_rgba(29,49,8,0.08)] backdrop-blur-xl"
            : "border border-transparent bg-transparent"
        }`}
      >
        <Link href="#" className="flex items-center gap-2">
          <Image src="/images/logo.png" alt="AjoPay" width={32} height={32} className="h-8 w-8 rounded-full object-cover" priority />
          <span className="font-display text-lg font-bold text-brand-dark">AjoPay</span>
        </Link>

        <nav className="hidden items-center gap-8 md:flex">
          {NAV_LINKS.map((link) => (
            <a
              key={link.href}
              href={link.href}
              className="text-sm font-semibold text-brand-dark/70 transition-colors hover:text-brand-dark"
            >
              {link.label}
            </a>
          ))}
        </nav>

        <div className="hidden items-center gap-3 md:flex">
          <Link href="/login" className="text-sm font-semibold text-brand-dark/70 transition-colors hover:text-brand-dark">
            Sign In
          </Link>
          <Link
            href="/signup"
            className="rounded-full bg-brand px-5 py-2.5 text-sm font-bold text-brand-dark transition-transform hover:scale-105 active:scale-95"
          >
            Get Started
          </Link>
        </div>

        <button
          type="button"
          onClick={() => setMenuOpen((v) => !v)}
          className="flex h-9 w-9 items-center justify-center rounded-full text-brand-dark md:hidden"
          aria-label="Toggle menu"
        >
          {menuOpen ? <X size={20} /> : <Menu size={20} />}
        </button>
      </div>

      <AnimatePresence>
        {menuOpen && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ duration: 0.2 }}
            className="mx-4 mt-2 rounded-3xl border border-black/5 bg-white/95 p-5 shadow-xl backdrop-blur-xl md:hidden"
          >
            <div className="flex flex-col gap-4">
              {NAV_LINKS.map((link) => (
                <a
                  key={link.href}
                  href={link.href}
                  onClick={() => setMenuOpen(false)}
                  className="text-sm font-semibold text-brand-dark/80"
                >
                  {link.label}
                </a>
              ))}
              <div className="mt-2 flex flex-col gap-2 border-t border-black/5 pt-4">
                <Link href="/login" onClick={() => setMenuOpen(false)} className="text-sm font-semibold text-brand-dark/70">
                  Sign In
                </Link>
                <Link
                  href="/signup"
                  onClick={() => setMenuOpen(false)}
                  className="rounded-full bg-brand px-5 py-2.5 text-center text-sm font-bold text-brand-dark"
                >
                  Get Started
                </Link>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </header>
  );
}
