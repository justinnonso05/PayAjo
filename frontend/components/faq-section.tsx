"use client";

import { ChevronDown } from "lucide-react";
import { useState } from "react";
import { Reveal } from "./reveal";

const FAQS = [
  {
    q: "How does PayAjo work?",
    a: "Create or join a savings group, agree on a contribution amount and frequency, and each round every member contributes into the pool. One member receives the full payout each round, rotating until everyone has been paid.",
  },
  {
    q: "Is my money safe?",
    a: "Yes. Contributions and wallet balances sit in bank-partnered virtual accounts, every member is BVN-verified before joining a group, and every payment is confirmed with your transaction PIN.",
  },
  {
    q: "What if I need money earlier than my scheduled payout turn?",
    a: "You can send a Cycle Swap request to swap turns with another willing member in your group. Once approved by the member and admin, your payout positions are swapped seamlessly.",
  },
  {
    q: "What happens if a member forgets to contribute on time?",
    a: "Members can enable Auto-Debit so contributions are automatically paid from their wallet before the deadline. Admins can also trigger instant push reminders to anyone who owes.",
  },
  {
    q: "What is a Reserved Account?",
    a: "A dedicated virtual bank account number tied to your personal wallet. Transfer any amount to it from any bank app, and it lands in your PayAjo wallet automatically.",
  },
  {
    q: "Can I withdraw anytime?",
    a: "Yes — once you've set up a payout bank, your wallet balance can be withdrawn anytime, straight to your bank account.",
  },
  {
    q: "Do I need BVN?",
    a: "Yes. BVN verification is required for every member so groups stay secure and everyone in the circle is a verified real person.",
  },
  {
    q: "How do payouts work?",
    a: "Each round's contributions are pooled together. The member whose turn it is — set when the group starts, either randomized or in a manual order — receives the full pool as an automated payout straight to their bank account.",
  },
  {
    q: "Are there any hidden fees or charges?",
    a: "No hidden fees. Creating groups, joining groups, and receiving payouts are completely free.",
  },
  {
    q: "Can I join multiple groups?",
    a: "Yes. You can belong to as many savings groups as you like, each with its own contribution amount, frequency, and payout schedule.",
  },
];

export function FaqSection() {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <section id="faq" className="mx-auto max-w-3xl px-6 py-24 sm:py-32">
      <Reveal className="text-center">
        <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-accent">FAQ</p>
        <h2 className="mt-4 font-display text-3xl font-bold tracking-tight text-brand-dark sm:text-4xl">Questions? We&apos;ve got answers.</h2>
      </Reveal>

      <Reveal delay={0.1} className="mt-12 space-y-3">
        {FAQS.map((item, i) => {
          const isOpen = openIndex === i;
          return (
            <div key={item.q} className="overflow-hidden rounded-2xl border border-brand-dark/5 bg-soft-gray">
              <button
                type="button"
                onClick={() => setOpenIndex(isOpen ? null : i)}
                className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left"
              >
                <span className="font-display text-sm font-bold text-brand-dark sm:text-base">{item.q}</span>
                <ChevronDown size={18} className={`shrink-0 text-brand-dark/40 transition-transform duration-300 ${isOpen ? "rotate-180" : ""}`} />
              </button>
              <div
                className="grid transition-all duration-300 ease-in-out"
                style={{ gridTemplateRows: isOpen ? "1fr" : "0fr" }}
              >
                <div className="overflow-hidden">
                  <p className="px-5 pb-4 text-sm leading-relaxed text-brand-dark/60">{item.a}</p>
                </div>
              </div>
            </div>
          );
        })}
      </Reveal>
    </section>
  );
}
