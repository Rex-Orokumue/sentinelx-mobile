# Start message — Phase 2b (Flutter) in a new session

Paste everything below the line into a fresh Codex or Claude Code session opened in `C:\Users\gorok\sentinelx_mobile`.

---

You are building **Phase 2b of the Sentinel X Flutter app** (bracket, Match Centre, check-in, result submission with a screenshot, opponent rating, wagering, lobby results, dashboard fixtures card). A complete implementation plan already exists — your job is to execute it exactly, not to redesign it.

**Read first, in this order**
1. `C:\Users\gorok\sentinelx_mobile\CLAUDE.md` and `AGENTS.md` (repo rules; they bind you).
2. The plan: `docs/superpowers/plans/2026-09-26-mobile-phase2b-flutter-screens.md` — Global Constraints, Review Focus, Coordination, then Tasks 0–11.
3. The spec it implements (web repo, `C:\Users\gorok\Videos\sentinelx`): `docs/superpowers/specs/2026-09-23-mobile-phase2b-compete-core-design.md`, and the endpoint definitions in `lib/mobile-api/endpoints/` (`bracket.ts`, `standings.ts`, `results.ts`, `match-centre.ts`, `check-in.ts`, `match-result.ts`, `rating.ts`, `wager.ts`, `squads.ts`, `lobby-result.ts`, `summary.ts`) on branch `docs/mobile-phase1-phase2a-specs`.
4. `docs/agent-handoffs/2026-09-26-mobile-phase2a-flutter-notes.md` (what 2a built, its open items), `2026-09-26-integration-and-3a-review.md` (how the integration branch was made, the 3a review), and `2026-09-25-mobile-phase3b-flutter-session-notes.md` (staging setup).

**Where to work**
- **Base your work on the integration branch `integration/2a-3a-3b`** (worktree `C:\Users\gorok\sentinelx_mobile-integration`): it already contains Phases 2a, 3a and the 3b Flutter commits merged locally (analyze clean, 368 tests). Task 0 creates your own worktree `..\sentinelx_mobile-p2b` on a new branch `phase2b/screens` cut from it. **Never commit to the integration branch directly, and do not work in, delete, or reset the other worktrees** (`-p2a`, `-p3a`, `-p3b`, `-integration`, `-auth-hardening`).
- **`api/openapi.json` on that base is a hand-built UNION** of several unmerged web branches (46 operations). **Do not overwrite it with a single web file** — that would drop the 3a/3b operations. Task 0 only verifies that the twelve 2b operations are present; if one is missing, stop and report.
- **Another session is fixing Phase 3a's review findings in parallel** (`sentinelx_mobile-p3a`, branch `phase3a/screens`); those fixes get merged into the integration branch later. You share these hotspots with it: `lib/core/api/api_client.dart`, `lib/router/app_router.dart`, `lib/core/routing/web_links.dart`, the ARB files + generated l10n, `lib/features/home/home_screen.dart`. Edit them **append-only with minimal hunks**, never reformat or rewrap existing code (the 3a branch did once and it cost a hand-resolved merge), and regenerate l10n after any rebase.

**How to work**
- Strict TDD: write the failing test, **run it and read the failure**, then the minimal code, then run it green. Every task ends with `flutter analyze` (no issues) and `flutter test` (all pass), then the plan's commit step. After `flutter pub get`/`flutter test`, run `git checkout -- linux macos windows` before committing.
- Follow the plan's Interfaces blocks for names and signatures. If the plan is wrong or contradicts the spec, make the smallest change that satisfies the spec and log it as a **Ruling** (what, why, cost if wrong) in your running log at `docs/agent-handoffs/2026-09-26-mobile-phase2b-flutter-notes.md`. Do not deviate silently.
- The plan is the spec-argued design; two rules are easy to get wrong: (a) the **Idempotency-Key policy** (reuse a key only after `network` / `idempotency_in_progress` / `bad_response`, mint a new one after any other error) is implemented once in `WriteFlow` (Task 3) — don't re-implement it per screen; (b) **never show an optimistic result** — a submitted result is only "awaiting confirmation".

**Hard rules (do not break)**
- The Supabase project `itxubrkbropttfdackmi` is PRODUCTION and there is no dev DB. **Never test writes against production** (check-in, result, rating, wager, lobby result, screenshot upload are all writes). Device/manual runs use staging (`ofxmoxpvwbemfouaowoa`) with dart-defines; `config/dev.json` alone points at production.
- Writes go only through `/api/mobile/v1/*` — never PostgREST. The single sanctioned exception is the screenshot upload to the private Storage bucket `match-evidence` (plan Global Constraints).
- No copy hard-coded in widgets; ARB en+fr (identical key sets), then `flutter gen-l10n`. No secrets in files you write.
- **Do not push, open a PR, or merge anything** without the owner's explicit OK. The web endpoints this phase needs are on an unmerged web branch, so nothing can run against a real server yet — report that honestly.
- Do not add squad UI (out of scope, see plan). Do not touch Phase 3a/3b code except the append-only hotspots above.

**Report back after each task** (one short block): commit hash, exact `flutter analyze` / `flutter test` result, any Ruling, anything surprising. When Task 11 is done, list: branch + HEAD, test counts, every deviation, the deferred items, and what is **not** verified (live-server behavior, the screenshot upload, the device checklist).

Start with Task 0. If Task 0's base check fails (2a is neither merged nor present), stop and tell me instead of improvising.
