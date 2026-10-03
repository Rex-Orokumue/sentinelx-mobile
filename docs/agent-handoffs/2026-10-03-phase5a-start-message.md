# Start message — Phase 5a (Notifications & push): web plan → web build → mobile plan → mobile build

Paste everything below the line into a fresh session. Stage B belongs in the web repo
(`C:\Users\gorok\Videos\sentinelx`); Stages C and D belong in the mobile repo
(`C:\Users\gorok\sentinelx_mobile`). If your harness can't work across two repo roots in one session,
split at the Stage B → C boundary and hand off with written notes — don't skip reading them on the mobile
side.

---

You are taking **Phase 5a of the Sentinel X Flutter app — Notifications & push** from an *approved design
spec* to a merged, working feature. The design is done and approved by the owner (2026-10-03); **do not
re-open it**. If you find something in it that is wrong, stop and report it as a deviation request — don't
quietly redesign. You are doing three stages in order, with two mandatory stop-and-report checkpoints.

Phase 5 was split by the owner into **5a Notifications & push → 5b Direct messages → 5c Guide quests &
support chatbot**. This message is **5a only**. DMs, DM push, the messages inbox, guide and chatbot are
*not* in scope.

## Read first

1. Mobile repo `CLAUDE.md` and `AGENTS.md` — they bind you. **Correction to their wording:** a staging
   database *does* exist — `sentinelx-staging` (`ofxmoxpvwbemfouaowoa`), behind the web repo's staging
   preview deployment. Production is `itxubrkbropttfdackmi`. Never test writes against production, in
   either repo.
2. **The approved spec** (web repo, on `main`, commit `b3cae26`):
   `docs/superpowers/specs/2026-10-03-mobile-phase5a-notifications-push-design.md`. It holds the ground
   truth table, every Ruling (with cost-if-wrong), the endpoint table, the sender change, the channel
   table, the permission and cold-start rules, the test list and the open items. Read all of it.
3. Mobile master spec §6.2 (push), §6.3 (realtime), §8.11 (notifications), and web
   `docs/superpowers/specs/2026-09-18-mobile-api-v1-conventions.md` (read before adding any endpoint).
4. The existing web code the spec cites: `lib/notifications/{fcm,push,push-types,mutes,mute-actions,
   inbox,copy,test-push}.ts`, `lib/settings/notification-prefs.ts`,
   `lib/mobile-api/endpoints/devices.ts` (+ its test, as the pattern to copy), migrations `062`, `066`,
   `082`, `20260918210000_fcm_tokens_platform`.
5. The existing mobile code: `lib/core/notifications/unread_counts.dart`,
   `lib/shared/widgets/sx_tab_app_bar.dart` (the bell and messages icons already exist, wired to the
   coming-soon screen), `lib/core/routing/web_links.dart`, `lib/router/app_router.dart`,
   `lib/core/providers.dart`, `lib/core/auth/` (session/onboarding gate).
6. Style templates: web spec/plan pair for Phase 4 (`2026-09-27-mobile-phase4-community-design.md`) and the
   mobile plan it produced, `docs/superpowers/plans/2026-09-28-mobile-phase4-community-screens.md`
   (Global Constraints, Review Focus, Coordination, numbered Tasks, ARB en+fr). Also read
   `docs/agent-handoffs/2026-10-03-mobile-phase4-stage-d-handoff.md` — especially its **code-review
   table** and **process notes**; the bugs listed there are the ones this phase is most likely to
   reintroduce (see "Lessons" below).

## Stage B — Web: plan, then build (web repo)

Use a **separate git worktree off `origin/main`** for this work (`git worktree add`), not the checkout at
`C:\Users\gorok\Videos\sentinelx`, which has the owner's untracked files and concurrent sessions. Verify
the branch and `git diff --cached` before every commit.

