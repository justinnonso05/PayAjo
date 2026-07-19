import type { LucideIcon } from "lucide-react";
import type { ReactNode } from "react";

export function EmptyState({
  icon: Icon,
  title,
  subtitle,
  action,
}: {
  icon: LucideIcon;
  title: string;
  subtitle: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center gap-3 px-6 py-10 text-center">
      <span className="flex h-14 w-14 items-center justify-center rounded-full bg-brand-pale">
        <Icon size={24} className="text-brand-accent" />
      </span>
      <div>
        <p className="font-display text-sm font-bold text-brand-dark">{title}</p>
        <p className="mt-1 max-w-xs text-xs text-brand-dark/50">{subtitle}</p>
      </div>
      {action}
    </div>
  );
}
