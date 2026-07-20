const TOKEN_KEY = "payajo_access_token";
const TOKEN_TYPE_KEY = "payajo_token_type";
const LAST_EMAIL_KEY = "payajo_last_email";

// localStorage is the web equivalent of the mobile app's secure storage —
// it's not encrypted at rest like flutter_secure_storage, which is an
// accepted tradeoff for a web session (same as most web apps).
export function saveToken(accessToken: string, tokenType?: string) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(TOKEN_KEY, accessToken);
  if (tokenType) window.localStorage.setItem(TOKEN_TYPE_KEY, tokenType);
}

export function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem(TOKEN_KEY);
}

// Deliberately not cleared here — so a re-login (manual or after an
// expired-session bounce) still only asks for the password.
export function clearToken() {
  if (typeof window === "undefined") return;
  window.localStorage.removeItem(TOKEN_KEY);
  window.localStorage.removeItem(TOKEN_TYPE_KEY);
}

export function saveLastEmail(email: string) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(LAST_EMAIL_KEY, email);
}

export function getLastEmail(): string | null {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem(LAST_EMAIL_KEY);
}

export function authHeaders(): HeadersInit {
  const token = getToken();
  const tokenType = (typeof window !== "undefined" && window.localStorage.getItem(TOKEN_TYPE_KEY)) || "Bearer";
  return token ? { Authorization: `${tokenType} ${token}` } : {};
}

/** Pulls `access_token`/`token_type` out of a login/signup response's `data` and persists it. */
export function saveTokenFromResponse(data: unknown) {
  if (!data || typeof data !== "object") {
    throw new Error("Unexpected response from server.");
  }
  const record = data as Record<string, unknown>;
  const accessToken = record.access_token;
  if (typeof accessToken !== "string" || !accessToken) {
    throw new Error("Unexpected response from server.");
  }
  const tokenType = typeof record.token_type === "string" ? record.token_type : undefined;
  saveToken(accessToken, tokenType);
}
