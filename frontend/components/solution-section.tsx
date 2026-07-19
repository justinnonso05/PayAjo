import { Banknote, Bell, MessageCircle, ShieldCheck, Wallet, Zap } from "lucide-react";
import { Reveal, StaggerGroup, StaggerItem } from "./reveal";

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

export function SolutionSection() {
  return (
    <section className="bg-soft-gray py-24 sm:py-32">
      <div className="mx-auto grid max-w-6xl items-center gap-14 px-6 lg:grid-cols-2">
        <Reveal>
          <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-accent">The solution</p>
          <h2 className="mt-4 font-display text-3xl font-bold tracking-tight text-brand-dark sm:text-4xl">
            Meet AjoPay.
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
          <div className="relative overflow-hidden rounded-card bg-gradient-to-br from-brand-dark to-[#2a4611] p-10 shadow-2xl">
            <div className="absolute -right-10 -top-10 h-56 w-56 rounded-full bg-brand/20 blur-3xl" />
            <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand/70">Group pool</p>
            <p className="mt-3 font-display text-4xl font-extrabold text-white">₦2,400,000</p>
            <p className="mt-2 text-sm font-medium text-white/50">12 members · Round 5 of 12</p>

            <div className="mt-8 space-y-3">
              {[
                { name: "Amara O.", status: "Paid" },
                { name: "Chidi E.", status: "Paid" },
                { name: "Ngozi K.", status: "Pending" },
              ].map((m) => (
                <div key={m.name} className="flex items-center justify-between rounded-2xl bg-white/10 px-4 py-3 backdrop-blur">
                  <span className="text-sm font-semibold text-white/90">{m.name}</span>
                  <span
                    className={`rounded-full px-3 py-1 text-xs font-bold ${
                      m.status === "Paid" ? "bg-brand text-brand-dark" : "bg-white/15 text-white/60"
                    }`}
                  >
                    {m.status}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
