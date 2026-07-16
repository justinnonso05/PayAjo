# Testing Monnify Endpoints in Postman — Pre-Implementation Guide

Goal: exercise every Monnify endpoint AjoPay depends on, by hand, in Postman —
before any of it is wired into FastAPI. If it doesn't work cleanly here, it
won't work cleanly in code either.

> Endpoint paths below are confirmed against Monnify's current developer docs
> as of this guide's writing. Monnify has migrated some routes between v1/v2
> before — if any call 404s, check `https://developers.monnify.com/api`
> for the current path before assuming your setup is wrong.

---

## 1. Prerequisites

- A Monnify account with **Sandbox/Test** credentials from **Developers → API Keys & Contracts**: `API Key`, `Secret Key`, `Contract Code`.
- Postman installed (desktop or web).
- A way to receive webhooks for testing: [webhook.site](https://webhook.site) is the fastest — it gives you a public URL instantly with no setup, and shows every incoming payload in real time.
- Access to the email inbox tied to your Monnify account (OTPs for disbursement land there).
- The Monnify Bank Simulator, used in your browser (not Postman) to simulate a customer paying into a reserved account — this is separate from the API calls below, but you'll use it in step 6.

---

## 2. Postman Environment Setup

Create a Postman **Environment** called `Monnify Sandbox` with these variables (leave `current value` blank for secrets, fill only in your local/private environment — never commit a Postman environment with real keys to git):

| Variable | Initial value | Notes |
|---|---|---|
| `base_url` | `https://sandbox.monnify.com` | Sandbox base — changes when you go live |
| `api_key` | *(your sandbox API key)* | |
| `secret_key` | *(your sandbox secret key)* | |
| `contract_code` | *(your sandbox contract code)* | |
| `access_token` | *(auto-filled — see §3)* | |
| `account_reference` | *(auto-filled — see §5)* | |
| `transfer_reference` | *(auto-filled — see §7)* | |
| `webhook_url` | *(your webhook.site URL)* | Paste into your Monnify dashboard webhook settings |

Create a **Collection** called `AjoPay — Monnify Sandbox`, with folders:

```
AjoPay — Monnify Sandbox/
├── 0. Auth
├── 1. Supporting Data (Banks, Name Enquiry)
├── 2. Reserved Accounts (Collections)
├── 3. Dynamic Virtual Accounts (Direct-to-Group)
├── 4. Disbursements (Payouts)
├── 5. Sub-Accounts (Splits) — stretch
└── 6. Internal Mocks (BVN)
```

---

## 3. Folder 0: Authentication

Every Monnify call needs a Bearer token. Get one first, and set up a script so you don't manually copy-paste it 30 times.

### Request: Login
- **Method:** `POST`
- **URL:** `{{base_url}}/api/v1/auth/login`
- **Auth:** none in the header field — instead go to the **Authorization** tab, type `Basic Auth`, username = `{{api_key}}`, password = `{{secret_key}}`. Postman base64-encodes it for you.
- **Body:** none required.

**Expected response:**
```json
{
  "requestSuccessful": true,
  "responseMessage": "success",
  "responseCode": "0",
  "responseBody": {
    "accessToken": "eyJhbGciOiJIUzI1NiJ9...",
    "expiresIn": 3600
  }
}
```

**Postman Tests script** (Tests tab) — auto-saves the token so every other request can just reference `{{access_token}}`:
```javascript
const json = pm.response.json();
pm.environment.set("access_token", json.responseBody.accessToken);
pm.test("Login succeeded", () => {
    pm.expect(json.requestSuccessful).to.be.true;
});
```

For every other request in this guide, set header:
```
Authorization: Bearer {{access_token}}
```

> Token expires after 1 hour (3600s). If later calls start failing with a 401, re-run this request first — it's almost always an expired token, not a broken integration.

**✅ Maps to:** every authenticated call AjoPay's backend makes to Monnify.

---

## 4. Folder 1: Supporting Data

### 4.1 Get Banks
- **Method:** `GET`
- **URL:** `{{base_url}}/api/v1/banks`
- **Header:** `Authorization: Bearer {{access_token}}`

Returns the full list of bank names + codes. You'll need a real `bankCode` (e.g. `232` for Sterling, `058` for GTBank-style test codes — whichever appears in your sandbox list) for every request below that needs one. Save 2–3 codes somewhere handy for the rest of this session.

**✅ Maps to:** populating a bank-selection dropdown when a member adds their payout account.

### 4.2 Name Enquiry (Validate Bank Account)
This is the **real, sandbox-available** verification endpoint — not the mocked one. Use it to confirm a member's payout account before saving it.

- **Method:** `GET`
- **URL:** `{{base_url}}/api/v1/disbursements/account/validate?accountNumber=0068687503&bankCode=232`
- **Header:** `Authorization: Bearer {{access_token}}`

**Expected response:**
```json
{
  "requestSuccessful": true,
  "responseMessage": "success",
  "responseCode": "0",
  "responseBody": {
    "accountNumber": "0068687503",
    "accountName": "DAMILARE SAMUEL OGUNNAIKE",
    "bankCode": "232"
  }
}
```

Try it with an invalid account number too, and confirm you get a clean error response rather than a crash — you'll need to handle that path in the onboarding flow.

**✅ Maps to:** §7.2 of the PRD — bank account validation at onboarding, free on both sandbox and live.

---

## 5. Folder 2: Reserved Accounts (Collections)

### 5.1 Create Reserved Account
- **Method:** `POST`
- **URL:** `{{base_url}}/api/v2/bank-transfer/reserved-accounts`
- **Header:** `Authorization: Bearer {{access_token}}`, `Content-Type: application/json`
- **Body (raw JSON):**
```json
{
  "accountReference": "ajopay-member-001",
  "accountName": "AjoPay - Chidi Okafor",
  "currencyCode": "NGN",
  "contractCode": "{{contract_code}}",
  "customerEmail": "chidi@example.com",
  "customerName": "Chidi Okafor",
  "getAllAvailableBanks": false,
  "preferredBanks": ["232"],
  "bvn": "22222222222"
}
```

> `bvn` (or `nin`) is a **mandatory** field on this endpoint for real KYC compliance, even in sandbox. Since real BVN verification isn't available in sandbox anyway, use any well-formed 11-digit placeholder value here — Monnify's sandbox does not appear to validate it against a real registry, so this is safe to stub for testing. Flag this clearly as a stubbed value in your own test notes.
>
> `preferredBanks` is **required whenever `getAllAvailableBanks` is `false`** — it's the bank code(s) (from §4.1 Get Banks) you want the reserved account issued against. Omitting it with `getAllAvailableBanks: false` returns a `99` error ("Kindly specify preferred bank codes or set getAllAvailableBanks to true"). Set `getAllAvailableBanks: true` instead if you'd rather let Monnify issue account numbers across all its partner banks and drop `preferredBanks` entirely — that's a UX choice (one predictable account vs. several bank options), not a bug either way.

**Expected response:** account number(s) + bank name(s) assigned to `accountReference`.

**Tests script** — save the reference for reuse:
```javascript
pm.environment.set("account_reference", pm.response.json().responseBody.accountReference);
```

**✅ Maps to:** §7.2 — one reserved account created per member per group at onboarding.

### 5.2 Get Reserved Account Details
- **Method:** `GET`
- **URL:** `{{base_url}}/api/v2/bank-transfer/reserved-accounts/{{account_reference}}`
- **Header:** `Authorization: Bearer {{access_token}}`

Confirms the account number/bank name you'll display to the member as "pay into this account."

**✅ Maps to:** displaying the reserved account in the mobile/web onboarding screen.

### 5.3 (Optional) Get Reserved Account Transactions
- **Method:** `GET`
- **URL:** `{{base_url}}/api/v2/bank-transfer/reserved-accounts/transactions?accountReference={{account_reference}}&page=0&size=10`

Use this as your **fallback reconciliation path** if a webhook is ever missed — confirm it returns a transaction list you can diff against your own contribution ledger.

**✅ Maps to:** §9.2 — reconciliation fallback beyond webhooks.

---

## 6. Simulating a Payment (Browser, not Postman)

Postman can't simulate an actual bank transfer — Monnify's **Bank Simulator** is a hosted web page that stands in for the customer's banking app in sandbox.

1. In your Monnify sandbox dashboard, locate the Bank Simulator (linked from the reserved accounts / testing docs).
2. Enter the reserved account number from §5.1 and the **exact** amount you want to test with (entering a different amount produces an over/underpayment status — useful to test deliberately once, but keep it exact for your main pass).
3. Submit — Monnify's sandbox marks the transaction `PAID` and fires your configured webhook.

**Check your webhook.site URL** — you should see a payload arrive within a few seconds. Confirm:
- The `monnify-signature` header is present (you'll validate this server-side later).
- The payload contains the `accountReference`/`accountNumber`, `amountPaid`, and a `paymentReference`.

Then re-run **§5.3 Get Reserved Account Transactions** and confirm the same transaction shows up there too — this proves your webhook and your polling fallback agree, which matters for §9.2's idempotency design.

**✅ Maps to:** §7.3 — contribution tracking, and §9.2 — webhook + fallback reconciliation.

---

## 7. Folder 3: Dynamic Virtual Accounts (Direct-to-Group Payments)

This is the **Path B** flow from the PRD: a one-time, transaction-scoped account for a member paying a specific group's cycle directly, bypassing the wallet entirely. Unlike Reserved Accounts, this does **not** hit the `R42` "one account per BVN" limit, because nothing is being reserved long-term — a fresh account is generated per transaction.

Two calls, in sequence.

### 7.1 Initialize Transaction
- **Method:** `POST`
- **URL:** `{{base_url}}/api/v1/merchant/transactions/init-transaction`
- **Header:** `Authorization: Bearer {{access_token}}`, `Content-Type: application/json`
- **Body:**
```json
{
  "amount": 10000.00,
  "customerName": "Chidi Okafor",
  "customerEmail": "chidi@example.com",
  "paymentReference": "ajopay-direct-group042-cycle3-user017-{{$timestamp}}",
  "paymentDescription": "AjoPay contribution — Group 042 cycle 3",
  "currencyCode": "NGN",
  "contractCode": "{{contract_code}}",
  "redirectUrl": "https://ajopay.app/contribute/confirm",
  "paymentMethods": ["ACCOUNT_TRANSFER"]
}
```
> `paymentMethods: ["ACCOUNT_TRANSFER"]` restricts the checkout to bank transfer only — no point offering card here since the whole point of this path is the transfer-native experience. `paymentReference` is where you encode `{user_id, group_id, cycle_number}` so the webhook can be attributed with zero ambiguity — this is the field the whole Path B design leans on.

**Expected response:**
```json
{
  "requestSuccessful": true,
  "responseMessage": "success",
  "responseCode": "0",
  "responseBody": {
    "transactionReference": "MNFY|20260716|000090",
    "paymentReference": "ajopay-direct-group042-cycle3-user017-...",
    "checkoutUrl": "https://sandbox.sdk.monnify.com/checkout/MNFY|20260716|000090",
    "enabledPaymentMethod": ["ACCOUNT_TRANSFER"]
  }
}
```

**Tests script** — save the reference for the next call:
```javascript
pm.environment.set("transaction_reference", pm.response.json().responseBody.transactionReference);
```

**✅ Maps to:** §7.3 Path B — creating the one-time payment intent before a member sees an account number.

### 7.2 Get Dynamic Virtual Account (Pay with Bank Transfer)
- **Method:** `POST`
- **URL:** `{{base_url}}/api/v1/merchant/bank-transfer/init-payment`
- **Header:** `Authorization: Bearer {{access_token}}`, `Content-Type: application/json`
- **Body:**
```json
{
  "transactionReference": "{{transaction_reference}}",
  "bankCode": "232"
}
```
> `bankCode` is optional — include it if you want a USSD string back for that bank too. You can call this endpoint more than once for the same `transactionReference`; each call tells you how many seconds of validity remain.

**Expected response:** a dynamic account number + bank name to display to the member, plus `accountDuration` in seconds.

> ⚠️ **This account expires in 2400 seconds (40 minutes), fixed** — not configurable. Whatever UI you build around this needs a visible countdown or an obvious "generate a new one" action once it lapses; don't let a member discover the expiry only after a failed transfer.

Simulate the payment against this account exactly like §6 (Bank Simulator, exact amount), then confirm your webhook fires with the `paymentReference` you set in 7.1 intact — that reference is what your webhook handler decodes into `{user_id, group_id, cycle_number}` to write the `GroupLedgerEntry` directly, with no wallet involved.

**✅ Maps to:** §7.3 Path B — the account the member actually pays into, and the reconciliation that follows.

---

## 8. Folder 4: Disbursements (Payouts)

### 7.1 Initiate Single Transfer
- **Method:** `POST`
- **URL:** `{{base_url}}/api/v2/disbursements/single`
- **Header:** `Authorization: Bearer {{access_token}}`, `Content-Type: application/json`
- **Body:**
```json
{
  "amount": 500.00,
  "reference": "ajopay-payout-cycle1-{{$timestamp}}",
  "narration": "AjoPay payout — Test Group — cycle 1",
  "destinationBankCode": "058",
  "destinationAccountNumber": "0123456789",
  "destinationAccountName": "John Doe",
  "currency": "NGN",
  "sourceAccountNumber": "9999999999"
}
```
> `destinationAccountName` must exactly match what Name Enquiry (§4.2) returned for that account — a mismatch fails the transfer. Always chain a Name Enquiry call before this one, even in testing, to build the habit.

**Expected response** — since MFA/OTP is on by default in sandbox, expect:
```json
{
  "responseBody": {
    "amount": 500,
    "reference": "ajopay-payout-cycle1-...",
    "status": "PENDING_AUTHORIZATION",
    "destinationAccountName": "John Doe",
    "destinationBankName": "GTBank",
    "destinationAccountNumber": "0123456789",
    "destinationBankCode": "058"
  }
}
```

**Tests script:**
```javascript
pm.environment.set("transfer_reference", pm.response.json().responseBody.reference);
```

To deliberately test a **failure path**, use Monnify's documented sandbox failure test account:
`destinationAccountNumber: 0035785417`, `destinationBankCode: 044` — confirm you get a clean `FAILED` status back, and that your future error-handling code has something real to branch on.

**✅ Maps to:** §8.2 — the payout engine's disbursement call.

### 7.2 Authorize Transfer (submit OTP)
Check the email inbox tied to your Monnify account for the OTP, then:

- **Method:** `POST`
- **URL:** `{{base_url}}/api/v2/disbursements/single/validate-otp`
- **Header:** `Authorization: Bearer {{access_token}}`, `Content-Type: application/json`
- **Body:**
```json
{
  "reference": "{{transfer_reference}}",
  "authorizationCode": "123456"
}
```

**Expected response:** `"status": "SUCCESS"`.

**✅ Maps to:** §8.2/§9.3 — the "Approve Payout" admin action, and the honest OTP-checkpoint UX the PRD calls for.

### 7.3 Resend OTP
Test this deliberately by letting an OTP go stale, or just to confirm the flow works:
- **Method:** `POST`
- **URL:** `{{base_url}}/api/v2/disbursements/single/resend-otp`
- **Body:** `{ "reference": "{{transfer_reference}}" }`

**✅ Maps to:** §9.3 — "Resend OTP" button in the admin dashboard.

### 7.4 Get Transfer Status (Requery)
- **Method:** `GET`
- **URL:** `{{base_url}}/api/v2/disbursements/transfer-status/{{transfer_reference}}`

> Monnify's docs note this endpoint is protected with **Basic Auth** rather than Bearer — if you get a 401 using your Bearer token here, switch the Authorization tab to Basic Auth with `api_key`/`secret_key` and retry. Worth confirming this quirk yourself before writing the client code, since it's an easy thing to miss.

**✅ Maps to:** §9.2 — polling fallback for payout status if the disbursement webhook is missed.

### 7.5 (Optional) Get All Single Transfers
- **Method:** `GET`
- **URL:** `{{base_url}}/api/v2/disbursements/single/transactions?pageSize=5&pageNo=1`

Useful for building the admin dashboard's payout history view (§7.8 of the PRD) without needing to store every field yourself.

---

## 9. Folder 5: Sub-Accounts / Split Payments (Stretch)

Only test this once the core flow above is solid.

### 8.1 Create Sub-Account
- **Method:** `POST`
- **URL:** `{{base_url}}/api/v1/sub-accounts`
- **Body:**
```json
{
  "currencyCode": "NGN",
  "bankCode": "232",
  "accountNumber": "0068687503",
  "email": "platform-fees@ajopay.app",
  "defaultSplitPercentage": 2
}
```

### 8.2 Attach split to a Reserved Account
Re-run §5.1's Create Reserved Account, adding:
```json
"incomeSplitConfig": [
  {
    "subAccountCode": "<code from 8.1 response>",
    "feePercentage": 2,
    "splitAmount": null,
    "feeBearer": false
  }
]
```
Then simulate a payment again (§6) and confirm the platform fee sub-account actually receives its cut.

**✅ Maps to:** §7.6/§16 — optional platform fee, "Should have" tier.

---

## 10. Folder 6: Internal Mocks (BVN) — not a Monnify call

Real BVN/NIN verification is **Live-only** on Monnify (confirmed: sandbox requests to BVN Information Verification, BVN+Account Name Match, and NIN Verification all fail outside production). There's nothing to test against Monnify here.

Instead, add a placeholder request in this folder that hits **your own future FastAPI mock endpoint** once it exists (`POST http://localhost:8000/internal/mock/bvn/verify`), shaped exactly like Monnify's real BVN + Account Name Match request/response, so the same Postman collection documents both the real integration and the mocked one side by side — useful when you eventually swap the mock for the live call.

---

## 11. Pre-flight Checklist Before Writing Any FastAPI Code

Run through this list — everything should be a ✅ before you start on `app/monnify_client.py`:

- [ ] Login returns a token, and the Tests script auto-populates `access_token`
- [ ] Get Banks returns a usable list with real codes
- [ ] Name Enquiry returns a correct name for a known test account, and a clean error for an invalid one
- [ ] Reserved Account creation succeeds with a placeholder BVN
- [ ] Reserved Account details fetch returns the right account number/bank
- [ ] A simulated payment triggers a webhook.site payload **and** shows up via the transactions/polling endpoint
- [ ] Initialize Transaction + Get Dynamic Virtual Account returns a payable account, and a simulated payment against it fires a webhook carrying your `paymentReference` intact
- [ ] Single Transfer returns `PENDING_AUTHORIZATION`, and you've received the OTP by email
- [ ] Authorize Transfer with that OTP returns `SUCCESS`
- [ ] Resend OTP works
- [ ] Get Transfer Status (Basic Auth) returns the right final status
- [ ] The documented sandbox failure account (`0035785417` / `044`) returns a clean `FAILED`, not a crash
- [ ] (If attempting stretch) Sub-account split correctly divides a simulated payment

If any of these behave differently than documented here, that's real information — better to hit it now in Postman than mid-hackathon in code.