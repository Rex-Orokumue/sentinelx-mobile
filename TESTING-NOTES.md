# Testing Notes

Tracks every `zzqa_`-prefixed test account created while testing Phase 1's
signup/onboarding/confirmation flow against production (no staging DB exists
— see the design spec §5). Reused test accounts (non-signup flows) are not
logged here.

| Username | Date | Verified | Cleaned up (anonymise_account) |
|---|---|---|---|
| zzqa_p1a | 2026-09-21 | not created: signup blocked, Supabase Auth returned 500 (Resend 550, sentinelxesports.com.ng sender domain not verified); nothing to clean up | n/a |
