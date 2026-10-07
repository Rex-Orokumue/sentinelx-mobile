# Testing Notes

Tracks every `zzqa_`-prefixed test account created while testing Phase 1's
signup/onboarding/confirmation flow against production (no staging DB exists
— see the design spec §5). Reused test accounts (non-signup flows) are not
logged here.

| Username | Date | Verified | Cleaned up (anonymise_account) |
|---|---|---|---|
| zzqa_p1a | 2026-09-21 | not created: signup blocked, Supabase Auth returned 500 (Resend 550, sentinelxesports.com.ng sender domain not verified); nothing to clean up | n/a |
| zzqa_p1a | 2026-09-22 | created + confirmed after the Resend DNS fix: signup returned 200, confirmation email delivered, App Link tap → `verifyOtp` → landed on Home signed in | Yes |
| zzqa_mobile_profile | 2026-10-03 | staging-only account created and email-confirmed for physical-device profile-onboarding verification; auth user `aeaffd10-35e7-4952-8e9b-a0acb0762537` | Pending |
| zzqa_profile_retest | 2026-10-05 | staging-only account created and email-confirmed for the one-submit profile-onboarding regression retest; auth user `9b04ec85-6d0d-401c-b671-5a405f29f142` | Pending |

Profile-onboarding device result: the original run required two successful submits because navigation happened before
the refreshed `/me` completed. The app now waits for that refresh, with a regression test that fails when the wait is
removed. On 2026-10-05, a fresh incomplete staging account reached the compulsory form. Its first request exposed a
staging game ID that PostgreSQL accepts but strict RFC UUID validation rejected; after the web request and `/me`
response schemas were aligned with PostgreSQL UUIDs, one submit returned HTTP 200 and opened Home. Opening Account
then showed the completed profile. A separate account-screen regression now renders `/me` failures as a localized
error with Retry instead of falsely showing Log in/Create account. The Edit Profile and airplane-mode checks remain
pending. Staging test account cleanup remains Pending until those checks finish.

