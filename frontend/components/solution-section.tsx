"use client";

import { Banknote, Bell, MessageCircle, ShieldCheck, Wallet, Zap } from "lucide-react";
import { animate, motion, useMotionValue, useSpring, useTransform } from "framer-motion";
import { useEffect, useRef, useState } from "react";
import { Reveal } from "./reveal";

const FEATURES = [
  { icon: Banknote, label: "Automatic contribution tracking" },
  { icon: ShieldCheck, label: "Reserved group bank accounts" },
  { icon: Wallet, label: "Personal wallets" },
  { icon: ShieldCheck, label: "BVN verification" },
  { icon: MessageCircle, label: "Group chat" },
  { icon: Bell, label: "Contribution reminders" },
  { icon: Zap, label: "Instant payouts" },
  { icon: ShieldCheck, label: "Secure withdrawals" },
];

const MEMBERS = [
  { name: "Amara O.", status: "Paid" as const },
  { name: "Chidi E.", status: "Paid" as const },
  { name: "Ngozi K.", status: "Pending" as const },
];

function PoolCard() {
  const cardRef = useRef<HTMLDivElement>(null);
  const [inView, setInView] = useState(false);
  const [ngoziPaid, setNgoziPaid] = useState(false);
  const [amount, setAmount] = useState(0);

  // Mouse-tracking 3D tilt.
  const mouseX = useMotionValue(0.5);
  const mouseY = useMotionValue(0.5);
  const springX = useSpring(mouseX, { stiffness: 150, damping: 20 });
  const springY = useSpring(mouseY, { stiffness: 150, damping: 20 });
  const rotateX = useTransform(springY, [0, 1], [8, -8]);
  const rotateY = useTransform(springX, [0, 1], [-8, 8]);

  const handleMouseMove = (e: React.MouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    mouseX.set((e.clientX - rect.left) / rect.width);
    mouseY.set((e.clientY - rect.top) / rect.height);
  };

  const resetTilt = () => {
    mouseX.set(0.5);
    mouseY.set(0.5);
  };

  useEffect(() => {
    const el = cardRef.current;
    if (!el) return;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setInView(true);
          observer.disconnect();
        }
      },
      { threshold: 0.4 },
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!inView) return;

    const countUp = animate(0, 2_400_000, {
      duration: 1.4,
      ease: [0.16, 1, 0.3, 1],
      onUpdate: (v) => setAmount(Math.round(v)),
    });

    // After the count-up settles, simulate a real-time contribution landing —
    // demonstrates "automatic contribution tracking" instead of just describing it.
    const flip = setTimeout(() => setNgoziPaid(true), 2200);

    return () => {
      countUp.stop();
      clearTimeout(flip);
    };
  }, [inView]);

  const members = MEMBERS.map((m) => (m.name === "Ngozi K." && ngoziPaid ? { ...m, status: "Paid" as const } : m));

  return (
    <div style={{ perspective: 1000 }}>
      <motion.div
        ref={cardRef}
        onMouseMove={handleMouseMove}
        onMouseLeave={resetTilt}
        style={{ rotateX, rotateY, transformStyle: "preserve-3d" }}
        className="relative overflow-hidden rounded-card bg-gradient-to-br from-brand-dark to-[#2a4611] p-10 shadow-2xl"
      >
        <motion.div
          animate={{ x: [0, 16, -10, 0], y: [0, -12, 10, 0] }}
          transition={{ duration: 10, repeat: Infinity, ease: "easeInOut" }}
          className="absolute -right-10 -top-10 h-56 w-56 rounded-full bg-brand/20 blur-3xl"
        />
        <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand/70">Group pool</p>
        <p className="mt-3 font-display text-4xl font-extrabold text-white">₦{amount.toLocaleString()}</p>
        <p className="mt-2 text-sm font-medium text-white/50">12 members · Round 5 of 12</p>

        <div className="mt-8 space-y-3">
          {members.map((m) => (
            <motion.div
              key={m.name}
              layout
              className="flex items-center justify-between rounded-2xl bg-white/10 px-4 py-3 backdrop-blur"
            >
              <span className="text-sm font-semibold text-white/90">{m.name}</span>
              <motion.span
                key={m.status}
                initial={m.name === "Ngozi K." && ngoziPaid ? { scale: 0.6, opacity: 0 } : false}
                animate={{ scale: 1, opacity: 1 }}
                transition={{ type: "spring", stiffness: 400, damping: 15 }}
                className={`rounded-full px-3 py-1 text-xs font-bold ${
                  m.status === "Paid" ? "bg-brand text-brand-dark" : "bg-white/15 text-white/60"
                }`}
              >
                {m.status}
              </motion.span>
            </motion.div>
          ))}
        </div>
      </motion.div>
    </div>
  );
}

export function SolutionSection() {
  return (
    <section className="bg-soft-gray py-24 sm:py-32">
      <div className="mx-auto grid max-w-6xl items-center gap-14 px-6 lg:grid-cols-2">
        <Reveal>
          <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-accent">The solution</p>
          <h2 className="mt-4 font-display text-3xl font-bold tracking-tight text-brand-dark sm:text-4xl">
            Meet PayAjo.
          </h2>
          <p className="mt-4 max-w-md text-base leading-relaxed text-brand-dark/60">
            Every group gets a dedicated account, every member gets a wallet, and every contribution is tracked
            automatically — so trust is backed by a system, not just a promise.
          </p>

          <div className="mt-10 grid grid-cols-1 gap-3 sm:grid-cols-2">
            {FEATURES.map(({ icon: Icon, label }) => (
              <div key={label} className="flex items-center gap-3 rounded-2xl bg-white px-4 py-3 shadow-sm">
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-brand-pale">
                  <Icon size={15} className="text-brand-accent" />
                </span>
                <span className="text-sm font-semibold text-brand-dark/80">{label}</span>
              </div>
            ))}
          </div>
        </Reveal>

        <Reveal delay={0.15} className="relative">
          <PoolCard />
        </Reveal>
      </div>
    </section>
  );
}
