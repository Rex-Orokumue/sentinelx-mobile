# Testing Notes

Tracks every `zzqa_`-prefixed test account created while testing Phase 1's
signup/onboarding/confirmation flow against production (no staging DB exists
— see the design spec §5). Reused test accounts (non-signup flows) are not
logged here.

| Username | Date | Verified | Cleaned up (anonymise_account) |
|---|---|---|---|
| zzqa_p1a | 2026-09-21 | not created: signup blocked, Supabase Auth returned 500 (Resend 550, sentinelxesports.com.ng sender domain not verified); nothing to clean up | n/a |
| zzqa_p1a | 2026-09-22 | created + confirmed after the Resend DNS fix: signup returned 200, confirmation email delivered, App Link tap → `verifyOtp` → landed on Home signed in | Yes |

## 2026-09-25 — Phase 1 auth/lifecycle hardening (`fix/phase1-auth-lifecycle`)

Manual check on a physical phone (Samsung SM-S9010, Android 16), debug build against production, Google sign-in via a
`GOOGLE_WEB_CLIENT_ID` dart-define.

| # | Check | Result |
|---|---|---|
| 1 | Signed-in account with no username is sent to `/onboarding/username`; after claiming a name it lands on Home and stays there (no bounce back) | Passed (fresh Google account) |
| 2 | `type=email_change` link as an onboarded user lands on Home | Not run — routing covered by `incoming_links_test.dart` only |
| 3 | `/session/start` fires once across background/resume cycles | Passed — one call after a cold start plus several background/resume cycles (temporary log, removed). A real token refresh (~1h expiry) was not observed; user-id dedupe is unit-tested |
| 4 | Failed login, then navigate away mid-request: no `setState() after dispose()` | Passed |
| 5 | Offline login and Google sign-in show readable localized text, no raw exception | Passed. Login's generic fallback reads "…creating your account", which is signup wording (deferred) |

Test account: created by Google sign-in during check 1 — needs `anonymise_account` cleanup (not yet done).

## 2026-09-26 — Phase 2a (Compete: browse, register, pay) — device checks PENDING

Not run yet: the owner chose to build all phases first and test on the phone together. **Staging only** (Supabase
`ofxmoxpvwbemfouaowoa`, web dev server on the branch with Paystack **test** keys — launch command in
`docs/agent-handoffs/2026-09-25-mobile-phase3b-flutter-session-notes.md`). `config/dev.json` alone points at PRODUCTION
(app_config defaults), so always pass the `--dart-define` overrides. Use a staging `zzqa_` account and log it below.

| # | Check | Result |
|---|---|---|
| 1 | Browse: tabs (All/Live/Upcoming/Completed), game filter, load more, open a tournament, open one by web link slug | pending |
| 2 | Register at full price → Paystack test card → WebView closes on callback → "Payment confirmed" → state shows registered | pending |
| 3 | Register with coin discount (half and full) → correct fee in Paystack / confirmed when discounted to zero | pending |
| 4 | Register with a fee waiver (create one on staging) → confirmed with no WebView | pending |
| 5 | Close the WebView mid-payment → "Payment window closed" → tournament shows Resume payment → resume works | pending |
| 6 | Airplane-mode toggle during submit, retry: exactly one `api_idempotency_keys` row and one registration row on staging | pending |
| 7 | Signed out shows Log in to register. Account without a username is routed to onboarding, then registration succeeds with a NEW key | pending |
| 8 | Full tournament: no waitlist button. Closed tournament: waitlist join works; a second join says already on the waitlist | pending |
| 9 | Invitations: accept (free and paid) and decline | pending |
| 10 | Games list; edit profile (name, bio, country, one-time username change; a second change shows the locked message); an existing bio survives a name-only edit | pending |
| 11 | 375px: no overflow on any of the above | pending |
| 12 | The Paystack WebView intercepts `/api/paystack/callback` on the real host AND on the LAN dev host | pending |
