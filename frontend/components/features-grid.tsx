import { ArrowLeftRight, Bell, Clock, Hash, MessageCircle, Repeat, Send, User, Wallet, Zap } from "lucide-react";
import { Reveal, StaggerGroup, StaggerItem } from "./reveal";

const FEATURES = [
  { icon: Wallet, title: "Personal Wallet", desc: "Deposit once. Pay contributions seamlessly across all your savings groups." },
  { icon: MessageCircle, title: "Group Chat", desc: "Built-in chat with image sharing to stay connected with group members." },
  { icon: Bell, title: "Smart Reminders", desc: "Timely push alerts so you never miss a contribution deadline." },
  { icon: User, title: "BVN Verification", desc: "Identity verification so you only save with people you can trust." },
  { icon: Clock, title: "Transaction History", desc: "Every payment is recorded, timestamped, and visible to all members." },
  { icon: Hash, title: "Invite Code", desc: "Join private or public savings groups instantly with a simple code." },
  { icon: ArrowLeftRight, title: "Cycle Swapping", desc: "Trade payout turns effortlessly with another member when life happens." },
  { icon: Send, title: "Payout Delegation", desc: "Send your payout directly to a friend or family member's wallet." },
  { icon: Zap, title: "Automated Payouts", desc: "Instant bank disbursement as soon as a round completes — zero manual chasing." },
  { icon: Repeat, title: "Auto-Debit", desc: "Enable automatic wallet debiting before deadlines so no member defaults." },
];

export function FeaturesGrid() {
  return (
    <section id="features" className="mx-auto max-w-6xl px-6 py-24 sm:py-32">
      <Reveal className="mx-auto max-w-2xl text-center">
        <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-accent">Everything you need</p>
        <h2 className="mt-4 font-display text-3xl font-bold tracking-tight text-brand-dark sm:text-4xl">
          One app, every part of your Ajo.
        </h2>
      </Reveal>

      <StaggerGroup className="mt-16 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
        {FEATURES.map(({ icon: Icon, title, desc }) => (
          <StaggerItem key={title}>
            <div className="group relative h-full cursor-pointer overflow-hidden rounded-card border border-brand-dark/5 bg-white p-6 shadow-sm transition-all duration-300 hover:-translate-y-1 hover:shadow-[0_20px_40px_rgba(29,49,8,0.15)] active:-translate-y-1 active:shadow-[0_20px_40px_rgba(29,49,8,0.15)]">
              {/* Diagonal color wipe: scales in from the bottom-left corner on hover. */}
              <span
                aria-hidden
                className="pointer-events-none absolute inset-0 origin-bottom-left scale-0 rounded-card bg-gradient-to-br from-brand-dark to-[#2a4611] transition-transform duration-300 ease-out group-hover:scale-[2.5] group-active:scale-[2.5]"
              />
              <div className="relative">
                <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-brand-pale transition-colors duration-300 group-hover:bg-white/15 group-active:bg-white/15">
                  <Icon size={20} className="text-brand-accent transition-colors duration-300 group-hover:text-brand group-active:text-brand" />
                </div>
                <h3 className="mt-5 font-display text-sm font-bold text-brand-dark transition-colors duration-300 group-hover:text-white group-active:text-white">
                  {title}
                </h3>
                <p className="mt-2 text-xs leading-relaxed text-brand-dark/55 transition-colors duration-300 group-hover:text-white/70 group-active:text-white/70">
                  {desc}
                </p>
              </div>
            </div>
          </StaggerItem>
        ))}
      </StaggerGroup>
    </section>
  );
}
