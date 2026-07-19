import { FeaturesGrid } from "@/components/features-grid";
import { FinalCta } from "@/components/final-cta";
import { Footer } from "@/components/footer";
import { Hero } from "@/components/hero";
import { HowItWorks } from "@/components/how-it-works";
import { Navbar } from "@/components/navbar";
import { ProblemSection } from "@/components/problem-section";
import { SolutionSection } from "@/components/solution-section";
import { TrustedBy } from "@/components/trusted-by";

export default function Home() {
  return (
    <>
      <Navbar />
      <main className="flex-1">
        <Hero />
        <TrustedBy />
        <ProblemSection />
        <SolutionSection />
        <HowItWorks />
        <FeaturesGrid />
        <FinalCta />
      </main>
      <Footer />
    </>
  );
}
