import Image from "next/image";

/** Real app screenshot wrapped in a simple device frame. */
export function PhoneMockup({ className }: { className?: string }) {
  return (
    <div className={className}>
      <div className="relative mx-auto w-[280px] overflow-hidden rounded-[44px] border-[5px] border-brand-dark bg-brand-dark shadow-2xl sm:w-[320px]">
        <div className="relative h-[580px] w-full overflow-hidden rounded-[34px] sm:h-[640px]">
          <Image
            src="/images/simulator.png"
            alt="PayAjo app — Home screen"
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
