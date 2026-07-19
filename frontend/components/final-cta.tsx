import Link from "next/link";
import { Reveal } from "./reveal";

export function FinalCta() {
  return (
    <section id="final-cta" className="px-6 py-24 sm:py-32">
      <Reveal className="relative mx-auto max-w-5xl overflow-hidden rounded-card bg-brand-dark px-8 py-16 text-center sm:px-16 sm:py-20">
        <div className="pointer-events-none absolute -top-24 left-1/2 h-72 w-72 -translate-x-1/2 rounded-full bg-brand/20 blur-3xl" />
        <h2 className="relative font-display text-3xl font-bold tracking-tight text-white sm:text-4xl">
          Ready to modernize your savings group?
        </h2>
        <p className="relative mx-auto mt-4 max-w-md text-base text-white/60">
          Join thousands running their Ajo the smarter way — transparent, automatic, and always on time.
        </p>
        <div className="relative mt-9 flex flex-wrap items-center justify-center gap-4">
          <Link
            href="/signup"
            className="rounded-full bg-brand px-7 py-3.5 text-sm font-bold text-brand-dark shadow-lg transition-transform hover:scale-105 active:scale-95"
          >
            Create Free Account
          </Link>
          <a
            href="#"
            className="rounded-full border border-white/20 px-7 py-3.5 text-sm font-bold text-white transition-colors hover:bg-white/10"
          >
            Download App
          </a>
        </div>
      </Reveal>
    </section>
  );
}
