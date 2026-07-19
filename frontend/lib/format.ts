/** Formats a numeric amount with thousands separators, e.g. 12345.5 -> "12,345.50". */
export function formatAmount(amount: number): string {
  const isWhole = Number.isInteger(amount);
  const value = isWhole ? amount.toFixed(0) : amount.toFixed(2);
  const [intPart, decimalPart] = value.split(".");
  const withCommas = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return decimalPart ? `${withCommas}.${decimalPart}` : withCommas;
}

export function formatShortDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "—";
  return date.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
}

export function formatDateTime(iso: string | null | undefined): string {
  if (!iso) return "—";
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "—";
  return date.toLocaleString("en-GB", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
}

/** Time-of-day greeting — computed client-side, so wrap callers in a mount check to avoid an SSR/CSR hydration mismatch. */
export function greeting(now: Date = new Date()): string {
  const hour = now.getHours();
  if (hour < 12) return "Good Morning";
  if (hour < 17) return "Good Afternoon";
  return "Good Evening";
}

const WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

function ordinal(day: number): string {
  if (day >= 11 && day <= 13) return `${day}th`;
  switch (day % 10) {
    case 1:
      return `${day}st`;
    case 2:
      return `${day}nd`;
    case 3:
      return `${day}rd`;
    default:
      return `${day}th`;
  }
}

/** e.g. "Friday, 17th July" */
export function formatFriendlyDate(date: Date): string {
  return `${WEEKDAYS[(date.getDay() + 6) % 7]}, ${ordinal(date.getDate())} ${date.toLocaleDateString("en-GB", { month: "long" })}`;
}

/** e.g. "3:45 PM" */
export function formatTime(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "—";
  return date.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit", hour12: true });
}

/** Buckets a timestamp into Today / Yesterday / Earlier for notification-style feeds. */
export function dayBucket(iso: string, now: Date = new Date()): "Today" | "Yesterday" | "Earlier" {
  const date = new Date(iso);
  const target = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const diffDays = Math.round((today.getTime() - target.getTime()) / 86_400_000);
  if (diffDays === 0) return "Today";
  if (diffDays === 1) return "Yesterday";
  return "Earlier";
}
