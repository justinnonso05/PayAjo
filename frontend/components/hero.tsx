"use client";

import { motion } from "framer-motion";
import { PlayCircle } from "lucide-react";
import { PhoneMockup } from "./phone-mockup";

export function Hero() {
  return (
    <section className="relative overflow-hidden pt-40 pb-24 sm:pt-48 sm:pb-32">
      {/* Abstract green gradient backdrop */}
      <div className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute -top-40 left-1/2 h-[520px] w-[520px] -translate-x-[60%] rounded-full bg-brand/30 blur-3xl" />
        <div className="absolute top-10 right-0 h-[420px] w-[420px] translate-x-1/3 rounded-full bg-brand-pale blur-3xl" />
      </div>

      <div className="mx-auto grid max-w-6xl items-center gap-16 px-6 lg:grid-cols-2">
        <div>
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
            className="inline-flex items-center gap-2 rounded-full border border-brand-dark/10 bg-white/70 px-4 py-1.5 text-xs font-bold text-brand-dark/70 backdrop-blur"
          >
            <span className="h-1.5 w-1.5 rounded-full bg-brand-accent" />
            Bank-grade savings groups, reimagined
          </motion.div>

          <motion.h1
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.1, ease: [0.22, 1, 0.36, 1] }}
            className="mt-6 font-display text-5xl font-bold leading-[1.05] tracking-tight text-brand-dark sm:text-6xl"
          >
            Save Together.
            <br />
            Grow Together.
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.2, ease: [0.22, 1, 0.36, 1] }}
            className="mt-6 max-w-lg text-lg leading-relaxed text-brand-dark/60"
          >
            A smarter way to run your Ajo or Esusu with friends, family, coworkers, and communities.
            No more chasing payments. No more missing records. No more disappearing treasurers.
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.3, ease: [0.22, 1, 0.36, 1] }}
            className="mt-9 flex flex-wrap items-center gap-4"
          >
            <a
              href="#final-cta"
              className="rounded-full bg-brand-dark px-7 py-3.5 text-sm font-bold text-white shadow-[0_8px_30px_rgba(29,49,8,0.25)] transition-transform hover:scale-105 active:scale-95"
            >
              Get Started
            </a>
            <a
              href="#how-it-works"
              className="inline-flex items-center gap-2 rounded-full px-6 py-3.5 text-sm font-bold text-brand-dark transition-colors hover:text-brand-accent"
            >
              <PlayCircle size={20} />
              Watch Demo
            </a>
          </motion.div>
        </div>

        <motion.div
          initial={{ opacity: 0, y: 40, scale: 0.96 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={{ duration: 0.9, delay: 0.25, ease: [0.22, 1, 0.36, 1] }}
          className="relative flex justify-center lg:justify-end"
        >
          <motion.div
            animate={{ y: [0, -14, 0] }}
            transition={{ duration: 5, repeat: Infinity, ease: "easeInOut" }}
          >
            <PhoneMockup />
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
}
