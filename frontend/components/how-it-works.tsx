"use client";

import { AnimatePresence, motion } from "framer-motion";
import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { Reveal } from "./reveal";

const STEPS = [
  {
    title: "Create your account",
    desc: "Sign up in minutes with your email and phone number.",
    image: "/images/create-account.png",
  },
  {
    title: "Verify your identity",
    desc: "Quick BVN verification keeps every group member accountable.",
    image: "/images/secure.png",
  },
  {
    title: "Create or join a savings group",
    desc: "Start your own circle or join one with an invite code.",
    image: "/images/join-group.png",
  },
  {
    title: "Fund your wallet or transfer directly",
    desc: "Top up your wallet, or pay a contribution straight from your bank.",
    image: "/images/fund-wallet.png",
  },
  {
    title: "Track contributions",
    desc: "See who's paid, who's pending, and where the pool stands — live.",
    image: "/images/track-contribution.png",
  },
  {
    title: "Receive your payout securely",
    desc: "When it's your turn, funds land straight in your bank account.",
    image: "/images/receive-payout.png",
  },
];

const AUTO_ADVANCE_MS = 4000;

export function HowItWorks() {
  const [active, setActive] = useState(0);
  const [isPaused, setIsPaused] = useState(false);

  // Auto-advances through the steps to draw the eye, but backs off for a
  // while after the visitor manually picks a step so it doesn't fight them.
  useEffect(() => {
    if (isPaused) return;
    const id = setInterval(() => {
      setActive((i) => (i + 1) % STEPS.length);
    }, AUTO_ADVANCE_MS);
    return () => clearInterval(id);
  }, [isPaused]);

  const resumeTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);

  const selectStep = (i: number) => {
    setActive(i);
    setIsPaused(true);
    if (resumeTimeout.current) clearTimeout(resumeTimeout.current);
    resumeTimeout.current = setTimeout(() => setIsPaused(false), AUTO_ADVANCE_MS * 3);
  };

  useEffect(() => {
    return () => {
      if (resumeTimeout.current) clearTimeout(resumeTimeout.current);
    };
  }, []);

  return (
    <section id="how-it-works" className="mx-auto max-w-6xl px-6 py-24 sm:py-32">
      <Reveal className="text-center">
        <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-accent">How it works</p>
        <h2 className="mt-4 font-display text-3xl font-bold tracking-tight text-brand-dark sm:text-4xl">
          Six steps to your first payout.
        </h2>
      </Reveal>

      <div className="mt-16 grid gap-16 lg:grid-cols-[1fr_auto] lg:items-start lg:gap-20">
        <div className="relative order-2 lg:order-1">
          <div className="absolute left-5 top-2 bottom-2 w-px bg-brand-dark/10 sm:left-6" />
          <div className="space-y-3">
            {STEPS.map((step, i) => {
              const isActive = i === active;
              return (
                <Reveal key={step.title} delay={i * 0.05}>
                  <button
                    type="button"
                    onClick={() => selectStep(i)}
                    className={`relative flex w-full items-start gap-6 overflow-hidden rounded-2xl px-3 py-3 text-left transition-colors ${
                      isActive ? "bg-brand-pale" : "hover:bg-soft-gray"
                    }`}
                  >
                    {isActive && !isPaused && (
                      <motion.span
                        key={active}
                        initial={{ scaleX: 0 }}
                        animate={{ scaleX: 1 }}
                        transition={{ duration: AUTO_ADVANCE_MS / 1000, ease: "linear" }}
                        className="absolute inset-x-0 bottom-0 h-0.5 origin-left bg-brand-accent"
                      />
                    )}
                    <span
                      className={`relative z-10 flex h-10 w-10 shrink-0 items-center justify-center rounded-full font-display text-sm font-bold transition-colors sm:h-12 sm:w-12 ${
                        isActive ? "bg-brand-dark text-white" : "bg-white text-brand-dark/40 ring-1 ring-brand-dark/10"
                      }`}
                    >
                      {i + 1}
                    </span>
                    <span className="pt-1.5">
                      <h3 className={`font-display text-lg font-bold ${isActive ? "text-brand-dark" : "text-brand-dark/70"}`}>
                        {step.title}
                      </h3>
                      <p className="mt-1.5 text-sm leading-relaxed text-brand-dark/55">{step.desc}</p>
                    </span>
                  </button>
                </Reveal>
              );
            })}
          </div>
        </div>

        <div className="order-1 lg:sticky lg:top-24 lg:order-2">
          <div className="relative mx-auto w-[240px] overflow-hidden rounded-[36px] border-[5px] border-brand-dark bg-brand-dark shadow-2xl sm:w-[280px]">
            <div className="relative h-[500px] w-full overflow-hidden rounded-[28px] sm:h-[580px]">
              <AnimatePresence mode="sync">
                <motion.div
                  key={active}
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.35, ease: [0.22, 1, 0.36, 1] }}
                  className="absolute inset-0"
                >
                  <Image
                    src={STEPS[active].image}
                    alt={STEPS[active].title}
                    fill
                    sizes="(min-width: 640px) 280px, 240px"
                    className="object-cover object-top"
                  />
                </motion.div>
              </AnimatePresence>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
