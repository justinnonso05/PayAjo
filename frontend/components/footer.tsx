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
          <div className="flex items-center gap-2">
            <Image src="/images/logo.png" alt="AjoPay" width={32} height={32} className="h-8 w-8 rounded-full object-cover" />
            <span className="font-display text-lg font-bold text-brand-dark">AjoPay</span>
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

      <p className="mt-10 text-center text-xs text-brand-dark/35">
        © {new Date().getFullYear()} AjoPay. All rights reserved.
      </p>
    </footer>
  );
}
