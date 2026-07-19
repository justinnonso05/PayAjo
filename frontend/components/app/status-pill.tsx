type Tone = "success" | "warning" | "danger" | "info" | "neutral";

const TONE_CLASSES: Record<Tone, string> = {
  success: "bg-brand-pale text-brand-accent",
  warning: "bg-amber-50 text-amber-600",
  danger: "bg-red-50 text-red-500",
  info: "bg-blue-50 text-blue-500",
  neutral: "bg-soft-gray text-brand-dark/50",
};

export function StatusPill({ label, tone = "neutral" }: { label: string; tone?: Tone }) {
  return <span className={`rounded-full px-2.5 py-1 text-[10.5px] font-bold capitalize ${TONE_CLASSES[tone]}`}>{label}</span>;
}