1. **Write the web implementation plan** with the `superpowers:writing-plans` skill:
   `docs/superpowers/plans/2026-10-0X-mobile-phase5a-notifications-push-web.md`. Cover, as numbered TDD
   tasks: `effectivePrefs()` shared by the sender gate and the endpoints; the sender platform partition
   (`sendToTokens` must read `platform`; web payload **byte-for-byte unchanged**, android with
   `notification` + high priority + versioned channel id, ios alert shape only; `broadcastFCM` and
   `broadcastPush` too); the type → channel table with the completeness/uniqueness test; the 8 endpoints in
   spec §4 as `defineEndpoint`s with their route files; the `openapi/mobile-v1.json` regeneration.
2. **Resolve the spec's open items that live on the web side** and record the answers as Rulings:
   the WhatsApp/achievement-sharing defaults for `effectivePrefs` (read `notify.ts`); each push type's real
   recipient at its call site to finalise the staff-bound channel assignments; whether `data` should
   carry the `player_notifications` row id (spec open item 3 — if it requires touching many call sites,
   say so and propose the smallest option rather than deciding silently).
3. **No schema change is expected** — `notification_mutes`, `fcm_tokens.platform`, the realtime
   publication and the prefs RPC all exist. If you find one is needed, stop and ask.
4. TDD every endpoint (mirror `devices.test.ts` and the Phase 4 `community-*.test.ts` patterns). Run the
   web repo's full verification (typecheck, lint, test, build). Never test writes against production.
5. Get it reviewed by a **fresh-context review pass**, fix findings, re-verify.

**Checkpoint 1 — stop here.** Report: what was built, review findings and fixes, verification output,
the answers to the open items above. Wait for the owner before merging. After confirmation, merge and
push to web `main` (no PR, standing preference) and confirm the staging preview deployment picks it up.

## Stage C — Mobile plan (mobile repo, only after Stage B is on web `main`)

Copy the web repo's regenerated `openapi/mobile-v1.json` over this repo's `api/openapi.json` (copy, never
hand-edit — see `AGENTS.md` rule 3). Then write
`docs/superpowers/plans/2026-10-0X-mobile-phase5a-notifications-push-screens.md` with
`superpowers:writing-plans`, in the Phase 4 plan's structure. It must cover: models and `ApiClient`
methods (each in `usedOperations`); the bell screen at `/notifications` (paging, mark read, read-all,
mute menu, unknown types, empty state with the permission row); Settings → Notifications (17 + 6 + 5
toggles with the optimistic-rollback rule, test-notification action, system-permission row); the push
service (permission, channels, registration lifecycle, foreground banner, tap resolver with the
cold-start queue, unmappable-link fallback); router and `resolveWebLink` additions; ARB en + fr with
identical keys and ICU plurals; the full test list per screen (empty/error/signed-out, rollback, API
gate, once-only prompt, all three prompt triggers, sign-out failure, foreground/background/terminated
taps). Resolve the remaining open items **in the plan**, with evidence: which package owns the Android 13+
permission dialog *at the exact versions you pin*; Gradle/AGP compatibility for the `google-services`
plugin.

### Two build traps the plan must handle explicitly
- **A missing `google-services.json` breaks the Android build** (the plugin fails the task). The owner
  will add the file, but until then — and in CI and tests — the app must still build, boot and pass
  tests. Decide and document one approach (e.g. apply the plugin only when the file exists) and test the
  no-file path with `flutter build apk --debug`.
- **Firebase init must be failure-tolerant.** If `Firebase.initializeApp()` throws (no config, iOS with no
  plist, tests), the app starts normally with push disabled — never a crash at launch. Push code sits
  behind an interface so tests use fakes and never touch Firebase.

## Stage D — Mobile build (mobile repo)

New worktree off current mobile `master`: `git worktree add ..\sentinelx_mobile-p5a -b phase5a/screens`
(there are no other worktrees now; all earlier ones were removed 2026-10-03). Strict TDD: failing test
first, watch it fail for the right reason, minimal code, green, repeat. `flutter analyze` clean and
`flutter test` passing before every commit; run `git checkout -- linux macos windows` after `flutter pub
get` / `flutter test` and before committing. Shared hotspot files (`api_client.dart`, `app_router.dart`,
`web_links.dart`, ARB + generated l10n, `home_screen.dart`) get minimal, append-only hunks — never
reformat existing code. Get a fresh-context review pass (`/code-review`), fix findings, re-verify.

