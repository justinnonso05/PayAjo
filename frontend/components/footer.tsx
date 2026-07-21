import Image from "next/image";

const LINKS = [
  { label: "Features", href: "#features" },
  { label: "FAQ", href: "#faq" },
  { label: "Privacy", href: "#" },
  { label: "Terms", href: "#" },
  { label: "Contact", href: "#" },
];

export function Footer() {
  return (
    <footer className="border-t border-brand-dark/5 bg-soft-gray px-6 py-14">
      <div className="mx-auto flex max-w-6xl flex-col items-center gap-8 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex flex-col items-center gap-3 sm:items-start">
          <div className="flex items-center gap-1.5">
            <Image src="/images/logo.png" alt="PayAjo" width={44} height={44} className="h-10 w-10 rounded-full object-cover sm:h-11 sm:w-11" />
            <span className="font-display text-xl font-extrabold tracking-tight text-brand-dark sm:text-2xl">PayAjo</span>
          </div>
          <p className="max-w-xs text-center text-sm text-brand-dark/50 sm:text-left">
            The modern way to run your Ajo or Esusu savings group.
          </p>
        </div>

        <nav className="flex flex-wrap items-center justify-center gap-x-6 gap-y-3">
          {LINKS.map((link) => (
            <a key={link.label} href={link.href} className="text-sm font-semibold text-brand-dark/60 hover:text-brand-dark">
              {link.label}
            </a>
          ))}
        </nav>
      </div>

      <p className="mx-auto mt-16 select-none text-center font-display text-[18vw] font-extrabold leading-none tracking-tight text-brand-dark/5 sm:text-[14vw] lg:text-[160px]">
        PayAjo
      </p>

      <p className="mt-10 text-center text-xs text-brand-dark/35">
        © {new Date().getFullYear()} PayAjo. All rights reserved.
      </p>
    </footer>
  );
}
