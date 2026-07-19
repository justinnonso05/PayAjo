import { AlertTriangle, EyeOff, FileWarning, Gavel, TimerOff, UserX } from "lucide-react";
import { Reveal, StaggerGroup, StaggerItem } from "./reveal";

const PROBLEMS = [
  { icon: UserX, title: "Treasurer disappears", desc: "One person holds everyone's money, and everyone's trust." },
  { icon: TimerOff, title: "Missed contributions", desc: "No system to catch who's behind until it's too late." },
  { icon: AlertTriangle, title: "No payment reminders", desc: "People forget, and the group quietly falls apart." },
  { icon: FileWarning, title: "Manual record keeping", desc: "A notebook or a chat thread isn't a ledger." },
  { icon: Gavel, title: "Money disputes", desc: "\"I paid already\" becomes a fight with no proof either way." },
  { icon: EyeOff, title: "No transparency", desc: "Members can't see the pool, the order, or where things stand." },
];

export function ProblemSection() {
  return (
    <section className="mx-auto max-w-6xl px-6 py-24 sm:py-32">
      <Reveal className="mx-auto max-w-2xl text-center">
        <h2 className="font-display text-3xl font-bold tracking-tight text-brand-dark sm:text-4xl">
          Traditional Ajo is built on trust.
          <br />
          Trust isn&apos;t always enough.
        </h2>
      </Reveal>

      <StaggerGroup className="mt-16 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
        {PROBLEMS.map(({ icon: Icon, title, desc }) => (
          <StaggerItem key={title}>
            <div className="group h-full rounded-card border border-brand-dark/5 bg-soft-gray p-7 transition-all duration-300 hover:-translate-y-1 hover:border-brand-dark/10 hover:shadow-[0_20px_40px_rgba(29,49,8,0.08)]">
              <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-white shadow-sm">
                <Icon size={20} className="text-brand-dark/60" />
              </div>
              <h3 className="mt-5 font-display text-base font-bold text-brand-dark">{title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-brand-dark/55">{desc}</p>
            </div>
          </StaggerItem>
        ))}
      </StaggerGroup>
    </section>
  );
}
