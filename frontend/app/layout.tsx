import type { Metadata } from "next";
import { Space_Grotesk, Plus_Jakarta_Sans } from "next/font/google";
import "./globals.css";

const spaceGrotesk = Space_Grotesk({
  variable: "--font-space-grotesk",
  subsets: ["latin"],
  weight: ["500", "600", "700"],
});

const plusJakartaSans = Plus_Jakarta_Sans({
  variable: "--font-plus-jakarta",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
});

// VERCEL_URL is a unique per-deployment hostname that changes on every push
// (and can sit behind Vercel's preview-auth wall) — VERCEL_PROJECT_PRODUCTION_URL
// is the stable production domain, which is what social-media link crawlers
// actually need to be able to reach.
const siteUrl = process.env.NEXT_PUBLIC_SITE_URL
  ? process.env.NEXT_PUBLIC_SITE_URL
  : process.env.VERCEL_PROJECT_PRODUCTION_URL
  ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
  : "https://payajo.vercel.app";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: "PayAjo — Save Together. Grow Together.",
  description:
    "A smarter way to run your Ajo or Esusu with friends, family, coworkers, and communities. No more chasing payments, missing records, or disappearing treasurers.",
  openGraph: {
    title: "PayAjo — Save Together. Grow Together.",
    description:
      "A smarter way to run your Ajo or Esusu with friends, family, coworkers, and communities. No more chasing payments, missing records, or disappearing treasurers.",
    url: siteUrl,
    siteName: "PayAjo",
    images: [
      {
        url: "/images/og-banner.jpg",
        width: 1200,
        height: 675,
        type: "image/jpeg",
        alt: "PayAjo — Save Together. Grow Together.",
      },
    ],
    locale: "en_NG",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "PayAjo — Save Together. Grow Together.",
    description:
      "A smarter way to run your Ajo or Esusu with friends, family, coworkers, and communities.",
    images: ["/images/og-banner.jpg"],
  },
  icons: {
    icon: [
      { url: "/images/logo.png", type: "image/png" },
      { url: "/favicon.ico" },
    ],
    shortcut: "/images/logo.png",
    apple: "/images/logo.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${spaceGrotesk.variable} ${plusJakartaSans.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col bg-white text-[#1D3108] font-sans">{children}</body>
    </html>
  );
}
