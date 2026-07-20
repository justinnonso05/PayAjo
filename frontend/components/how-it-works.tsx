import Image from "next/image";
import { Reveal } from "./reveal";

const STEPS = [
  {
    title: "Create your account",
    desc: "Sign up in minutes with your email and phone number.",
    image: "/images/create-account.png",
    bg: "bg-soft-gray",
  },
  {
    title: "Verify your identity",
    desc: "Quick BVN verification keeps every group member accountable.",
    image: "/images/secure.png",
    bg: "bg-brand-pale",
  },
  {
    title: "Create or join a savings group",
    desc: "Start your own circle or join one with an invite code.",
    image: "/images/join-group.png",
    bg: "bg-soft-gray",
  },
  {
    title: "Fund your wallet or transfer directly",
    desc: "Top up your wallet, or pay a contribution straight from your bank.",
    image: "/images/fund-wallet.png",
    bg: "bg-brand-pale",
  },
  {
    title: "Track contributions",
    desc: "See who's paid, who's pending, and where the pool stands — live.",
    image: "/images/track-contribution.png",
    bg: "bg-soft-gray",
  },
  {
    title: "Receive your payout securely",
    desc: "When it's your turn, funds land straight in your bank account.",
    image: "/images/receive-payout.png",
    bg: "bg-brand-pale",
  },
];

export function HowItWorks() {
  return (
    <section id="how-it-works" className="py-24 sm:py-32">
      <Reveal className="mx-auto max-w-6xl px-6 text-center">
        <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-accent">How it works</p>
        <h2 className="mt-4 font-display text-3xl font-bold tracking-tight text-brand-dark sm:text-4xl">
          Six steps to your first payout.
        </h2>
      </Reveal>

      <div className="mx-auto mt-16 flex max-w-6xl flex-col gap-10 px-6">
        {STEPS.map((step, i) => {
          const imageFirst = i % 2 === 0;
          return (
            <div key={step.title} className="sticky top-24" style={{ zIndex: i + 1 }}>
              <Reveal delay={i * 0.05}>
                {/* Fixed height only kicks in together with the row layout (md+) — at
                    any width in between, height must stay auto or overflow-hidden
                    clips the color panel/border/text off the top and bottom. */}
                <div className={`overflow-hidden rounded-[32px] ${step.bg} px-6 py-10 md:flex md:h-[660px] md:items-center md:px-14 md:py-0`}>
                  <div className="mx-auto flex max-w-4xl flex-col items-center gap-8 md:flex-row md:gap-16">
                    <div className={`shrink-0 ${imageFirst ? "md:order-1" : "md:order-2"}`}>
                      <div className="relative w-[190px] overflow-hidden rounded-[36px] border-[6px] border-brand-dark bg-brand-dark sm:w-[220px] md:w-[260px]">
                        <div className="relative h-[400px] w-full overflow-hidden rounded-[26px] sm:h-[460px] md:h-[540px]">
                          <Image
                            src={step.image}
                            alt={step.title}
                            fill
                            sizes="(min-width: 768px) 260px, (min-width: 640px) 220px, 190px"
                            className="object-cover object-top"
                          />
                        </div>
                      </div>
                    </div>
                    <div className={`text-center md:flex-1 md:text-left ${imageFirst ? "md:order-2" : "md:order-1"}`}>
                      <span className="text-xs font-bold uppercase tracking-[0.2em] text-brand-accent">Step {i + 1}</span>
                      <h3 className="mt-3 font-display text-2xl font-bold text-brand-dark sm:text-3xl md:text-4xl">{step.title}</h3>
                      <p className="mx-auto mt-4 max-w-md text-base leading-relaxed text-brand-dark/60 md:mx-0">
                        {step.desc}
                      </p>
                    </div>
                  </div>
                </div>
              </Reveal>
            </div>
          );
        })}
      </div>
    </section>
  );
}
