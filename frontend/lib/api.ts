import { clearToken } from "./auth";

const API_PREFIX = "/api/v1";

function baseUrl() {
  return process.env.NEXT_PUBLIC_API_BASE_URL ?? "https://ajopay.fastapicloud.dev";
}

function url(path: string) {
  const clean = path.startsWith("/") ? path : `/${path}`;
  return `${baseUrl()}${clean}`;
}

/** Same base URL, but with the scheme swapped for its WebSocket equivalent. */
export function wsUrl(path: string) {
  const httpUrl = new URL(url(path));
  httpUrl.protocol = httpUrl.protocol === "https:" ? "wss:" : "ws:";
  return httpUrl.toString();
}

export class ApiError extends Error {
  statusCode?: number;

  constructor(message: string, statusCode?: number) {
    super(message);
    this.name = "ApiError";
    this.statusCode = statusCode;
  }
}

// Mirrors the mobile app's response envelope: { success, message, data }.
type Envelope = { success?: boolean; message?: string; data?: unknown; detail?: unknown };

function extractErrorMessage(json: Envelope): string | null {
  const { detail } = json;
  if (typeof detail === "string" && detail) return detail;
  if (Array.isArray(detail) && detail.length > 0) {
    const first = detail[0];
    if (first && typeof first === "object" && "msg" in first && typeof first.msg === "string") {
      return first.msg;
    }
  }
  if (typeof json.message === "string" && json.message) return json.message;
  return null;
}

// Guarded so a burst of concurrent requests failing together right after
// expiry (several components refreshing at once) only redirects once
// instead of stacking navigations.
let isHandlingUnauthorized = false;

function handleUnauthorized() {
  if (isHandlingUnauthorized || typeof window === "undefined") return;
  isHandlingUnauthorized = true;
  clearToken();
  window.sessionStorage.setItem("ajopay_session_expired", "1");
  window.location.href = "/login";
}

/** Called on successful login so a later expiry can trigger the redirect again. */
export function resetUnauthorizedGuard() {
  isHandlingUnauthorized = false;
}

async function decode(response: Response): Promise<Envelope> {
  let json: Envelope = {};
  const text = await response.text();
  if (text) {
    try {
      json = JSON.parse(text);
    } catch {
      // non-JSON body; fall through with an empty object
    }
  }

  if (response.ok) return json;

  if (response.status === 401) handleUnauthorized();

  throw new ApiError(extractErrorMessage(json) ?? `Something went wrong (${response.status}).`, response.status);
}

async function request(path: string, init: RequestInit): Promise<Envelope> {
  let response: Response;
  try {
    response = await fetch(url(path), {
      ...init,
      headers: { "Content-Type": "application/json", ...init.headers },
    });
  } catch {
    throw new ApiError("Unable to reach the server. Check your connection and try again.");
  }
  return decode(response);
}

