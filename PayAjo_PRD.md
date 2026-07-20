# AjoPay — Product Requirements Document (v2)

**Hackathon:** API Conference Lagos 2026 Developer Challenge — Monnify
**Submission deadline:** 12:00 PM WAT, July 21, 2026
**Version:** 3.0 (Hackathon MVP — Wallet Architecture + Group Membership)
**Status:** Draft for build

**What changed in v2:** every user now has a personal wallet + dedicated virtual account; every group has its own dedicated virtual account (not one reserved account per member per group, as in v1); all outbound money movement now requires a transaction PIN; rotation cadence (weekly/monthly/yearly) is admin-configurable with day/month selection; and members can delegate or swap their payout turn. See §8, §9, §11, and §16 for that material.

**What changed in v3:** a user can belong to — and switch between — multiple groups, and be admin of one while just a member of others. Groups are joined either via a shareable invite code (self-service) or a targeted invite the admin sends to an existing user found by exact email/username match (accept/reject, like the swap flow). See §24 for the full mechanics, updated data model, and lifecycle examples.

**What changed in v4:** Monnify caps reserved accounts at **one per customer identity** (keyed off the BVN/NIN supplied) by default — confirmed by hitting `R42` when attempting a second reserved account against the same BVN. Since a group isn't a real person and can't have its own distinct KYC identity, **groups no longer get their own Monnify reserved account**. All contributions now flow through the member's personal wallet (fund wallet → internal ledger transfer to group pool), which was already Monnify-call-free per §8.2. Direct-to-group bank transfers are now a clearly-labeled stretch item, gated on Monnify raising the per-customer limit. See §8 and §13.1 for the updated architecture.

**What changed in v5:** the v4 note above turned out to be more pessimistic than necessary. Direct-to-group payment does **not** require Monnify to raise the per-customer reserved-account limit, or a KYC identity for the group — it just needs a different Monnify primitive. A **Dynamic Virtual Account** (Initialize Transaction + Pay with Bank Transfer) is transaction-scoped, not BVN-bound, so it never hits `R42` at all. Direct-to-group is therefore back in scope as **Path B**, alongside the existing wallet flow as **Path A** — both write to the same `GroupLedgerEntry` ledger, and Path B is fully self-attributing by design (no "unmatched contribution" UI needed). See §8.5 (new) and updates to §6, §7.3, §13.1, §13.2, and §15.

---

## 1. Problem Statement

Rotating savings groups (Ajo/Esusu) are one of the most widely used informal financial products in Nigeria — used by traders, artisans, colleagues, and religious/community groups to save and access lump sums without banks. They fail in three predictable ways:

1. **Trust failure** — a treasurer disappears with the pooled funds.
2. **Reconciliation failure** — "I sent it" disputes because contributions aren't traceable to a person.
3. **Coordination failure** — no visibility into who's late, who's next, or whether the group has enough to pay out this cycle.

AjoPay digitizes the mechanics of Ajo — dedicated accounts, automatic reconciliation, automatic payout on rotation, and a shared space to coordinate — without asking members to change *how* the ajo works. It looks and feels like the ajo they already run; it just can't be run away with.

## 2. Vision & Positioning

AjoPay is a **rotation engine with real money behind it**: every user has a wallet funded through their own dedicated virtual account, every group has its own dedicated virtual account as the collection point, every contribution is reconciled automatically, and every payout — including who actually receives it, if a member delegates or swaps — is handled deliberately, with a PIN-gated confirmation step standing in for the trust a human treasurer used to provide.

## 3. Goals (Hackathon Scope)

- Ship a working, demoable product on Monnify **sandbox**, no live keys.
- Cover mobile (primary) and web (secondary) with one shared backend.
- Use real Monnify endpoints for account reservation, collection webhooks, name validation, and disbursement.
- Implement the wallet + PIN architecture described in §8, including both funding paths (wallet top-up vs direct-to-group).
- Support weekly/monthly/yearly rotation cadence with the correct day/month picker per frequency (§9).
- Support delegate and swap actions on a payout turn (§11), each with a worked lifecycle (§16).
- Support a user belonging to multiple groups, switching between them, and being admin of one while a plain member of others (§24).
- Make the automatic payout logic and risk score genuinely explainable in a 3-minute demo.

## 4. Non-Goals (explicitly out of scope for hackathon)

- Real BVN/NIN verification (Monnify only exposes this on **live**, not sandbox). We mock it, visibly labeled as mocked.
- Direct Debit / mandate-based auto-contribution — noted as a post-hackathon roadmap item.
- A real pooled-funds banking license or regulatory structure. The wallet model in §8 assumes all reserved accounts settle into AjoPay's own Monnify sub-account structure, and that moving money between a user's wallet and a group's wallet is an internal ledger entry rather than a new bank-to-bank transfer. This is a reasonable hackathon simplification but is explicitly flagged in §19 as something that would need real regulatory and settlement-partner sign-off before handling real money at scale.
- Multi-currency, cross-border groups.
- Native iOS/Android written twice — one cross-platform mobile codebase.

## 5. Users & Personas

| Persona | Description | Primary need |
|---|---|---|
| **Member** | Contributes each cycle, waits their turn to be paid, may delegate or swap their turn | "Did my contribution register? Can I send my payout to someone else this time?" |
| **Group Admin (Alaga)** | Creates the group, sets rotation cadence, resolves disputes, approves delegations/swaps | "Who hasn't paid? Is this delegation/swap request legitimate?" |
| **Prospective member** | Invited but not yet onboarded | "Is this legit? How do I join?" |

## 6. Core Concepts & Glossary

| Term | Meaning |
|---|---|
| **User Wallet** | A user's personal ledger balance inside AjoPay, funded via their own dedicated virtual account |
| **User Virtual Account** | A Monnify Reserved Account, one per user (platform-wide, not per group), used to top up their wallet |
| **Group Virtual Account** *(superseded — see §8.1, §8.5)* | Earlier versions gave each group its own Monnify Reserved Account for this purpose; that hit Monnify's `R42` BVN-uniqueness limit and was dropped. A group has no persistent Monnify account of its own — direct-to-group payment instead uses a **Dynamic Virtual Account**, below |
| **Dynamic Virtual Account** | A **one-time**, transaction-scoped Monnify virtual account (via Initialize Transaction + Pay with Bank Transfer), generated fresh per direct-to-group payment. Not tied to a BVN and not persistent, so it never hits `R42` — this is what makes Path B (§8.5) possible without Monnify raising any limit |
| **Group Pool** | The ledger balance representing funds collected for the current cycle in a group |
| **Transaction PIN** | A 4–6 digit PIN, set at onboarding, required to authorize any outbound money movement inside the app |
| **Cycle** | One round of contribution + payout |
| **Rotation Order** | The sequence in which members are assigned to receive the pooled payout, one per cycle |
| **Cycle Assignment** | The record of who is *assigned* to a given cycle, and who *actually receives* the payout (may differ if delegated) |
| **Delegation** | The assigned member redirects this cycle's payout to a different member, without changing future rotation order |
| **Swap** | Two members mutually exchange their assigned cycle positions, changing future rotation order |
| **Quorum** | The % of members who must have contributed by the payout date for the cycle to pay out |
| **Risk Score** | A 0–100 score per member reflecting contribution reliability |
| **Group Invite Code** | A short, shareable, regenerable code that lets anyone with it self-join a group |
| **Direct Invite** | A targeted invite sent by an admin to a specific existing user (found by exact email/username match), which the recipient must accept or reject |

