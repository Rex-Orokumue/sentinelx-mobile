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
