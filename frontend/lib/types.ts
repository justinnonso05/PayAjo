// Raw shapes as returned by the backend (snake_case), mirroring the mobile
// app's Dart models one-to-one so both clients stay in sync with the API.

export type CycleFrequency = "weekly" | "monthly" | "yearly";

export type Profile = {
  id: string;
  username: string;
  first_name: string;
  last_name: string;
  email: string;
  phone?: string | null;
  wallet_balance: string;
  personal_reserved_account_number?: string | null;
  personal_reserved_account_bank?: string | null;
  personal_reserved_account_name?: string | null;
  kyc_status: boolean;
  has_wallet: boolean;
  has_pin: boolean;
  payout_bank_account_number?: string | null;
  payout_bank_code?: string | null;
  payout_account_name?: string | null;
};

export type GroupMembership = {
  membership_id: string;
  is_admin: boolean;
  membership_status: string;
  joined_at: string;
  group_id: string;
  group_name: string;
  contribution_amount: number;
  cycle_frequency: CycleFrequency | null;
  group_status: string;
  pool_balance: number;
};

export type Group = {
  id: string;
  name: string;
  contribution_amount: number;
  cycle_frequency: CycleFrequency | null;
  status: string;
  admin_user_id: string;
  invite_code: string | null;
  invite_code_active: boolean;
  pool_balance: number;
  member_cap: number | null;
  current_cycle_number: number;
  current_rotation_index: number;
  created_at: string | null;
  started_at: string | null;
  next_payout_date: string | null;
  updated_at: string | null;
};

export type GroupMember = {
  id: string;
  user_id: string;
  is_admin: boolean;
  status: string;
  joined_at: string;
  first_name: string;
  last_name: string;
  username: string;
};

export type PendingMember = GroupMember;

export type GroupInvite = {
  id: string;
  group_id: string;
  invited_user_id: string;
  invited_by_user_id: string;
  status: string;
  resolved_at: string | null;
  created_at: string;
};

export type WalletTransaction = {
  id: string;
  type: string;
  amount: number;
  related_group_id?: string | null;
  narration?: string | null;
  created_at: string;
};

const CREDIT_KEYWORDS = ["deposit", "topup", "payout", "refund", "credit", "received", "reversal"];
const DEBIT_KEYWORDS = ["withdraw", "contribution", "debit", "payment"];

export function isCreditTransaction(tx: WalletTransaction): boolean {
  const t = tx.type.toLowerCase().replace(/[_-]/g, "");
  if (DEBIT_KEYWORDS.some((k) => t.includes(k))) return false;
  return CREDIT_KEYWORDS.some((k) => t.includes(k));
}

export type Bank = { name: string; code: string };

export type BankValidationResult = { accountNumber: string; accountName: string; bankCode: string };

export type DirectPaymentDetails = {
  paymentReference: string;
  transactionReference: string;
  checkoutUrl: string;
  amount: number;
  accountNumber: string;
  bankName: string;
  bankCode: string;
  accountName: string;
  expiresOn: string;
  accountDurationSeconds: number;
};

export type AppNotification = {
  id: string;
  title: string;
  message: string;
  is_read: boolean;
  created_at: string;
};

export type ChatMessage = {
  id: string;
  group_id: string;
  sender_id: string;
  message: string;
  is_system: boolean;
  is_edited: boolean;
  is_deleted: boolean;
  created_at: string;
};