---

## 7. Feature Set

### 7.1 Onboarding
- Sign up: name, phone, email, password.
- Set a **4–6 digit Transaction PIN** (separate from login password), stored hashed (bcrypt/argon2), never logged or transmitted in plaintext beyond the initial set request.
- Add payout bank account, validated via Monnify **Name Enquiry** (real, sandbox-available).
- Complete **mocked BVN verification** (see §13.4) — clearly labeled as simulated in the UI.
- On successful onboarding, backend creates the user's **personal Reserved Account** (their wallet's funding channel) — this happens once per user, platform-wide, not per group.

### 7.2 Group Management
- Create group: name, contribution amount, **rotation cadence** (weekly/monthly/yearly — see §9 for the day/month picker logic), quorum threshold, member cap, delegation/swap approval settings (§11.3).
- On group creation, the group gets **no** Monnify Reserved Account of its own (see §8.1) — its collection point is either a member's wallet allocation (Path A) or a one-time Dynamic Virtual Account minted per direct payment (Path B, §8.5).
- Two ways to bring members in — a shareable **invite code** (self-service, enterable at onboarding or later) and a **direct, targeted invite** sent to an existing user found by exact email/username match. Full mechanics in §24.
- Rotation order: admin sets manually or generates a randomized "fair draw."
- A user can belong to multiple groups simultaneously and switch between them; admin status is per-group, not a platform-wide role (§24.4).

### 7.3 Funding & Contribution
See §8 for full mechanics — two independent paths, both landing in the same `GroupLedgerEntry` ledger:

- **Path A (wallet, the flexible default):** a member tops up their personal wallet by transferring to their own Reserved Account, then explicitly pays into the group from their wallet (PIN required). This internal wallet→group movement is instant and Monnify-call-free, since both balances already live inside AjoPay's own ledger.
- **Path B (direct-to-group, one-off convenience):** a member who wants to pay a specific cycle right now, without pre-funding their wallet, generates a one-time **Dynamic Virtual Account** scoped to that exact payment (§8.5) and pays it directly from any bank app — the wallet is never touched.

> **Updated from earlier drafts:** direct-to-group payment was previously marked stretch/blocked, on the assumption it would need the group to have its own persistent Reserved Account, which does hit Monnify's `R42` BVN limit (§8.1). Dynamic Virtual Accounts sidestep this entirely, since they're transaction-scoped rather than BVN-bound. Path B is therefore back in scope without Monnify needing to raise any limit — see §8.5 for the full mechanism.

