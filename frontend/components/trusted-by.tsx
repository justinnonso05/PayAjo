import { Reveal } from "./reveal";

const GROUPS = ["Friends", "Families", "Churches", "Cooperatives", "Market Associations", "Small Businesses", "Communities"];

export function TrustedBy() {
  return (
    <section className="border-y border-brand-dark/5 bg-soft-gray py-10">
      <Reveal className="mx-auto max-w-6xl px-6">
        <p className="text-center text-xs font-bold uppercase tracking-[0.2em] text-brand-dark/40">Built for</p>
        <div className="mt-5 flex flex-wrap items-center justify-center gap-x-8 gap-y-3">
          {GROUPS.map((g) => (
            <span key={g} className="text-sm font-semibold text-brand-dark/50">
              {g}
            </span>
          ))}
        </div>
      </Reveal>
    </section>
  );
}
