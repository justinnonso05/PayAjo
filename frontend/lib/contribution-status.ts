import type { Group, WalletTransaction } from "./types";

/** The backend doesn't expose a "have I paid this round" flag directly, so
 * this infers it from wallet history: a contribution-type transaction for
 * this group that landed after the group record last changed (which
 * happens whenever the round advances). Mirrors the mobile app's heuristic. */
export function hasPaidCurrentRound(group: Group, transactions: WalletTransaction[]): boolean {
  const roundStartedAt = group.updated_at ?? group.started_at;
  return transactions.some((t) => {
    if (t.related_group_id !== group.id) return false;
    if (!t.type.toLowerCase().includes("contribution")) return false;
    if (!roundStartedAt) return true;
    return new Date(t.created_at) >= new Date(roundStartedAt);
  });
}