### 7.4 Automatic Payout Engine
On the scheduled payout day (per §9's cadence config), if quorum is met, AjoPay resolves the assigned member for this cycle (accounting for any approved delegation/swap — §10), and disburses the pooled amount via Monnify Disbursement to the correct recipient's registered bank account.

### 7.5 Delegate & Swap
- **Delegate:** the member assigned to receive this cycle's payout can redirect it to a different member, PIN-confirmed, subject to the group's approval setting.
- **Swap:** two members can mutually agree to trade their assigned cycle positions going forward, both PIN-confirmed, subject to the group's approval setting.
- Full mechanics and lifecycles in §11 and §16.

### 7.6 Risk Score
Displayed as a Low/Medium/High badge per member, tappable to see the contributing factors (§12). Delegating or swapping is **not** treated as a negative signal by itself — only missed or late contributions affect the score.

### 7.7 Group Chat
- One chat thread per group, with auto-posted system messages for contributions, payouts, delegation/swap requests and outcomes, and cycle reminders.
- Real-time via WebSocket.

### 7.8 Notifications
- Email (primary) and in-app/push (mobile), covering the event matrix in §17.

### 7.9 Admin Dashboard
- Cycle status, rotation timeline, member risk badges, pending delegation/swap approvals, manual overrides.

---

## 8. Wallet & Virtual Account Architecture

### 8.1 Why one reserved account per user — and none for groups
Monnify caps reserved accounts at **one per customer identity**, where "customer" is keyed off the BVN/NIN you supply when creating the account — attempting a second reserved account against the same BVN returns `R42` ("You cannot reserve more than 1 account(s) for a customer"). This is a real constraint discovered while building against sandbox, not a hypothetical.

Since a group isn't a real person, it has no KYC identity of its own to reserve an account against — reusing the admin's BVN for the group's account would hit exactly the same `R42` error, and would hit it again for every additional group that admin creates. **So groups do not get their own Monnify reserved account.** Every real person (user) gets exactly one, platform-wide, used to fund their wallet — and every group is a pure ledger construct, funded only via internal wallet→group transfers (§8.2), which never touch Monnify anyway. This is both the constraint-compliant answer and, as it turns out, a simplification: it also eliminates the need to match ambiguous incoming bank transfers back to a specific member (there was no clean way to do this robustly once you consider it), since money can only reach a group by first passing through a wallet tied to one specific, verified person.

> **Update (v5):** true "pay the group directly" support does *not* require emailing Monnify to raise the per-customer limit, or a secondary KYC identity for the group, as this section originally concluded. A **Dynamic Virtual Account** — generated per transaction rather than reserved against a BVN — achieves the same direct-payment experience without ever touching `R42`. See §8.5.

### 8.2 Path A — Funding & contribution flow (wallet), in detail

1. User transfers money (from any bank) into their own personal Reserved Account.
2. Monnify webhook fires on that reserved account → AjoPay credits the user's **wallet ledger balance** by that amount. This money is now sitting inside AjoPay's pooled Monnify settlement balance, tagged in our own database as "belonging" to that user.
3. When the user wants to contribute to a group, they tap "Pay from wallet," enter their amount and their **Transaction PIN**.
4. AjoPay performs an **internal ledger transfer**: debit the user's wallet balance, credit the group's pool balance. **No Monnify API call is needed for this step** — the underlying money never has to move between banks, because it already lives inside AjoPay's own settlement balance; only the bookkeeping changes. This is what makes wallet-to-group payments instant and fee-free.
5. A `Contribution` record is created, attributed to that user, for that cycle.

This is the flexible **default** contribution path — every member funds their own wallet, then pays into whichever group(s) they belong to from that single wallet, on their own schedule. A member in three groups still only ever has one reserved account and one wallet balance to manage. It is not, however, the *only* path — see §8.5 for Path B, the direct-to-group alternative.

### 8.3 Why PIN gates only *some* actions
| Action | PIN required? | Why |
|---|---|---|
| Top up personal wallet (external → own reserved account) | No | Inbound only, nothing to authorize |
| Generate a Dynamic Virtual Account for a direct-to-group payment (Path B) | No | Same reasoning as wallet top-up — it's a request for an inbound payment destination, not an outbound movement of funds |
| Pay group **from wallet** (internal ledger transfer) | **Yes** | Money is leaving the user's control inside AjoPay |
| Delegate payout to another member | **Yes** | Redirects real money to a different recipient |
| Accept/confirm a swap | **Yes** (both parties) | Changes who receives money in future cycles |
| Withdraw wallet balance to own bank account | **Yes** | Outbound disbursement, plus Monnify OTP on top (§13.3) |
| Admin approving a payout, delegation, or swap | **Yes** | Defense-in-depth on top of Monnify's own OTP for the actual disbursement |

PIN attempts are rate-limited (e.g. 5 attempts, then a cooldown) to prevent brute-forcing; the PIN itself is never stored or logged in plaintext.

### 8.4 Reconciliation discipline
Because the wallet model introduces an internal ledger that must always match reality, every wallet/group balance mutation is written as an **append-only ledger entry** (`WalletLedgerEntry` — see §15), never as a direct balance overwrite. The displayed balance is always the sum of ledger entries, which makes it possible to audit and rebuild balances from scratch if a bug is ever suspected — an important discipline once money is modeled as an in-app wallet rather than pass-through transfers.

### 8.5 Path B — Direct-to-group via Dynamic Virtual Account (NEW, v5)

The full picture, combining both paths:

1. **Onboarding (once per user, ever):** the first time a user joins any group, they get exactly one persistent **Reserved Account** (§7.1). Joining more groups later never creates another one — `R42` would block it anyway, and there's no need to try.
2. **Path A — Wallet (§8.2, the flexible default):** money sent to that Reserved Account is picked up by webhook and credited to the user's wallet balance. It sits there, group-agnostic, until the user allocates some of it to a specific group's current cycle — an internal transfer, no Monnify call, written as a `GroupLedgerEntry` (`type: contribution_wallet`).
3. **Path B — Direct-to-group (this section):** if a member wants to pay a group right now without pre-funding their wallet:
   - AjoPay calls Monnify's **Initialize Transaction** (`POST /api/v1/merchant/transactions/init-transaction`), with `paymentReference` encoding `{user_id, group_id, cycle_number}` (e.g. `ajopay-direct-{group_id}-{cycle}-{user_id}-{timestamp}`) so the payment is self-describing from the moment it's created.
   - AjoPay then calls **Pay with Bank Transfer** (`POST /api/v1/merchant/bank-transfer/init-payment`) with that `transactionReference`, which returns a **one-time Dynamic Virtual Account** number/bank for the member to pay into. This account is valid for **2400 seconds (40 minutes), fixed** — the UI must show a visible countdown or a "generate a new one" action once it lapses.
   - The member pays that account directly from any bank app. Monnify's webhook for that transaction reference arrives; AjoPay decodes `paymentReference` and writes a `GroupLedgerEntry` (`type: contribution_direct`) straight onto that group/cycle, with the `monnify_transaction_reference` retained for audit.
   - **The member's wallet is untouched** — correctly, since this money never routed through it.
4. **Payout (unaffected by either path):** still a Monnify Single Transfer from the merchant's settlement account to the beneficiary's payout bank account, OTP-authorized (§13.3) — completely separate machinery from either contribution path.

Because each Dynamic Virtual Account is minted fresh per payment with the group/cycle/user already encoded in its reference, Path B has **no unmatched-contribution problem** the way a shared, persistent group account would have — there's nothing to manually attribute. The `UnmatchedContribution` entity in §15 predates this discovery and is no longer needed for Path B; it's kept in the data model only for historical reference.

---

## 9. Rotation Cadence Configuration

When the admin creates a group, they pick a cadence, and the UI then asks for the matching detail:

| Cadence | Admin picks | Example | Edge case handling |
|---|---|---|---|
| **Weekly** | Day of week (Mon–Sun) | "Every Friday" | None needed — every week has every weekday |
| **Monthly** | Day of month (1–31, or "Last day of month") | "The 5th of every month" | If a member picks day 31 and the current month only has 30 (or 28/29), the payout fires on the **last day of that month** instead — this is handled the same way as "Last day of month" would be, so no cycle is ever silently skipped |
| **Yearly** | Month of year (Jan–Dec) | "Every March" | Day-of-month within that month defaults to the group's creation day-of-month (e.g. a group created on the 14th pays out on March 14th each year), unless the admin overrides it explicitly |

This is stored on the group as `cycle_frequency` (`weekly` \| `monthly` \| `yearly`) plus the relevant one of `payout_day_of_week`, `payout_day_of_month`, or `payout_month` (+ optional `payout_day_override` for yearly). The daily scheduler tick (§10) checks the group's cadence type and evaluates the matching field to decide "is today a payout day for this group."

---

## 10. Automatic Payout Logic — updated for delegation/swap

### 10.1 Data backing the decision
Each group stores `rotation_order`, `current_rotation_index`, cadence fields (§9), `quorum_percent`, and `contribution_target_per_member`, same as before. Each cycle now also has a `CycleAssignment` record:

```
CycleAssignment
 ├─ cycle_number
 ├─ assigned_member_id       (from rotation_order — whose "turn" this officially is)
 ├─ actual_recipient_id      (defaults to assigned_member_id; changes if delegated)
 ├─ delegation_id            (nullable — set if a delegation was approved for this cycle)
 └─ status [pending | ready | paid | failed]
```

### 10.2 The scheduling job (daily tick, per group)
1. Is today a payout day for this group, per its cadence config (§9)?
2. If yes → compute `collected_ratio` from the group pool balance vs target.
3. If quorum met:
   - Look up this cycle's `CycleAssignment`. If there's an **approved, unexpired** delegation or swap affecting this cycle, `actual_recipient_id` already reflects that (set at approval time — see §11); otherwise it's simply `assigned_member_id`.
   - Look up `actual_recipient_id`'s registered payout bank account.
   - Call Monnify **Single Transfer** for the pooled amount, to that recipient.
   - Handle `PENDING_AUTHORIZATION` (OTP) exactly as in v1 (§13.3) — admin approves with their own PIN + the Monnify OTP.
   - On success: mark `CycleAssignment.status = paid`, post to group chat, advance `current_rotation_index` **only if this was not a swap-affected cycle** (swaps already permanently reordered `rotation_order` — see §11.2), open the next cycle.
4. If quorum not met: apply the group's shortfall policy (hold / partial / admin decides), unchanged from v1.

### 10.3 Cutoff rule for delegation/swap requests
Both delegation and swap requests must be submitted and approved **before** the payout scheduler tick fires for that cycle (i.e., before step 3 runs). Once a `CycleAssignment` is marked `paid`, no further changes are possible for that cycle — only future cycles.

---

## 11. Delegate & Swap Mechanics

### 11.1 Delegate — "send my turn's payout to someone else"
- Available only to the member currently `assigned` to the upcoming cycle.
- Flow: member selects a recipient (any other active member of the group) → confirms with PIN → request enters `pending_admin_approval` (if the group requires it — configurable, defaults to **on**) or is `auto_approved` (if the group has disabled the approval requirement).
- On approval: `CycleAssignment.actual_recipient_id` is updated to the delegate; `CycleAssignment.delegation_id` is set; `rotation_order` and `current_rotation_index` are **untouched** — the original member's turn is considered "used" as normal, they simply weren't the one who received the funds.
- A delegation only ever affects the **current** cycle; it is not a standing instruction.

### 11.2 Swap — "trade turns with someone else"
- Either member can initiate, naming the other member and the two cycle numbers being traded.
- The **counterpart must accept** (in-app notification + email) before anything happens — a swap needs consent from both sides, unlike delegation which only needs the assigned member's decision.
- Once both have accepted, the request enters `pending_admin_approval` (default **on**) or `auto_approved`.
- On approval: the two members' positions in `rotation_order` are exchanged for those two cycle slots going forward. This is a **standing change** to the rotation, not a one-cycle redirect — if A and B swap cycle 3 and cycle 7, A is now assigned cycle 7 and B is now assigned cycle 3, permanently (barring a further swap).

### 11.3 Shared rules
- Both delegation and swap are blocked once the affected `CycleAssignment.status` is `paid` (§10.3).
- Both require the initiating (and, for swaps, accepting) member's PIN.
- Both post a system message to group chat on request, on counterpart response (for swaps), and on final approval/rejection — this is deliberately visible to the whole group, not a private side-channel, to preserve the trust properties the app is built around.
- Admin-approval requirement is a **per-group setting**, checked independently for delegation vs swap (a group might allow free delegation but require approval for swaps, since swaps have longer-lasting effects).

---

## 12. Risk Score Methodology

(Unchanged from v1 — included here for completeness.)

| Factor | Weight | Description |
|---|---|---|
| Punctuality | 35% | Average of (contribution timestamp vs cycle deadline) |
| Consistency streak | 25% | Consecutive on-time cycles vs total |
| Completion rate | 25% | % of cycles where full target was met |
| Tenure | 10% | Newer members start neutral (50), not penalized |
| Group-relative standing | 5% | Adjustment relative to the group's own average |

```
score = (0.35 * punctuality_score) + (0.25 * streak_score)
      + (0.25 * completion_score) + (0.10 * tenure_score)
      + (0.05 * relative_score)
```

Badges: **Low risk** (70–100), **Medium** (40–69), **High** (0–39). Delegating or swapping does not itself move this score.

---

## 13. Monnify Integration

### 13.1 Endpoints used

| Capability | Monnify API | Sandbox status | Used for |
|---|---|---|---|
| Personal Reserved Account | Reserved Accounts (Create) | ✅ Works | One per **user**, at onboarding — wallet top-up channel. Note: capped at one reserved account per unique BVN/NIN supplied (`R42` if exceeded) — see §8.1 |
| Get Reserved Account details | Reserved Accounts (Get) | ✅ Works | Display account number/bank in-app |
| Collection webhook | Webhook: successful transaction | ✅ Works | Wallet top-up reconciliation |
| Account name validation | Name Enquiry | ✅ Works (free) | Validate payout bank account at onboarding |
| Payout | Single Transfer (Disbursement) | ✅ Works | Cycle payout to `actual_recipient_id`'s registered account; also user wallet withdrawal, if built |
| OTP authorization | Authorize Transfer / Resend OTP | ✅ Works | Required before any disbursement completes |
| Transfer status | Get Transfer Status | ✅ Works | Reconciliation fallback |
| BVN/NIN Verification | — | ❌ Live only | Mocked (§13.4) |
| *(Superseded — see §8.5)* Group Reserved Account | Reserved Accounts (Create) | ⚠️ Blocked by default (`R42`) | Would have enabled direct-to-group bank transfers via a persistent group account; abandoned in favor of the two rows below, which achieve the same UX without needing Monnify to raise any limit |
| Dynamic Virtual Account creation | Initialize Transaction (`/api/v1/merchant/transactions/init-transaction`) | ✅ Works | Path B, step 1 — creates a one-time payment intent, `paymentReference` encodes `{user, group, cycle}` |
| Dynamic Virtual Account details | Pay with Bank Transfer (`/api/v1/merchant/bank-transfer/init-payment`) | ✅ Works | Path B, step 2 — returns the one-time account number/bank the member pays into; valid 2400s (40 min), fixed |

> Note the important shift from v2: **internal wallet→group transfers (Path A) never call Monnify at all** — only real money entering (wallet top-up, or a Path B direct payment) or leaving (final payouts) AjoPay's settlement balance touches the Monnify API. Groups still have no *persistent reserved* account of their own (v4, §8.1); direct-to-group payment instead uses the transaction-scoped Dynamic Virtual Account flow (§8.5, v5), which was never subject to the `R42` limit in the first place.

### 13.2 Webhook handling
Unchanged from v1: signature verification, idempotency via `processed_webhook_events` keyed on `transactionReference`, always return `200` immediately.

One addition from earlier versions of this PRD, now updated again in v5: since groups still have no persistent reserved account of their own (§8.1), a webhook on the user's own **Reserved Account** is always a Path A wallet top-up. Path B (§8.5) reintroduces a second kind of collection webhook — one tied to a Dynamic Virtual Account's `transactionReference` — but it's never ambiguous, since `paymentReference` already encodes `{user, group, cycle}` at the moment the account was created. No manual attribution step is needed for either branch; this is a different situation from the old shared-group-account model, which genuinely had no clean way to tell senders apart.

### 13.3 Handling MFA/OTP on disbursement
Unchanged from v1 (§9.3 of the original PRD) — sandbox disbursement accounts have MFA on by default; admin approves with the OTP received by email, with a "Resend OTP" fallback.

### 13.4 Mocked BVN Verification
Unchanged from v1 — an internal `/internal/mock/bvn/verify` endpoint shaped like Monnify's real BVN+Account Name Match API, clearly labeled `"mocked": true`, built behind a `KYCProvider` interface for an easy swap to the real endpoint once live keys exist.

---

## 14. System Architecture

Unchanged at a high level — one FastAPI backend, React Native/Expo mobile, Next.js web, shared REST + WebSocket API. The addition in v2 is a **ledger subsystem** (§15) that every wallet/group balance change writes through, plus PIN hashing/verification on the auth layer.

---

## 15. Data Model (v2)

```
User
 ├─ id, name, email, phone, password_hash
 ├─ pin_hash                                  ← NEW: transaction PIN, bcrypt/argon2
 ├─ personal_reserved_account_number, bank     ← NEW: one per user, platform-wide
 ├─ payout_bank_account_number, bank_code, account_name (Name-Enquiry-validated)
 └─ created_at

Wallet
 ├─ id, user_id (1:1 with User)
 ├─ balance                                   ← always derived from WalletLedgerEntry sum, cached for read speed
 └─ updated_at

WalletLedgerEntry                              ← NEW: append-only, never overwritten
 ├─ id, wallet_id
 ├─ type [topup | pay_group | receive_delegation | withdrawal | correction]
 ├─ amount (signed: positive=credit, negative=debit)
 ├─ related_group_id (nullable), related_contribution_id (nullable)
 └─ created_at

Group
 ├─ id, name, created_by_user_id               ← creator, informational only — admin-ness lives on Membership
 ├─ invite_code, invite_code_active            ← regenerable/revocable self-service join code
 ├─ contribution_amount
 ├─ cycle_frequency [weekly|monthly|yearly]
 ├─ payout_day_of_week / payout_day_of_month / payout_month  ← NEW: per §9
 ├─ payout_day_override (nullable, yearly only)
 ├─ quorum_percent, shortfall_policy
 ├─ rotation_order, current_rotation_index, current_cycle_number
 ├─ requires_approval_for_delegate, requires_approval_for_swap  ← NEW
 ├─ pool_balance                               ← derived from GroupLedgerEntry sum
 └─ status, created_at

GroupLedgerEntry                               ← NEW: append-only, mirrors WalletLedgerEntry
 ├─ id, group_id
 ├─ type [contribution_wallet | contribution_direct | payout | correction]   ← contribution_direct added in v5, Path B
 ├─ amount, member_id (nullable for unmatched), cycle_number
 ├─ monnify_transaction_reference (nullable — set for contribution_direct rows, from the Path B webhook)
 └─ created_at

Membership
 ├─ id, group_id, user_id
 ├─ is_admin                                   ← NEW: per-group role — a user can be admin of one group, plain member of another
 ├─ risk_score, risk_factors (json)
 ├─ status [invited|active|removed]
 └─ joined_at

GroupInvite                                    ← NEW: targeted, search-based invite (§24.2)
 ├─ id, group_id, invited_user_id, invited_by_user_id
 ├─ status [pending|accepted|rejected|expired]
 └─ created_at, resolved_at

CycleAssignment                                ← NEW
 ├─ id, group_id, cycle_number
 ├─ assigned_member_id, actual_recipient_id
 ├─ delegation_id (nullable)
 ├─ status [pending|ready|paid|failed]
 └─ payout_reference (Monnify transfer reference)

PayoutDelegation                               ← NEW
 ├─ id, group_id, cycle_number
 ├─ from_member_id, to_member_id
 ├─ status [pending_admin_approval|auto_approved|approved|rejected]
 └─ created_at, resolved_at

PayoutSwapRequest                              ← NEW
 ├─ id, group_id
 ├─ initiator_member_id, counterpart_member_id
 ├─ initiator_cycle_number, counterpart_cycle_number
 ├─ counterpart_response [pending|accepted|declined]
 ├─ status [pending_admin_approval|auto_approved|approved|rejected]
 └─ created_at, resolved_at

UnmatchedContribution                          ← STRETCH ONLY, superseded in v5 — see §8.5
 (Kept for history, not needed for Path B: a Dynamic Virtual Account's paymentReference already encodes {user, group, cycle} at creation, so a Path B payment is never ambiguous. Would only matter again if a future shared-account model were revisited.)
 ├─ id, group_id, sender_account_number, sender_account_name
 ├─ amount, monnify_transaction_reference
 ├─ status [unattributed|attributed]
 └─ received_at

ChatMessage
 ├─ id, group_id, sender_user_id (nullable for system), content, type [user|system]
 └─ created_at

NotificationLog
 ├─ id, user_id, group_id, channel [email|push], event_type, payload
 └─ sent_at

ProcessedWebhookEvent
 ├─ id, monnify_reference, event_type
 └─ processed_at
```

---

## 16. Sample Lifecycles

Setup for all three examples: **"Umbrella Traders" group**, 5 members (Ada, Bola, Chidi, Dayo, Efe), ₦10,000/member/cycle, **weekly** cadence, payout day = **Friday**, quorum = 100%, rotation order = [Ada, Bola, Chidi, Dayo, Efe], delegation and swap both require admin approval.

### 16.1 Standard lifecycle (no delegation or swap)

1. **Monday:** Cycle 1 opens. `CycleAssignment` created: `assigned_member_id = Ada`, `actual_recipient_id = Ada`, `status = pending`.
2. **Tuesday:** Bola tops up her personal wallet with ₦15,000 — transfers to her own Reserved Account, webhook fires, `WalletLedgerEntry(type=topup, amount=+15000)` created, wallet balance now ₦15,000.
3. **Tuesday, later:** Bola opens the group, taps "Pay from wallet," enters ₦10,000 and her PIN. AjoPay debits her wallet (`WalletLedgerEntry(type=pay_group, amount=-10000)`), credits the group pool (`GroupLedgerEntry(type=contribution_wallet, amount=+10000, member_id=Bola)`). No Monnify call. Chat: *"Bola contributed ₦10,000 (1/5 collected)."*
4. **Wednesday:** Chidi, Dayo, and Efe each top up their own personal wallets (each transferring ₦10,000+ to their own Reserved Account), then each taps "Pay from wallet" with their PIN to contribute ₦10,000 to the group pool — same mechanic as Bola's, just three more members going through it. Chat updates after each: *"4/5 collected."*
5. **Thursday:** Ada tops up and pays her own ₦10,000 the same way. Group pool now at target — *"5/5 collected, quorum met."*
6. **Friday (payout day):** Scheduler tick runs, sees quorum met, resolves `actual_recipient_id = Ada` (no delegation/swap on record), initiates Monnify Single Transfer of ₦50,000 to Ada's registered bank account.
7. Monnify returns `PENDING_AUTHORIZATION`. Admin gets an email OTP, opens "Approve Payout," enters admin PIN + the OTP, submits.
8. Transfer completes. `CycleAssignment.status = paid`. Chat: *"Payout of ₦50,000 sent to Ada."* Rotation pointer advances to Bola for cycle 2.

### 16.2 Delegation lifecycle

Same group, **cycle 2**, assigned member is **Bola**.

1. **Monday:** Cycle 2 opens. `CycleAssignment(assigned_member_id=Bola, actual_recipient_id=Bola, status=pending)`.
2. Contributions come in through the week as usual (each member topping up their wallet, then paying the group from it), reaching quorum by Thursday.
3. **Thursday:** Bola realizes she'd rather this cycle's payout go straight to her sister Efe (also a group member) for a joint expense. She opens "My Payout," taps "Send to someone else," selects Efe, confirms with her PIN.
4. A `PayoutDelegation(from=Bola, to=Efe, cycle=2, status=pending_admin_approval)` is created. Chat: *"Bola has requested to delegate her cycle 2 payout to Efe — awaiting admin approval."*
5. Admin reviews in the dashboard, confirms this is legitimate (both are real, active members), approves with their PIN.
6. `PayoutDelegation.status = approved`. `CycleAssignment.actual_recipient_id` updates to Efe, `delegation_id` set. Chat: *"Delegation approved — cycle 2 payout will go to Efe."*
7. **Friday:** Scheduler tick resolves `actual_recipient_id = Efe`, disburses ₦50,000 to **Efe's** registered bank account (not Bola's), following the same OTP-approval flow as §16.1 step 7–8.
8. `CycleAssignment.status = paid`. Rotation pointer still advances to **Chidi** for cycle 3 — Bola's turn was used as normal; only the destination of the funds changed.