/** For the rare endpoint that returns a bare JSON array instead of the usual envelope (e.g. chat history). */
async function requestList(path: string, headers?: HeadersInit): Promise<unknown[]> {
  let response: Response;
  try {
    response = await fetch(url(path), { headers: { "Content-Type": "application/json", ...headers } });
  } catch {
    throw new ApiError("Unable to reach the server. Check your connection and try again.");
  }
  if (response.ok) {
    const text = await response.text();
    if (!text) return [];
    try {
      const parsed = JSON.parse(text);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return decode(response) as never;
}

/** For file uploads (multipart/form-data) — the browser sets its own Content-Type with boundary, so it must not be overridden. */
async function requestMultipart(path: string, file: File, headers?: HeadersInit): Promise<Envelope> {
  const form = new FormData();
  form.append("file", file);
  let response: Response;
  try {
    response = await fetch(url(path), { method: "POST", body: form, headers });
  } catch {
    throw new ApiError("Unable to reach the server. Check your connection and try again.");
  }
  return decode(response);
}

export const api = {
  get: (path: string, headers?: HeadersInit) => request(path, { method: "GET", headers }),
  post: (path: string, body?: unknown, headers?: HeadersInit) =>
    request(path, { method: "POST", body: JSON.stringify(body ?? {}), headers }),
  patch: (path: string, body?: unknown, headers?: HeadersInit) =>
    request(path, { method: "PATCH", body: JSON.stringify(body ?? {}), headers }),
  postFile: (path: string, file: File, headers?: HeadersInit) => requestMultipart(path, file, headers),
  getList: (path: string, headers?: HeadersInit) => requestList(path, headers),
};

export const endpoints = {
  // Auth
  register: `${API_PREFIX}/auth/signup`,
  login: `${API_PREFIX}/auth/login`,
  setupPin: `${API_PREFIX}/auth/setup-pin`,
  requestPinReset: `${API_PREFIX}/auth/request-pin-reset`,
  resetPin: `${API_PREFIX}/auth/reset-pin`,

  // User
  me: `${API_PREFIX}/users/me`,
  avatar: `${API_PREFIX}/users/me/avatar`,
  myGroups: `${API_PREFIX}/users/me/groups`,
  mockKycVerify: `${API_PREFIX}/users/me/kyc/mock-verify`,
  searchUser: (q: string) => `${API_PREFIX}/users/search?q=${encodeURIComponent(q)}`,

  // Groups
  groups: `${API_PREFIX}/groups/`,
  joinGroup: `${API_PREFIX}/groups/join`,
  group: (groupId: string) => `${API_PREFIX}/groups/${groupId}`,
  groupMembers: (groupId: string) => `${API_PREFIX}/groups/${groupId}/members`,
  groupRotations: (groupId: string) => `${API_PREFIX}/groups/${groupId}/rotations`,
  autoDebit: (groupId: string) => `${API_PREFIX}/groups/${groupId}/auto-debit`,
  payFromWallet: (groupId: string) => `${API_PREFIX}/groups/${groupId}/pay-from-wallet`,
  generateDirectPayment: (groupId: string) => `${API_PREFIX}/groups/${groupId}/generate-direct-payment`,
  pendingMembers: (groupId: string) => `${API_PREFIX}/groups/${groupId}/members/pending`,
  approveMember: (groupId: string, userId: string) => `${API_PREFIX}/groups/${groupId}/members/${userId}/approve`,
  startGroup: (groupId: string) => `${API_PREFIX}/groups/${groupId}/start`,
  rotateInviteCode: (groupId: string) => `${API_PREFIX}/groups/${groupId}/rotate-code`,
  sendMemberReminder: (groupId: string, userId: string) => `${API_PREFIX}/groups/${groupId}/members/${userId}/send-reminder`,
  sendRemindersBulk: (groupId: string) => `${API_PREFIX}/groups/${groupId}/send-reminders-bulk`,
  // Manually runs the payout scheduler across ALL groups (not scoped to one) — testing/demo only.
  triggerScheduler: `${API_PREFIX}/cycles/admin/trigger-scheduler`,
  sendInvite: (groupId: string) => `${API_PREFIX}/groups/${groupId}/invites`,
  myInvites: `${API_PREFIX}/groups/me/invites`,
  respondInvite: (inviteId: string, accept: boolean) => `${API_PREFIX}/groups/invites/${inviteId}/respond?accept=${accept}`,
  chatHistory: (groupId: string, limit = 50, offset = 0) => `${API_PREFIX}/groups/${groupId}/chat?limit=${limit}&offset=${offset}`,
  chatWebSocket: (groupId: string, token: string) => `${API_PREFIX}/groups/${groupId}/ws?token=${token}`,

  // Wallet
  walletTransactions: `${API_PREFIX}/users/me/wallet/transactions`,
  walletTransactionReceipt: (transactionId: string) => `${API_PREFIX}/users/me/wallet/transactions/${transactionId}`,
  walletWithdraw: `${API_PREFIX}/users/me/wallet/withdraw`,
  walletLookup: (accountNumber: string) => `${API_PREFIX}/users/me/wallet/lookup?account_number=${accountNumber}`,
  walletTransfer: `${API_PREFIX}/users/me/wallet/transfer`,
  transactionStatus: (ref: string) => `${API_PREFIX}/users/me/transactions/status/${ref}`,
  banks: `${API_PREFIX}/users/banks`,
  validateBankAccount: (accountNumber: string, bankCode: string) =>
    `${API_PREFIX}/users/banks/validate?account_number=${accountNumber}&bank_code=${bankCode}`,
  requestPayoutBankOtp: `${API_PREFIX}/users/me/payout-bank/request-otp`,
  setPayoutBank: `${API_PREFIX}/users/me/payout-bank`,

  // Notifications
  notifications: `${API_PREFIX}/notifications`,
  markNotificationsRead: `${API_PREFIX}/notifications/mark-read`,
};
