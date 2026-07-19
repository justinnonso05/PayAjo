const TOKEN_KEY = "ajopay_access_token";
const TOKEN_TYPE_KEY = "ajopay_token_type";

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

export function clearToken() {
  if (typeof window === "undefined") return;
  window.localStorage.removeItem(TOKEN_KEY);
  window.localStorage.removeItem(TOKEN_TYPE_KEY);
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