### 16.3 Swap lifecycle

Same group, now at **cycle 3** (Chidi assigned) and looking ahead to **cycle 5** (Efe assigned, since Ada, Bola already had turns 1–2 and Bola's cycle-2 slot doesn't change who's due later).

1. Chidi has an urgent expense and would rather receive cycle 5's slightly later date... actually the reverse: Chidi wants to move **earlier**, so he asks Efe (assigned cycle 5) to trade — Chidi takes cycle 5, Efe takes cycle 3.

   *(Concretely: Chidi initiates a swap proposing "I take your cycle 5 slot, you take my cycle 3 slot.")*

2. Chidi opens "Swap My Turn," selects Efe, confirms with PIN. `PayoutSwapRequest(initiator=Chidi, counterpart=Efe, initiator_cycle=3, counterpart_cycle=5, counterpart_response=pending, status=pending_admin_approval)` is created — status only progresses past `pending_admin_approval` once Efe has also responded.
3. Efe receives an in-app + email notification: *"Chidi wants to swap: he'd get your cycle 5 turn, you'd get his cycle 3 turn."* Efe reviews and taps "Accept," confirming with her own PIN. `counterpart_response = accepted`.
4. Now both parties have consented; the request moves to admin for approval (group setting requires it for swaps). Admin reviews and approves with their PIN.
5. `rotation_order` is updated: the member previously in the cycle-3 slot (Chidi) is replaced by Efe, and the member previously in the cycle-5 slot (Efe) is replaced by Chidi. This is a standing change — Chidi is now due at cycle 5 for good (not just this once), and Efe is due at cycle 3.
6. Chat: *"Chidi and Efe have swapped turns — Efe will now receive cycle 3's payout, Chidi will receive cycle 5's."*
7. Cycle 3 proceeds exactly like §16.1's standard lifecycle, except `CycleAssignment(cycle=3).assigned_member_id` is now Efe (not Chidi) from the start — this wasn't a per-cycle redirect like delegation, it changed who was assigned before the cycle even reached quorum.

---

## 17. Notifications — Event Matrix (updated)

| Event | Email | In-app/Push | Chat system message |
|---|---|---|---|
| Wallet top-up received | ✅ | ✅ | — |
| Contribution received (wallet → group, Path A) | ✅ | ✅ | ✅ |
| Direct-to-group contribution received (Path B) | ✅ (to contributor) | ✅ | ✅ |
| *(Stretch, superseded in v5 — see §8.5)* Unmatched direct contribution needs attribution | ✅ (to admin) | ✅ | — |
| Cycle reminder (T-2 days) | ✅ | ✅ | ✅ |
| Delegation requested | ✅ (to admin + delegate) | ✅ | ✅ |
| Delegation approved/rejected | ✅ | ✅ | ✅ |
| Swap requested | ✅ (to counterpart) | ✅ | ✅ |
| Swap accepted/declined by counterpart | ✅ | ✅ | ✅ |
| Swap approved/rejected by admin | ✅ | ✅ | ✅ |
| Payout awaiting authorization | ✅ (to admin, OTP prompt) | ✅ | — |
| Payout success | ✅ (to recipient + group) | ✅ | ✅ |
| Payout failed | ✅ (to admin) | ✅ | ✅ |
| Member risk flagged High | ✅ (to admin) | ✅ | — |
| Direct invite sent | ✅ (to invited user) | ✅ | — |
| Direct invite accepted/rejected | ✅ (to admin) | ✅ | ✅ (accepted only) |
| New member joined (via code or invite) | ✅ (to group) | ✅ | ✅ |

---

## 18. Non-Functional Requirements

- Same as v1 (idempotent webhooks, signature verification, no secrets in repo, mobile-first responsive web), plus:
- **PIN security:** hashed at rest, rate-limited attempts with cooldown/lockout, never included in logs or error messages.
- **Ledger integrity:** wallet and group balances are always derived from summing ledger entries, never mutated directly — this makes the system auditable and recoverable.

---

## 19. MVP Scope (Must / Should / Could) — updated

**Must have:**
- Personal wallet + reserved account per user (groups have no Monnify account of their own — see §8.1)
- Both funding paths: wallet-pay (Path A) and direct-to-group via one-time Dynamic Virtual Account (Path B, §8.5) — self-attributing by design, no manual matching UI needed
- Transaction PIN on all outbound actions (§8.3 table)
- Weekly/monthly/yearly cadence config with correct day/month picker
- Automatic payout engine incl. OTP-approval handling
- Risk score
- Group chat, core email notifications
- Mocked BVN flow

**Should have:**
- Delegation flow end-to-end (§11.1, §16.2)
- Admin approval settings per group for delegate/swap
- ~~Unmatched-contribution admin attribution UI~~ *(superseded in v5 — Dynamic Virtual Accounts self-attribute, see §8.5)*

**Could have (only if ahead of schedule):**
- Swap flow end-to-end (§11.2, §16.3) — more complex due to mutual consent, build after delegation is solid
- Wallet withdrawal to external bank account
- AI-generated localized reminder copy
- Platform fee via sub-accounts

> If time is tight, ship delegation but demo swap as a "coming next" slide — the two share most of their plumbing (`CycleAssignment`, PIN gating, admin approval), so delegation alone still tells a complete, honest story.

---

## 20. Suggested Build Timeline (6-day window)

| Day | Focus |
|---|---|
| Day 1 | Sandbox setup, MFA-waiver email, FastAPI scaffolding, DB schema incl. ledger tables, personal Reserved Account creation (groups get none — see §8.1) |
| Day 2 | Wallet top-up flow, PIN set/verify, onboarding (mocked BVN + Name Enquiry) |
| Day 3 | Both contribution paths (Path A wallet, Path B Dynamic Virtual Account — §8.5), rotation engine + cadence config (§9) |
| Day 4 | Payout engine incl. OTP-approval, `CycleAssignment` logic, risk score, admin dashboard |
| Day 5 | Delegation flow end-to-end, group chat, notifications |
| Day 6 | Swap flow if time allows, end-to-end testing, demo video, README, submission |

---

## 21. Demo Script (aligned to judging criteria)

1. Open with the problem (treasurer disappears with contributions).
2. Onboard two test members, show mocked BVN + Name Enquiry + PIN setup.
3. Show **both** funding paths live: one member tops up wallet then pays the group (Path A); another pays the group directly via a fresh one-time Dynamic Virtual Account generated for that exact payment (Path B, §8.5), landing straight in the group pool with zero manual matching.
4. Show a **delegation**: assigned member redirects this cycle's payout to someone else, admin approves, payout goes to the delegate.
5. Trigger payout day, show the OTP-approval step happening live.
6. Show risk score badge + factor breakdown for a deliberately late member.
7. Close with roadmap: swap flow (if not fully built), real BVN on live keys, wallet withdrawal, Direct Debit auto-contribution.

---

## 22. Risks & Mitigations (updated)

| Risk | Mitigation |
|---|---|
| Ledger drift between AjoPay's internal balances and actual Monnify settlement balance | Append-only ledger design (§8.4, §15) makes balances always recomputable and auditable; add a scheduled job that periodically diffs ledger sums against Monnify's real transaction history |
| Swap/delegation abuse (e.g. pressuring a member into delegating) | Every request and resolution is posted publicly to group chat, not hidden — visibility is the main defense; admin approval is on by default for both |
| PIN brute-forcing | Rate limiting + lockout on repeated failures |
| MFA waiver not granted before demo | Same as v1 — OTP-approval is designed as a first-class UX, not a failure state |
| Two-person team, now with more surface area (wallet + delegation/swap) | Strict Must/Should/Could split (§19); swap explicitly deprioritized below delegation since it shares most of the same plumbing |

---

## 23. Success Metrics (for the demo)

- End-to-end cycle completes with **both** funding paths exercised in the same demo.
- A delegation (and, if built, a swap) completes end-to-end with correct fund routing.
- Wallet and group ledger balances reconcile to zero drift against Monnify's own transaction history at the end of the demo.
- Judges can clone the repo and get a working local instance following the README in under 10 minutes.

---

## 24. Group Joining & Membership Flows

### 24.1 Path A — Invite code (self-service)
- Every group has a short, human-shareable `invite_code` (e.g. 6–8 alphanumeric characters), generated when the group is created.
- A prospective member can enter this code **either as a step during their own onboarding** (before they've finished signing up — "Have a group code? Enter it now or skip") **or at any point afterward** from an in-app "Join a group" screen.
- Entering a valid, active code joins the group immediately — no admin approval step, since possessing the code is treated as sufficient authorization (the admin controls distribution of the code itself).
- The admin can **regenerate** the code at any time from group settings, which immediately invalidates the old one (existing members are unaffected — this only blocks *new* joins via the stale code). Useful if a code is shared somewhere it shouldn't be.
- If the group is at its member cap, or `invite_code_active` has been turned off, code entry fails with a clear error rather than a silent no-op.

### 24.2 Path B — Direct invite (targeted, search-based)
- An admin (of any group) can search for an **already-registered** user by **exact email or exact username match only** — not a fuzzy/partial search across all users, which would let anyone enumerate the user base. If there's no exact match, the admin sees "No user found with that email/username," not a list of near-matches.
- The admin sends the invite. A `GroupInvite` record is created (`status = pending`).
- The invited user sees it **both** as an email and as an in-app notification/badge, with **Accept** / **Reject** actions — the same accept-or-decline pattern already used for swap counterparts (§11.2), so it's a consistent interaction the user has likely already seen elsewhere in the app.
- On **Accept**: a `Membership` is created (`is_admin = false`), a chat system message announces the new member, and the admin is notified.
- On **Reject**: the `GroupInvite` is marked `rejected`; the admin is notified but the user's decision is not exposed to the rest of the group.
- No code is ever involved in this path — the whole point is that the admin already knows exactly who they want to invite.

### 24.3 Common rules across both paths
- A user cannot join the same group twice; re-entering a code or re-accepting an invite while already an active member is a no-op with a friendly message, not an error.
- A user **previously removed** from a group can rejoin via either path unless the admin has explicitly blocked them (a `banned_user_ids` list on the group, stretch — not required for MVP).
- Every successful join, regardless of path, posts the same **"X joined the group"** chat system message — members shouldn't be able to tell from the chat alone whether someone came in via code or direct invite.

### 24.4 Multi-group membership & admin scoping
- **Admin is a property of the `Membership` row (`is_admin`), never of the `User` globally.** A person who creates "Umbrella Traders" is automatically `is_admin = true` on that Membership, and can simultaneously hold `is_admin = false` Memberships in as many other groups as they've joined via §24.1/§24.2.
- The mobile/web client maintains a lightweight **"active group" context** — much like a workspace switcher (Slack-style). On mobile, this is a drawer or top-bar switcher listing every group the user belongs to (with an unread/pending-action badge per group where relevant); on web, a persistent sidebar. Switching groups changes which group's chat, cycle status, and rotation timeline are shown — the user's **wallet is the one thing that stays constant across the switch**, since it's a platform-level concept, not a per-group one (§8.1).
- `GET /users/me/groups` (or equivalent) returns every group the current user belongs to, plus their `is_admin` flag and any pending action counts (unread chat, pending delegation/swap approvals if admin, etc.) — this is what powers the switcher UI.

### 24.5 Sample lifecycle: joining via invite code

1. Efe wants to join "Umbrella Traders." Ada (the group's admin) shares the invite code `UMB-7F3K` with her over WhatsApp.
2. Efe is new to AjoPay — during signup, on the "Have a group code?" step, she enters `UMB-7F3K`.
3. Backend validates: code is active, group isn't at capacity. Efe's account is created, and a `Membership(group=Umbrella Traders, user=Efe, is_admin=false)` is created in the same flow.
4. Efe lands directly in the group's chat, sees the system message *"Efe joined the group,"* and immediately sees the current cycle status.
5. Later, Efe is invited to a second, unrelated group ("Market Women's Circle") the same way, using that group's own code. Her group switcher now shows both groups; her wallet balance is shared across both.

### 24.6 Sample lifecycle: joining via direct invite

1. Chidi is already a registered AjoPay user — in fact, he's the **admin** of his own group, "Bike Riders Ajo." He is not yet in "Umbrella Traders."
2. Ada wants Chidi in "Umbrella Traders" specifically (not just anyone with a code), so from her admin dashboard she searches `chidi@example.com` — an exact match returns his profile.
3. Ada taps "Send Invite." A `GroupInvite(group=Umbrella Traders, invited_user=Chidi, invited_by=Ada, status=pending)` is created; Chidi gets an email and an in-app badge.
4. Chidi opens the invite, sees which group and who invited him, and taps **Accept**.
5. `Membership(group=Umbrella Traders, user=Chidi, is_admin=false)` is created. Chat: *"Chidi joined the group."* Ada is notified the invite was accepted.
6. Chidi's group switcher now shows **three** groups: "Bike Riders Ajo" (where he's admin), "Umbrella Traders" (where he's just a member), and any others he's already in — same user, same wallet, different roles in different spaces.


### Collateral feature
This is the single most important question to have answered before your demo — it's the exact scenario your own opening pitch line (treasurer disappears with the money) promises to solve, so judges will absolutely ask it if you don't address it first. Let me walk through the real mechanism, then update the PRD.
The actual problem, named precisely
In rotating savings groups, the person who collects early in the rotation has the most to gain and the least at stake — they've paid in maybe one round, received the full pool, and now have every incentive to vanish rather than keep contributing for everyone else's turns. This is a well-known failure mode of ROSCAs generally, not just Nigerian ajo — and it's the one thing a human treasurer's social pressure was actually doing that your app needs to replace with something structural.
Risk score alone doesn't solve it — by definition, a brand-new member has no history yet, so the score can't warn you about someone who's never defaulted before.
The real fix: locked collateral, not just trust
Here's the mechanism that actually works, and it's only possible because of the wallet architecture we already built: since a member's money sits inside AjoPay's own settlement balance the moment they top up their wallet, AjoPay has direct custodial control over locked funds — it doesn't need the member's cooperation or PIN to seize collateral if they default. That's the whole unlock.
Concretely:

Before a member can be assigned a rotation position, they must lock a security deposit in their wallet (e.g. equal to one contribution round).
This deposit is frozen — not spendable, not withdrawable — until they've completed every remaining contribution owed after their own payout.
If a cycle passes and they haven't paid, AjoPay automatically pulls the shortfall from their locked deposit into the group pool. No PIN needed, no cooperation required — this is the whole point of it being locked collateral rather than a promise.
If they never come back at all, the rest of the group is still made whole (fully, if the deposit covers their full remaining obligation) — the "run away" scenario becomes a non-event instead of a catastrophe.

What BVN is actually for (your direct question)
You're right that just collecting it and storing it does nothing by itself. Its real value is as a persistent identity key, not a one-time checkbox:

A phone number or email can be thrown away and recreated in five minutes. A BVN can't — it's tied to one real person's entire banking life.
That means a default can be recorded against the BVN, not against the AjoPay account — so if someone defaults in Group A, deletes their account, and tries to sign up fresh to join Group B, the same BVN can flag them before they're ever assigned an early rotation slot again.
In a live (non-sandbox) version, this could eventually hook into Nigeria's existing BVN-linked bank fraud/watchlist infrastructure — meaning a serial defaulter's problem stops being "just this app" and starts threatening their standing with real banks. That's a genuine deterrent, not just a database flag. Worth being honest with judges that this last part is roadmap, not built — sandbox can't verify real BVNs anyway (§13.4) — but the architecture is designed to support it the moment live keys exist.



**A sub-account is a second, real bank account you register with Monnify — not a database concept**

`POST /api/v1/sub-accounts` (from your own guide's §9/Folder 5) takes a currency, bank code, and **an actual account number** — the destination you want your cut to land in — and gives you back a `subAccountCode`. That's a one-time setup step you genuinely haven't done yet. Nothing routes anywhere until this exists.

**The split only happens at the moment real money touches Monnify — not on your internal wallet→group transfer**

This is the part worth being precise about, because it's easy to assume "every contribution" gets split, and that's not quite right given your architecture:

- `incomeSplitConfig` gets attached to a Reserved Account **at creation time** (it's a field in the same `POST` request you already use to create each user's account). From then on, *every payment that lands on that reserved account* — i.e. every wallet top-up (Path A) — automatically gets sliced.
- For Path B (Dynamic Virtual Account), the same `incomeSplitConfig` array can instead be attached to the **Initialize Transaction** call, so a direct-to-group payment gets sliced at that point.
- Your internal wallet → group pool step (§8.2) **can never carry a split**, because no Monnify transaction happens there at all — there's nothing for Monnify to slice. This means: if you only configure splitting on the Reserved Account, you're taking a cut on **wallet funding**, not on "each contribution" the way I loosely phrased it last time. Worth deciding deliberately whether that's actually what you want.

**What the fields actually do (this is where I was too vague before):**

```json
"incomeSplitConfig": [
  {
    "subAccountCode": "MFY_SUB_xxxx",
    "splitPercentage": 1,
    "feePercentage": 100,
    "feeBearer": true
  }
]
```
- `splitPercentage` (or `splitAmount` for a flat figure) — this is your actual platform cut: the % of the transaction amount diverted to your sub-account, off the top, automatically.
- `feePercentage` — a separate thing entirely: what share of *Monnify's own* transaction fee (the 1.5%, capped at ₦2,000) the sub-account is responsible for, versus your main account.
- `feeBearer` — whether that fee responsibility is charged to the sub-account or absorbed elsewhere.

So on a ₦10,000 top-up with `splitPercentage: 1`: ₦100 goes straight to your sub-account's real bank account, and the rest settles toward your main balance (which is what backs the wallet), separately from however Monnify's own ₦150 processing fee gets apportioned via `feePercentage`.

**The real product question this raises, which you'll need to decide:** if ₦100 gets skimmed at top-up, does the member's wallet show ₦10,000 or ₦9,900? If it silently shows less than what they sent, that's a transparency problem worth designing around explicitly (e.g. showing "₦10,000 received, ₦9,900 credited, ₦100 platform fee" rather than a mismatched number with no explanation).

**What's actually needed to turn this on, concretely:**
1. Create one sub-account pointing at a real bank account (yours) — one-time.
2. Add `incomeSplitConfig` to the Reserved Account creation call for **new** users going forward — I haven't confirmed whether Monnify has an update endpoint that retroactively adds a split to an *already-created* reserved account, so I wouldn't assume that's possible without checking the docs directly.
3. Separately decide whether to also attach it to Path B's Initialize Transaction, if you want direct-to-group payments fee'd too.