**Final checkpoint.** Report: branch + HEAD, test counts, review findings and fixes, every Ruling, what's
deferred, what is **not** verified. Then merge to mobile `master` and push immediately, no PR — only after
review and green.

## Lessons from the Phase 4 review — each of these bit us once

1. **Viewer-specific reads need the bearer token.** `publicRequest: true` strips it; the web handlers that
   read the optional caller identity then return the anonymous answer. Add a test per authenticated read
   that the `Authorization` header is present. Fakes can't catch this.
2. **`StreamProvider<void>` notifies once.** Every `null` equals the last. Realtime providers must emit
   distinct values (a counter). Test with two consecutive events.
3. **Providers that return caller-specific data must watch the viewer** (`communityViewerIdProvider`
   pattern: user id, not token) so login/logout refetches and a token refresh does not.
4. **Optimistic rollback reverts only your own change on the current value** — never restores a
   tap-time snapshot over fresher data — and must not use a disposed widget's `ref`/`context` after an
   `await` (resolve the notifier at build time; make notifier mutators no-ops when unmounted).
5. **Background refresh must not reset pagination or race a manual action.** Re-read the loaded window in
   place; serialise refresh and load-more.
6. **Tolerant parsing:** an unrecognised enum value from a newer server (notification `type`!) must
   degrade (generic title/body/link), never fail the whole list.
7. **Plurals:** counts use ICU plural in en and fr from the start ("1 notification", not "1
   notifications").
8. **A link-resolution function used as a router redirect runs on every location.** Make sure a new
   mapping can't swallow an in-app path (see `resolveWebLink`'s community rule and its tests).
9. **Windows encoding hazard:** never edit source with bare `open(p).read()/write()` in Python — cp1252
   corrupts non-ASCII and the analyzer then reports "URI doesn't exist". Use the Edit/Write tools or
   `encoding='utf-8', newline=''`. If analyze reports missing URIs for files that exist, scan changed files
   for invalid UTF-8 before suspecting a cache.
10. **Verify a reviewer's claim before acting** — one Phase 4 finding (pop on an empty stack) was a false
    positive and a test settled it.

## Hard rules throughout

- Never test writes against production. The staging database and preview deployment are for write-path
  work; the app's defaults point at production, so running against staging needs `--dart-define` of
  `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` and `API_BASE_URL` (no committed staging config exists —
  adding a git-ignored or documented example is welcome, committing keys is not).
- No copy hard-coded in widgets: ARB en + fr, then `flutter gen-l10n`; commit the generated output.
- All writes and all TypeScript-computed reads go through `/api/mobile/v1`; never write via PostgREST.
  The bell's row reads and unread count are the spec's one deliberate exception (owner-RLS + realtime).
- Don't delete or reset anything in either repo without asking. Don't push the web checkout at
  `C:\Users\gorok\Videos\sentinelx` directly — use your worktree.
- Log every deviation from the spec or plan as a **Ruling** (what, why, cost if wrong); don't deviate
  silently.
- Write a handoff note per stage in the relevant repo's `docs/agent-handoffs/` (dated, descriptive name;
  separate verified facts from recommendations; record verification limits and whether code changed).

## Owner-side prerequisite (not yours)

For live push the owner registers the Android app `ng.com.sentinelxesports.app` in the **web's existing
Firebase project** and places `google-services.json` in `android/app`. Do not create a Firebase project
and do not ask for the file before the plan needs it. Until it exists, everything is built and tested
against fakes and the live exit criteria stay explicitly *unverified* in your reports. The owner runs the
device pass on staging afterwards: test push in foreground, background and terminated; tap routing from
each including a cold start while signed in; an account switch on one phone; a real fixture assignment.