Fresh-context review on 2026-10-05 found and fixed five pre-device blockers: canonical country-name drift, default-false
consent being treated as an answer, 401 login bounce, hidden Edit Profile server field errors, and insufficient real-router
coverage. The combined focused profile/gate/router/push/contract suite passes (79 tests). No live calls were made.
Follow-up review found four additional canonical country labels and a router-refresh regression that could pop a
pushed screen on token refresh. Both now have regression coverage; router reevaluation preserves the pushed stack.
The final post-rebase suite passed all 1,342 tests. After the Account error-state regression was added, the full suite
passed all 1,345 tests and `flutter analyze` reported no issues.

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
| 5 | Close the WebView mid-payment → "Payment window closed" + a **Check payment status** button (no Continue) → after paying elsewhere it confirms; the tournament shows Resume payment; resume re-runs the form (fresh reference — web's behavior) | pending |
| 6 | Airplane-mode toggle during submit, retry: exactly one `api_idempotency_keys` row and one registration row on staging | pending |
| 7 | Signed out shows Log in to register. Account without a username is routed to onboarding, then registration succeeds with a NEW key | pending |
| 8 | Full tournament: no waitlist button. Closed tournament: waitlist join works; a second join says already on the waitlist | pending |
| 9 | Invitations: accept (free and paid) and decline | pending |
| 10 | Games list; edit profile (name, bio, country, one-time username change; a second change shows the locked message); an existing bio survives a name-only edit | pending |
| 11 | 375px: no overflow on any of the above | pending |
| 12 | The Paystack WebView intercepts `/api/paystack/callback` on the real host AND on the LAN dev host | pending |

## 2026-09-26 — Phase 3a progress screens (`phase3a/screens`)

- `flutter gen-l10n`: passed.
- `flutter analyze`: no issues.
- `flutter test`: 163 tests passed.
- Added widget coverage for rankings rows/wins expansion, seasons list and empty detail, Hall of Fame sections, Home entry points, and localized web-link routing.
- No production writes were made; Phase 3a endpoints and verification are read-only.
- Live staging/device interaction was not run because the Vercel preview hostname remained unavailable through Windows DNS and the in-app browser rejected its sandbox metadata. The web preview itself reported ready; this limitation was also recorded on the web API PR.

## 2026-09-27 — Phase 2b (bracket, Match Centre, check-in, result/rating/wager, lobby result) — device checks PENDING

Not run yet: nothing here can run against a real server today (the web repo's twelve Phase 2b endpoints live on
an unmerged branch). **Staging only** once the web endpoints are live (Supabase `ofxmoxpvwbemfouaowoa`, web dev
server on that branch — launch command in `docs/agent-handoffs/2026-09-25-mobile-phase3b-flutter-session-notes.md`).
`config/dev.json` alone points at PRODUCTION, so always pass the `--dart-define` overrides. Check-in, result, rating,
wager and lobby-result are writes (wager spends coins) — never run them against production. Use two staging
`zzqa_` test players plus an admin session on the web to confirm results, and log accounts below.

| # | Check | Result |
|---|---|---|
| 1 | Bracket for a group+knockout tournament: standings tables, fixtures buckets, knockout rounds; compare group tables and the champion against the web page for 3 tournaments | pending |
| 2 | A points-race tournament: Stages → standings table matches the web | pending |
| 3 | Match Centre as a guest, as a participant, as a non-participant (each control set as specified) | pending |
| 4 | Check-in on match day; before match day shows the localized "match day" message; double-tap sends one request | pending |
| 5 | Submit a result with a screenshot: file appears in `match-evidence/<uid>/<matchId>/…` on staging; the web admin review page shows the pending result; app shows "awaiting confirmation" only | pending |
| 6 | Airplane-mode toggle during submit, retry: exactly one `api_idempotency_keys` row, one `match_results` row, one storage object | pending |
| 7 | Admin confirms on web → pull-to-refresh: score appears, Rate button appears; rate 5★ → `+20` SX Score event exists once; rate again → "already rated" | pending |
| 8 | Wager as a third player: place, change, insufficient coins, window closed; coin ledger correct | pending |
| 9 | Lobby result from the Home card; second submit after admin confirm shows the locked message | pending |
| 10 | Home fixtures card: next match, submit prompt, banners, pending payment row | pending |
| 11 | Deep link `/matches/<id>` from a browser opens the Match Centre | pending |
| 12 | 375px: no overflow on any screen above | pending |

- `flutter gen-l10n`: passed (French copy is machine-written and flagged for native review — see PR/handoff note).
- `flutter analyze`: no issues.
- `flutter test`: 496 tests passed.
- No production writes were made; nothing in this phase has run against a real server (staging or production) — the
  API models were verified only against the Phase 2b endpoint definitions (zod schemas) on the web branch.
- The screenshot upload path (`SupabaseEvidenceUploader` → private bucket `match-evidence`) is exercised only by fakes
  in widget tests; it has not run against the real staging bucket.

## Phase 5a - notifications and push (device pass, owner)

Not verifiable in unit tests: FCM delivery, Doze / OEM battery behavior, channel behavior and the Android 13+
permission dialog on a real device, a tap from a killed app, and iOS (payload shape only; no iOS build until
Phase 10). Run on **staging**, with `android/app/google-services.json` in place and the staging web deployment
sending with Firebase project `sentinelx-f061e` credentials (**open item: unconfirmed** - without it tokens
registered from the staging app are unreachable).

| # | Check | Result |
|---|---|---|
| 1 | Sign in; confirm `fcm_tokens` has a row for this phone with `platform = android` (POST /devices ran) | PASS 2026-10-06 (Galaxy S9010, Android 16, staging via local web dev server). Token registered; server sent to platform android |
| 2 | Settings -> Notifications -> "Send a test notification" with the app in the **foreground**: in-app banner; tap opens Settings -> Notifications | PASS 2026-10-06 foreground: banner shown; tap stayed on Settings -> Notifications (already the destination) |
| 3 | Same test with the app in the **background**: a system notification on the right channel; tap opens the destination | PASS 2026-10-06 background: system notification arrived; tap opened Settings -> Notifications |
| 4 | Same test with the app **killed**: it still arrives (notification block); tap cold-starts straight to the destination, no login/onboarding bounce | PASS 2026-10-06 killed: notification arrived; tap cold-started to the destination, no login bounce |
| 5 | Android 13+: the permission dialog appears **once**, after the first confirmed stake (register / waitlist / invitation accept), not at launch; deny it and confirm it is never re-asked and the passive rows show "Open system settings" | pending |
| 6 | Turn notifications on in system settings, return to the app: the passive row disappears (resume refresh) | pending |
| 7 | A real fixture assignment arrives, on the Matches channel; tap opens the match | pending |
| 8 | Bell: unread badge updates live; mark read, mark all read; mute a type for 1h and "always"; mute a post thread; unmute | pending |
| 9 | Settings toggles edit the same preferences as the website; flip one on each and see it on the other | pending |
| 10 | Account switch on one phone: sign out (token unregistered), sign in as another user (token registered to them); a push for the first user no longer arrives | pending |
| 11 | Sign out with the network off: sign-out still completes | pending |
| 12 | 375px: no overflow on the bell, the mute sheet, the settings screen (also in French) | pending |
| 13 | Tap a push whose link has no screen yet (e.g. a wallet notification): opens the bell, does nothing else | pending |

## Phase 5b - direct messages (device pass, owner)

Not verifiable in unit tests: anything that needs two real accounts, real Realtime, real Storage or real hardware.
Run on **staging** (`sentinelx-staging`, `ofxmoxpvwbemfouaowoa`, via `--dart-define` of `SUPABASE_URL`,
`SUPABASE_PUBLISHABLE_KEY`, `API_BASE_URL`) with two real accounts (`zzqa_` prefix) on two devices (or one device and
the staging web). Never against production.

| # | Check | Result |
|---|---|---|
| 1 | Send and receive text both ways; ticks go sent -> delivered -> read as the other side opens the thread | pending |
| 2 | Photo: send one; the **received file has no GPS EXIF** (inspect it); a 4000 px photo arrives at <= 1600 px | pending |
| 3 | Sticker: all 14 send and render on both sides | pending |
| 4 | Voice note: record -> pause -> review -> send -> play on the other device; the 120 s cap lands in review; a phone call mid-recording pauses it (no auto-resume); deny the microphone, then Open settings, then return: the banner clears | pending |
| 5 | Reply (quote shows), edit and unsend inside 10 minutes, and the controls gone after 10 minutes | pending |
| 6 | Forward a message to another conversation | pending |
| 7 | Typing shows in both directions, and is **absent** in a pending request thread and in a blocked thread | pending |
| 8 | Online dot appears/disappears as the other account opens/backgrounds the app | pending |
| 9 | DM push in the **foreground**: open thread = no banner, another thread = banner; **background** and **killed**: tap opens the thread over the current tab and Back returns to that tab | pending |
| 10 | Message request, end to end: a stranger starts a thread -> the recipient sees a preview-only thread, **no read receipt and no push** -> Accept; Decline looks like a block to the sender; replying auto-accepts; the outgoing side notices acceptance within about 25 s | pending |
| 11 | Block, unblock and report from the menu and from a message | pending |
| 12 | Airplane-mode toggle, and background for 10 minutes then return: the window reconciles with no gap and expired image/voice URLs refresh | pending |
| 13 | Realtime rejoin after a network loss (Ruling 4: whether `realtime_client` re-fires `subscribed` on its own rejoin is unverified) | pending |
| 14 | `markAllDelivered` timing: the sender sees two ticks shortly after the receiver opens the app | pending |
| 15 | 375 px: no overflow on the inbox, conversation, request panel and voice composer (also in French) | pending |
| 16 | The web 5a device pass is still outstanding (separate item) | pending |

## Phase 5c device pass (guide, coach marks, avatar upload, support chat)

Run on a real Android device against the **staging** web (never production). Test accounts use the `zzqa_` prefix.

| # | Check | Result |
|---|---|---|
| 1 | Quest steps flip as each real step completes (profile, first tournament entry, first completed match) | PARTIAL 2026-10-07: profile step flips to done after avatar upload (it needs username + avatar, not bio); tournament and match steps not yet tested |
| 2 | Claim once: a second tap or a retry shows "Badge earned"; XP and coins change exactly once | pending |
| 3 | Avatar upload with a GPS-tagged photo: open the uploaded file's URL and confirm it carries no EXIF; the avatar updates after saving | PASS 2026-10-07: phone-camera photo with location on; stored file is 400x400 JPEG, no EXIF/GPS/XMP (only an ICC colour profile); step ticked after save |
| 4 | Chat signed in: a wallet question shows the correct balance; streaming looks smooth | PARTIAL 2026-10-07: owner reports the signed-in chat worked well; wallet-balance accuracy and streaming smoothness not separately confirmed |
| 5 | Chat: background the app mid-reply, return, tap Retry (one answer, no duplicate bubble); airplane mode mid-reply, then Retry | pending |
| 6 | Chat: rapid sends show the rate-limit message with a countdown; Retry enables when it ends | pending |
| 7 | Chat: Clear chat asks first, then empties; the 30-day notice is shown | pending |
| 8 | Chat signed out: an FAQ answer works, no account data is offered, nothing is saved, the notice says so, "busy" copy asks to sign in | pending |
| 9 | Coach marks: first launch shows them, Skip and system Back dismiss and do not return, "Replay the tour" restarts them; TalkBack announces each step | pending |
| 10 | The equipped bubble skin shows on the guide button; the default mascot shows when none is equipped or signed out | pending |
| 11 | French locale: guide, tour, coach marks, chat and error copy; 375 px with no overflow | pending |
| 12 | The **eval** result from the web plan (Task 14) | pending |
| 13 | Streaming over Vercel on a real mobile network (buffering would show as one burst at the end) | pending |
