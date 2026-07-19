import { Reveal } from "./reveal";

const STEPS = [
  { title: "Create your account", desc: "Sign up in minutes with your email and phone number." },
  { title: "Verify your identity", desc: "Quick BVN verification keeps every group member accountable." },
  { title: "Create or join a savings group", desc: "Start your own circle or join one with an invite code." },
  { title: "Fund your wallet or transfer directly", desc: "Top up your wallet, or pay a contribution straight from your bank." },
  { title: "Track contributions", desc: "See who's paid, who's pending, and where the pool stands — live." },
  { title: "Receive your payout securely", desc: "When it's your turn, funds land straight in your bank account." },
];

export function HowItWorks() {
  return (
    <section id="how-it-works" className="mx-auto max-w-4xl px-6 py-24 sm:py-32">
      <Reveal className="text-center">
        <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-accent">How it works</p>
        <h2 className="mt-4 font-display text-3xl font-bold tracking-tight text-brand-dark sm:text-4xl">
          Six steps to your first payout.
        </h2>
      </Reveal>

      <div className="relative mt-16">
        <div className="absolute left-5 top-2 bottom-2 w-px bg-brand-dark/10 sm:left-6" />
        <div className="space-y-10">
          {STEPS.map((step, i) => (
            <Reveal key={step.title} delay={i * 0.05} className="relative flex gap-6 pl-0">
              <div className="relative z-10 flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-dark font-display text-sm font-bold text-white sm:h-12 sm:w-12">
                {i + 1}
              </div>
              <div className="pt-1.5">
                <h3 className="font-display text-lg font-bold text-brand-dark">{step.title}</h3>
                <p className="mt-1.5 text-sm leading-relaxed text-brand-dark/55">{step.desc}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
