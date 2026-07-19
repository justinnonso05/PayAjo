import Image from "next/image";

/** Real app screenshot wrapped in a simple device frame. */
export function PhoneMockup({ className }: { className?: string }) {
  return (
    <div className={className}>
      <div className="relative mx-auto w-[280px] overflow-hidden rounded-[44px] border-[10px] border-brand-dark bg-brand-dark shadow-2xl sm:w-[320px]">
        <div className="absolute left-1/2 top-0 z-10 h-6 w-32 -translate-x-1/2 rounded-b-2xl bg-brand-dark" />
        <div className="relative h-[580px] w-full overflow-hidden rounded-[34px] sm:h-[640px]">
          <Image
            src="/images/simulator.png"
            alt="AjoPay app — Home screen"
            fill
            sizes="(min-width: 640px) 320px, 280px"
            className="object-cover object-top"
            priority
          />
        </div>
      </div>
    </div>
  );
}
