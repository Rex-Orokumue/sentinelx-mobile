# Mobile Phase 2b (Flutter) — Bracket, Match Centre, Check-in, Results, Rating, Wager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. (No superpowers skills available, e.g. Codex? Follow the steps in order yourself: failing test first, watch it fail, minimal code, watch it pass, commit; keep a running log in `docs/agent-handoffs/`.)

**Goal:** Finish the Compete loop in the Flutter app: tournament bracket / group standings / champion, Match Centre (check-in, submit result with a screenshot, rate opponent, wager), lobby-result submission for points-race formats, and the dashboard "next fixture" card — backed by the twelve Phase 2b web endpoints, and retire the temporary Supabase-direct tournaments slice.

**Architecture:** Same shape as Phases 1/2a/3b. Hand-written `ApiClient` methods + plain-Dart models with `fromJson`; T1 reads (one match row, tournament stages) through one small Supabase repository with explicit columns; **every write goes through `/api/mobile/v1/*`** except the evidence screenshot upload (see Global Constraints). All five idempotent writes share ONE generic `WriteFlow` notifier that owns the Idempotency-Key policy, so the policy is implemented and tested once. Screens are `ConsumerWidget`s reading Riverpod providers. New code lives in `lib/features/match/` and `lib/features/bracket/`.

**Tech Stack:** Flutter (stable), Dart ^3.11, `flutter_riverpod` ^3.3 (manual providers), `go_router` ^17, `dio`, `supabase_flutter`, `url_launcher`, `flutter_test`. **One new dependency: `image_picker`.**

**Spec:** web repo (`C:\Users\gorok\Videos\sentinelx`) `docs/superpowers/specs/2026-09-23-mobile-phase2b-compete-core-design.md` (§1, §4–§8 binding) and `2026-09-22-mobile-phase2a-tournaments-registration-design.md` (§4 idempotency). Wire shapes are defined by `lib/mobile-api/endpoints/{bracket,standings,results,match-centre,check-in,match-result,rating,wager,squads,lobby-result,summary}.ts` on the web branch `docs/mobile-phase1-phase2a-specs` (not yet on `main`); Task 1's models match them field-for-field. Master spec: `docs/superpowers/specs/2026-09-18-flutter-mobile-app-master-design.md` §8.3–§8.6, §13. **Read this repo's `CLAUDE.md` and `AGENTS.md` first.** Phase 2a plan (already built): `docs/superpowers/plans/2026-09-26-mobile-phase2a-flutter-screens.md`.

## Global Constraints

- **Writes only through `ApiClient`** (`/api/mobile/v1/*`). Never write via PostgREST. **One sanctioned exception, stated in the spec's web equivalent:** the result/lobby screenshot is uploaded straight to the private Supabase Storage bucket `match-evidence` at path `{userId}/{matchId or lobbyId}/{epochMs}-{safeName}` — the bucket policy only allows a user's own `{uid}/…` folder, the API then receives just the path. This is a Storage write, not PostgREST, and mirrors the website exactly. Ledger it as a ruling in the PR.
- **Reads:** the bracket, standings, champion, match centre, and dashboard summary come from the API. Only two things are direct Supabase reads (T1, explicit columns, never `*`): the match row (names, score, stream URL — the centre endpoint returns none of these) and a tournament's stages (`tournament_stages` is public-read). Never read `profiles` beyond `username, display_name`.
- **Every new `ApiClient` method is listed in `ApiClient.usedOperations`** and checked against `api/openapi.json` by `test/core/api_contract_test.dart`. `api/openapi.json` normally is a **copy** of the web repo's `openapi/mobile-v1.json` — copy it, never hand-edit. **On the integration base (Task 0) it is an integration-only UNION** of several unmerged web branches (no single web file has every operation): **never overwrite it from one web file** (that would drop the 3a/3b operations); only verify that the twelve 2b operations are present. The real contract is regenerated later from the merged web repo.
- **Idempotency-Key policy (exact):** `POST /matches/{id}/result`, `/matches/{id}/rating`, `/matches/{id}/wager`, `/lobbies/{id}/result`, `/squads` require the header. One key per *attempt*; **reuse it only** when the previous outcome was `ApiException.code` `network`, `idempotency_in_progress` (409) or `bad_response` (a reply with no error envelope — the server may have processed it); after **any other** error response the next attempt **must mint a new key** (the server replays a stored error for the same key forever). A success clears the key. Two rapid taps send one request. `POST /matches/{id}/check-in` takes no key.
- **The app never shows an optimistic result.** Submitting a result creates a *pending* result only; show "submitted — awaiting confirmation". A win/loss/score is displayed only from a server value.
- **Copy is never hard-coded in widgets.** Add keys to `lib/core/l10n/app_en.arb` **and** `app_fr.arb` (`test/core/l10n_test.dart` requires identical key sets), run `flutter gen-l10n`, never edit `lib/core/l10n/gen/*`. Server `error.message` strings are English and are **never shown**: map `error.code` to ARB copy (Task 2's `matchErrorCopy`), falling back to a generic message. Round labels (`quarter_final` …) come from the API's `label` fields, not from Dart.
- **No Dart copy of server logic.** Never recompute standings, ranks, advancement, wager payout, check-in verdicts or `canCheckIn`; render what the API returns. The wager estimate is displayed exactly as returned.
- **Squads:** the register endpoint still rejects `squadId` (`squads_not_available`), so the squad *screens* are **out of scope** here; Task 1 adds only the two client methods + models so the contract is covered. Do not add squad UI.
- **Mobile-first at 375px**, no horizontal overflow (long names, 60-char club names, 5+ knockout rounds). `SxColors` only; no new colors. American spelling.
- **Testing against production is forbidden; check-in, result, rating and wager are writes and wager spends coins.** Device runs use the staging project only (`docs/agent-handoffs/2026-09-25-mobile-phase3b-flutter-session-notes.md` has the launch command). `config/dev.json` alone points at PRODUCTION.
- **Before every commit:** `flutter analyze` (no issues) and `flutter test` (all pass). Regenerate l10n after ARB edits and commit the generated output. After `flutter pub get`/`flutter test` run `git checkout -- linux macos windows` before committing.

## Review Focus

Failure modes the spec implies that are easy to ship broken, most likely first. Each has a test in the task that owns the code.

1. **Double submit / key loss on the money-adjacent writes** (result, rating, wager, lobby result): retry after a network drop reuses the key; retry after any real server error mints a new one; two rapid taps send one request; a gateway/HTML reply keeps the key. (Task 3)
2. **Upload succeeded, POST failed**: retrying must not upload the screenshot a second time and must not lose the picked image. A failed *upload* must say so (not "network") and send nothing. (Task 4)
3. **Never claim an outcome the server did not give**: after submit show "awaiting confirmation"; the score line and "you won" style text appear only from confirmed data; a `disputed`/`forfeited`/`cancelled`/`bye` match renders its own state, not a blank. (Tasks 6, 7)
4. **Signed-out and non-participant users**: the Match Centre is public; a guest sees no check-in/submit/rate controls and the wager card asks to log in; a participant never sees the wager card (`own_match`); a non-participant never sees submit/rate. (Task 6)
5. **Odd data**: a bracket with only groups, only knockout, neither (draw not made), a `null` champion with `noWinner`, a bye (score null), 0 fixtures in a split, a 60-char team name, a live/completed match with null scores. (Tasks 5, 6)

## Coordination (shared-file hotspots)

- **Base: the integration branch `integration/2a-3a-3b`** (worktree `C:\Users\gorok\sentinelx_mobile-integration`), which already contains Phase 2a, Phase 3a and the Phase 3b Flutter commits merged locally (analyze clean, **368 tests**). Phase 2b reuses 2a's `newIdempotencyKey`, `lib/features/compete/*`, l10n keys and router, and shares hotspots with 3a/3b, so one trunk with everything merged avoids a three-way rebase. Build on a new branch `phase2b/screens` cut from it (Task 0). If `master` has since absorbed those phases (check `git log master --oneline | findstr /i "integration"`), base on `master` instead.
- **A parallel session is fixing Phase 3a's review findings** on branch `phase3a/screens` (worktree `sentinelx_mobile-p3a`). Those fixes will be merged into the integration branch later. Hotspots you share with it and with the merged phases: `lib/core/api/api_client.dart` (append methods and `usedOperations` lines only), `api/openapi.json` (see the union rule above), `lib/router/app_router.dart` (add routes only), `lib/core/routing/web_links.dart` (add cases only), ARB files + generated l10n (regenerate after any rebase), `home_screen.dart` (one widget line). **Never rewrite or reformat those files** — the 3a branch already reformatted whole shared files once and it cost a hand-resolved merge; keep every hunk minimal and match the surrounding style.
- Do **not** delete or modify the other worktrees (`-p3a`, `-p3b`, `-p2a`, `-integration`); `-integration` is the base, never commit to it directly.

## Deferred / known gaps (record in the PR, do not build)

- Squad create/lookup **screens** (server still rejects `squadId` on register).
- The no-show flag (`noShowEligible`) is displayed as information only; there is no player-facing no-show endpoint in 2b.
- Evidence screenshot **preview of an earlier submission**, and editing a submitted result: the app requires a fresh screenshot on every submit (the server would accept an empty path only when it already holds one; the app cannot know).
- Realtime updates of the Match Centre; pull-to-refresh is the refresh mechanism.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/api/match_models.dart` (create) | `NameRef`, `StandingRow`, `GroupStandings`, `BracketFixture`, `FixtureSplit`, `KnockoutRound`, `ProjectedRound`, `BracketView`, `PointsStandingRow`, `ChampionEntry`, `TournamentResults`, `WagerInfo`, `CheckInVerdict`, `MatchCentre`, `SquadPreview`, `CreatedSquad`, `MeSummary` (+ `NextMatch`, `NextLobby`, `SummaryRegistration`, `SummaryBanner`) — `fromJson` only |
| `lib/core/api/api_client.dart` (modify) | 12 methods + `usedOperations` lines (append) |
| `lib/core/utils/write_flow.dart` (create) | `WriteFlow` generic idempotent-write notifier (+ `WriteState`, `writeFlowProvider`) |
| `lib/features/match/evidence.dart` (create) | `PickedImage`, `evidencePath()`, `EvidenceUploader` + Supabase impl, `ImagePickerPort` + plugin impl, providers, `ResultSubmitter` (upload-once memo) |
| `lib/features/match/match_reads_repository.dart` (create) | `MatchInfo`, `StageInfo`, `MatchReadsRepository` + Supabase impl |
| `lib/features/match/match_repository.dart` (create) | Thin fake-able wrapper over the API calls used by the match screens |
| `lib/features/match/match_providers.dart` (create) | `matchInfoProvider`, `matchCentreProvider`, `bracketProvider`, `stagesProvider`, `stageStandingsProvider`, `tournamentResultsProvider`, `meSummaryProvider` |
| `lib/features/match/match_error_copy.dart` (create) | `matchErrorCopy(l10n, code)` |
| `lib/features/bracket/bracket_screen.dart` (create) | Groups / Fixtures / Knockout view + champion banner |
| `lib/features/bracket/stage_standings_screen.dart` (create) | Points-race stage table |
| `lib/features/match/match_centre_screen.dart` (create) | Composed Match Centre |
| `lib/features/match/result_submission_screen.dart` (create) | Score + screenshot + optional recording URL |
| `lib/features/match/lobby_result_screen.dart` (create) | Placement + kills + screenshot |
| `lib/features/match/rating_sheet.dart`, `wager_sheet.dart` (create) | Bottom sheets |
| `lib/features/match/fixtures_card.dart` (create) | Dashboard "next fixture" card for Home |
| `lib/features/compete/compete_detail_screen.dart` (modify) | Champion card when completed (Task 5) |
| `lib/core/l10n/app_en.arb`, `app_fr.arb` (modify) | New keys (Task 2) |
| `lib/router/app_router.dart` (modify) | Routes (Task 10) |
| `lib/core/routing/web_links.dart` (modify) | `/matches/<id>` |
| `lib/features/home/home_screen.dart` (modify) | One `FixturesCard` line |
| Retired in Task 10 | `lib/data/*`, `lib/models/*`, `lib/features/tournaments/*`, `test/fakes/fake_tournaments_repository.dart`, `test/features/bracket_screen_test.dart` |
| `test/…` beside each | See tasks; shared fixtures in `test/support/match_fixtures.dart` |

---

### Task 0: Worktree, base, contract, dependency, live-schema check

**Files:** `api/openapi.json`, `pubspec.yaml`.

- [ ] **Step 1: Pick the base and create the worktree**

```bash
cd C:\Users\gorok\sentinelx_mobile
git branch --list "integration/2a-3a-3b"
git log integration/2a-3a-3b --oneline -3
```
- If branch `integration/2a-3a-3b` exists → base on it.
- Else if `master` already contains the 2a, 3a and 3b work → base on `master`.
- Else **stop and report**: 2b cannot start without 2a's idempotency util and `compete` feature folder.

```bash
git worktree add ..\sentinelx_mobile-p2b -b phase2b/screens integration/2a-3a-3b
cd ..\sentinelx_mobile-p2b
flutter pub get
flutter analyze && flutter test
```
Expected: clean and green (**368 tests** on the integration base). If red, stop and report; do not build on a red base.

- [ ] **Step 2: Confirm the pieces this plan consumes from 2a**

```bash
findstr /c:"String newIdempotencyKey" lib\core\utils\idempotency_key.dart
findstr /c:"headers" lib\core\api\api_client.dart
findstr /c:"class CompeteTournament" lib\features\compete\compete_models.dart
findstr /c:"cmpEcGeneric" lib\core\l10n\app_en.arb
findstr /c:"competeBaseOverrides" test\support\pump_compete.dart
findstr /c:"_withQuery" lib\core\api\api_client.dart
```
Each must print a match (`_withQuery` comes from the 3a/3b work on this base). If a name differs, use the real one everywhere this plan says it.

- [ ] **Step 3: Copy the contract**

**Do NOT copy a web file over `api/openapi.json` on this base.** It is an integration-only union (web `phase3b/web-endpoints` contract + 3a's five operations, 46 operations) and no single web branch has all of them; overwriting it would drop operations the merged app already uses. Only verify:

```bash
findstr /c:"getTournamentBracket" /c:"getTournamentStandings" /c:"getTournamentResults" /c:"getMatchCentre" /c:"postMatchCheckIn" /c:"postMatchResult" /c:"postMatchRating" /c:"postMatchWager" /c:"postSquads" /c:"getSquadLookup" /c:"postLobbyResult" /c:"getMeSummary" api\openapi.json
```
All twelve must match (they do on the integration base — they come from the web docs-branch contract). If any is missing, **stop and report** rather than copying. If you are instead on a `master` that has a real regenerated contract, then a fresh copy from the merged web repo is fine.

- [ ] **Step 4: Add the image picker**

```bash
flutter pub add image_picker
flutter pub get
flutter analyze
```
Android needs no manifest change for gallery picking via the system picker; iOS needs `NSPhotoLibraryUsageDescription` in `ios/Runner/Info.plist` (add it: "Choose a screenshot of your match result.") — iOS is Phase 10, but adding the key now is harmless. Commit `pubspec.*` with Task 1.

- [ ] **Step 5: Live schema check (read-only, staging project `ofxmoxpvwbemfouaowoa` only)**

Supabase MCP `execute_sql`:

```sql
select table_name, count(*) as cols from information_schema.columns
 where table_schema='public' and (
   (table_name='matches' and column_name in ('id','tournament_id','round','status','score_a','score_b','scheduled_at','is_full_day','youtube_stream_url','replay_url','player_a_id','player_b_id','team_a_id','team_b_id'))
   or (table_name='tournament_stages' and column_name in ('id','tournament_id','seq','name','status'))
   or (table_name='tournaments' and column_name in ('id','title','slug')))
 group by table_name order by table_name;
```
Expected: `matches` 14, `tournament_stages` 5, `tournaments` 3. Also confirm the bucket: `select id, public from storage.buckets where id='match-evidence';` → one row, `public = false`. Any mismatch: stop and fix Task 3's column list / report the missing bucket.

---

### Task 1: Contract models and client methods

**Files:**
- Create: `lib/core/api/match_models.dart`, `test/core/match_models_test.dart`, `test/core/api_client_match_test.dart`, `test/support/match_fixtures.dart`
- Modify: `lib/core/api/api_client.dart`

**Interfaces:**
- Produces (all in `match_models.dart`, every class has `factory X.fromJson(Map<String, dynamic> j)`; field names below are the Dart names, the JSON keys are exactly those of the zod schemas quoted in the spec files):

```dart
class NameRef { final String id; final String name; }
class StandingRow { String playerId; String name; String? clubName; int played, wins, draws, losses, goalsFor, goalsAgainst, goalDiff, points, rank; bool advancing; }
class GroupStandings { String groupId; String groupName; List<StandingRow> rows; }
class BracketFixture { String id; String round; String? groupId; String? groupName; String status; int? scoreA; int? scoreB; String? scheduledAt; bool isFullDay; NameRef playerA; NameRef playerB; }   // JSON keys group_id, score_a, score_b, scheduled_at, is_full_day, playerA, playerB, groupName
class FixtureSplit { List<BracketFixture> live, upcoming, completed, disputedOrCancelled; }
class KnockoutRound { String round; String label; List<BracketFixture> matches; }
class ProjectedRound { String round; String label; int matchCount; }
class BracketView { List<GroupStandings> standings; FixtureSplit fixtures; List<KnockoutRound> rounds; List<ProjectedRound> projected; NameRef? champion; NameRef? thirdPlace; BracketFixture? thirdPlaceMatch; bool hasGroups; bool hasKnockout; }
class PointsStandingRow { String entrantId; String displayName; int played, totalPoints, totalKills; int? bestPlacement, lastRoundPlacement; int rank; bool advancing; List<String> unresolvedTieWith; }
class ChampionEntry { String tournamentId, slug, title, tournamentType, gameId, gameName; String? date; int? prizePool; NameRef champion; NameRef? runnerUp; String? championAvatarUrl; String? seasonName; }
class TournamentResults { ChampionEntry? champion; bool noWinner; }
enum CheckInVerdict { both, one, none }
class WagerInfo { bool windowOpen; int poolA, poolB; double feeRate; int minStake, maxStake; String? myPickPlayerId; int? myStakeCoins; num estimatedPayoutIfIStakeA100; }   // JSON pools: {playerA, playerB}
class MatchCentre { String matchId; String status; String? scheduledAt; bool isFullDay, isParticipant, canCheckIn; List<String> checkedInPlayerIds; CheckInVerdict checkInVerdict; String? soleAttendeeId; WagerInfo wager; bool noShowEligible; }
class SquadPreview { String id, name; int memberCount, teamSize; }
class CreatedSquad { String squadId; String inviteCode; }
class MeSummary { NextMatch? nextMatch; NextLobby? nextLobby; bool hasSubmittableMatch; List<SummaryRegistration> registrations; List<SummaryBanner> banners; }
class NextMatch { String id, status, round; String? scheduledAt; bool isFullDay; String tournamentTitle; }
class NextLobby { String lobbyId, tournamentTitle, stageName; int roundNo; String label; String? scheduledAt; bool hasRoomCode, submitted; }
class SummaryRegistration { String id, paymentStatus, tournamentTitle, tournamentSlug; }
enum BannerKind { qualified, eliminated }
class SummaryBanner { BannerKind kind; String tournamentTitle, tournamentSlug, round; bool awaitingOpponent; }   // awaitingOpponent only for `qualified`, else false
// ApiClient (all await the standard `_send`; idempotent ones take `required String idempotencyKey` → header `Idempotency-Key`):
Future<BracketView> getTournamentBracket(String tournamentId);
Future<List<PointsStandingRow>> getTournamentStandings(String tournamentId, String stageId);      // GET /tournaments/{id}/standings?stage=
Future<TournamentResults> getTournamentResults(String tournamentId);
Future<MatchCentre> getMatchCentre(String matchId);
Future<void> postMatchCheckIn(String matchId);
Future<void> postMatchResult(String matchId, {required int scoreA, required int scoreB, String recordingUrl = '', required String screenshotPath, required String idempotencyKey});
Future<void> postMatchRating(String matchId, {required int stars, required String idempotencyKey});
Future<void> postMatchWager(String matchId, {required String pickPlayerId, required int stakeCoins, required String idempotencyKey});
Future<void> postLobbyResult(String lobbyId, {required int placement, required int kills, required String screenshotPath, required String idempotencyKey});
Future<CreatedSquad> postSquads({required String tournamentId, required String name, required String idempotencyKey});
Future<SquadPreview> getSquadLookup({required String tournamentId, required String code});       // GET /squads/lookup?tournamentId=&code=
Future<MeSummary> getMeSummary();
```
`operationId → 'method /path'` lines to append to `usedOperations`:
`getTournamentBracket: get /api/mobile/v1/tournaments/{id}/bracket`, `getTournamentStandings: get /api/mobile/v1/tournaments/{id}/standings`, `getTournamentResults: get /api/mobile/v1/tournaments/{id}/results`, `getMatchCentre: get /api/mobile/v1/matches/{id}/centre`, `postMatchCheckIn: post /api/mobile/v1/matches/{id}/check-in`, `postMatchResult: post /api/mobile/v1/matches/{id}/result`, `postMatchRating: post /api/mobile/v1/matches/{id}/rating`, `postMatchWager: post /api/mobile/v1/matches/{id}/wager`, `postLobbyResult: post /api/mobile/v1/lobbies/{id}/result`, `postSquads: post /api/mobile/v1/squads`, `getSquadLookup: get /api/mobile/v1/squads/lookup`, `getMeSummary: get /api/mobile/v1/me/summary`.

The web `bracketMatch` schema uses snake_case for `group_id, score_a, score_b, scheduled_at, is_full_day` and camelCase for `groupName, playerA, playerB`; `matchCentre`/`summary` are camelCase. Parse exactly that, do not "normalize".

- [ ] **Step 1: Fixtures** — `test/support/match_fixtures.dart` exports plain `Map<String, dynamic>` builders with defaults for: `fixtureJson({id, status, scoreA, scoreB, groupId, groupName, playerA, playerB, scheduledAt})`, `bracketJson({groups = 1, withKnockout = true, champion})`, `centreJson({isParticipant, canCheckIn, status, windowOpen, myPick, myStake, checkedIn})`, `summaryJson({nextMatch, nextLobby, banners})`. Build them from the shapes above; every later test file uses them.

- [ ] **Step 2: Write the failing model tests** — `test/core/match_models_test.dart`. Cover (each as its own `test`):
  1. `BracketView.fromJson(bracketJson())` parses standings rows (`rank`, `advancing`, nullable `clubName`), all four fixture buckets, rounds with labels, projected rounds, `hasGroups`/`hasKnockout`.
  2. A bye/unplayed fixture: `score_a: null, score_b: null` → `scoreA == null`.
  3. `champion: null, thirdPlace: null, thirdPlaceMatch: null` parse to nulls; a set champion parses to `NameRef`.
  4. `PointsStandingRow` with `bestPlacement: null` and `unresolvedTieWith: ['e2']`.
  5. `TournamentResults` with `champion: null, noWinner: true`; and a full `ChampionEntry` (nullable `runnerUp`, `date`, `prizePool`, `championAvatarUrl`, `seasonName`).
  6. `MatchCentre`: verdict strings `both|one|none` map; unknown verdict throws `FormatException`; `wager.pools` flattens to `poolA/poolB`; `myPickPlayerId`/`myStakeCoins` null.
  7. `MeSummary`: `nextMatch: null`; `banners` with both `qualified` (with `awaitingOpponent`) and `eliminated`; an unknown banner `kind` throws `FormatException`.
  8. `CreatedSquad`, `SquadPreview` parse.

- [ ] **Step 3: Write the failing client tests** — `test/core/api_client_match_test.dart` (copy the `_FakeAdapter`/`_json`/`_client` helpers from `test/core/api_client_compete_test.dart`). Cover:
  - each GET hits the exact path (`/api/mobile/v1/tournaments/t1/bracket`, `.../standings?stage=s1` — assert `options.uri.queryParameters['stage'] == 's1'`, `.../results`, `/matches/m1/centre`, `/me/summary`, `/squads/lookup?tournamentId=t1&code=ABC` with query parameters URL-encoded);
  - `postMatchCheckIn` sends **no** `Idempotency-Key`;
  - `postMatchResult` sends the header and body `{scoreA, scoreB, recordingUrl, screenshotPath}`;
  - `postMatchRating` body `{stars: 4}`, `postMatchWager` body `{pickPlayerId, stakeCoins}`, `postLobbyResult` body `{placement, kills, screenshotPath}`, `postSquads` body `{tournamentId, name}` — all with the header;
  - an error envelope (`{error:{code:'already_rated',message:'x'}}`, 409) throws `ApiException(code:'already_rated', status:409)`.

- [ ] **Step 4: Run to verify failure**

Run: `flutter test test/core/match_models_test.dart test/core/api_client_match_test.dart`
Expected: FAIL (`match_models.dart` not found / methods not defined).

- [ ] **Step 5: Implement `lib/core/api/match_models.dart`** exactly per the Interfaces block. Use these helpers at the top of the file so every class parses defensively but strictly:

```dart
List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) f) =>
    (v! as List<dynamic>).map((e) => f(e as Map<String, dynamic>)).toList();

Map<String, dynamic>? _obj(Object? v) => v == null ? null : v as Map<String, dynamic>;

int _int(Object? v) => (v as num).toInt();
int? _intOrNull(Object? v) => (v as num?)?.toInt();
```
`CheckInVerdict` parse: `switch (s) { 'both' => both, 'one' => one, 'none' => none, _ => throw FormatException('Unknown check-in verdict: $s') }`. Same pattern for `BannerKind`. `SummaryBanner.fromJson` reads `awaitingOpponent` only when `kind == 'qualified'`.

- [ ] **Step 6: Implement the client methods** in `api_client.dart` (append; keep the existing `_send(...)` signature which already accepts `headers`). Query strings: build with `Uri(path: ..., queryParameters: {...}).toString()` (use the existing `_withQuery(String path, Map<String, Object?> query)` helper already in `api_client.dart` from the 3a work — do not add another). Path segments use `Uri.encodeComponent`. Write methods parse `{success: true}` responses with `(_) {}`.

- [ ] **Step 7: Run tests + contract test**

Run: `flutter test test/core/match_models_test.dart test/core/api_client_match_test.dart test/core/api_contract_test.dart`
Expected: PASS (the contract test also checks the 12 new operations against the re-copied `api/openapi.json`).

- [ ] **Step 8: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add pubspec.yaml pubspec.lock api/openapi.json lib/core/api test/core test/support
git commit -m "feat(api): Phase 2b contract models and client methods"
```

---

### Task 2: Copy (ARB en + fr) and error-code copy

**Files:**
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_fr.arb`
- Create: `lib/features/match/match_error_copy.dart`, `test/features/match/match_error_copy_test.dart`

**Interfaces:**
- Produces: `String matchErrorCopy(AppLocalizations l10n, String code)` — never empty; unknown codes → `l10n.mtcEcGeneric`. Codes handled: `network`, `unauthorized`, `idempotency_in_progress`, `upload_failed`, `match_not_found`, `not_participant`, `not_match_day`, `check_in_closed`, `bye_no_result`, `match_cancelled`, `already_confirmed`, `submission_locked`, `screenshot_required`, `validation_failed`, `not_a_participant`, `result_not_confirmed_yet`, `cannot_rate_self`, `not_ratable`, `already_rated`, `pending_deletion`, `own_match`, `invalid_pick`, `window_closed`, `insufficient_coins`, `not_in_lobby`, `lobby_confirmed`, `result_confirmed`. (`*_failed` server-internal codes fall through to generic.)

- [ ] **Step 1: Add the keys.** Append to `app_en.arb` (mind commas) and the same keys to `app_fr.arb`. Placeholders need an `@key` block like `updateRequiredBody`. French is machine-written: flag for native review in the PR.

| Key | English | French |
|---|---|---|
| `mtcBracketTitle` | Bracket | Tableau |
| `mtcTabGroups` | Groups | Groupes |
| `mtcTabFixtures` | Fixtures | Matchs |
| `mtcTabKnockout` | Knockout | Phase finale |
| `mtcNoDrawYet` | The draw hasn't been made yet. | Le tirage n'a pas encore été fait. |
| `mtcChampion` | Champion | Champion |
| `mtcThirdPlace` | Third place | 3e place |
| `mtcNoWinner` | This tournament closed without a winner. | Ce tournoi s'est terminé sans vainqueur. |
| `mtcGroupCol` | {group} | {group} (placeholder `group` String) |
| `mtcColPlayed` | P | J |
| `mtcColWins` | W | V |
| `mtcColDraws` | D | N |
| `mtcColLosses` | L | D |
| `mtcColGoalDiff` | GD | DB |
| `mtcColPoints` | Pts | Pts |
| `mtcAdvancing` | Advancing | Qualifié |
| `mtcFixtLive` | Live | En direct |
| `mtcFixtUpcoming` | Upcoming | À venir |
| `mtcFixtCompleted` | Completed | Terminés |
| `mtcFixtDisputed` | Disputed or cancelled | Litigieux ou annulés |
| `mtcProjectedMatches` | {count} matches to come | {count} matchs à venir (placeholder `count` int) |
| `mtcTbd` | To be announced | À confirmer |
| `mtcVs` | vs | contre |
| `mtcStages` | Stages | Phases |
| `mtcStageStandingsTitle` | Standings | Classement |
| `mtcColRank` | # | # |
| `mtcColKills` | Kills | Éliminations |
| `mtcTieUnresolved` | Tied — awaiting tiebreak | Égalité — départage en attente |
| `mtcMatchTitle` | Match | Match |
| `mtcStatusScheduled` | Scheduled | Programmé |
| `mtcStatusLive` | Live | En direct |
| `mtcStatusCompleted` | Completed | Terminé |
| `mtcStatusDisputed` | Under review | En cours d'examen |
| `mtcStatusCancelled` | Cancelled | Annulé |
| `mtcStatusBye` | Bye | Exempt |
| `mtcStatusForfeited` | Forfeited | Forfait |
| `mtcWatchLive` | Watch live | Regarder en direct |
| `mtcWatchReplay` | Watch replay | Voir le replay |
| `mtcCheckIn` | I'm here — check in | Je suis là — pointer |
| `mtcCheckedIn` | Checked in | Pointé |
| `mtcNotCheckedIn` | Not checked in | Non pointé |
| `mtcCheckInSuccess` | You're checked in. | Vous êtes pointé. |
| `mtcSubmitResult` | Submit result | Soumettre le résultat |
| `mtcResultSubmitted` | Result submitted — awaiting confirmation. | Résultat soumis — en attente de confirmation. |
| `mtcRateOpponent` | Rate your opponent | Noter votre adversaire |
| `mtcRated` | Thanks for rating! | Merci pour votre note ! |
| `mtcWagerTitle` | Wager | Pari |
| `mtcWagerLoginPrompt` | Log in to place a wager. | Connectez-vous pour parier. |
| `mtcWagerClosed` | Wagering is closed for this match. | Les paris sont fermés pour ce match. |
| `mtcWagerPool` | Pool: {a} vs {b} coins | Cagnotte : {a} contre {b} pièces (placeholders `a`,`b` int) |
| `mtcWagerFee` | House fee {percent}% | Frais {percent} % (placeholder `percent` String) |
| `mtcWagerYourPick` | Your wager: {coins} coins on {name} | Votre pari : {coins} pièces sur {name} (placeholders `coins` int, `name` String) |
| `mtcWagerPlace` | Place wager | Parier |
| `mtcWagerChange` | Change wager | Modifier le pari |
| `mtcWagerStake` | Stake (coins) | Mise (pièces) |
| `mtcWagerStakeRange` | Between {min} and {max} coins. | Entre {min} et {max} pièces. (int,int) |
| `mtcWagerPlaced` | Wager placed. | Pari enregistré. |
| `mtcWagerEstimate` | A 100-coin wager on the first player would pay about {payout} coins. | Un pari de 100 pièces sur le premier joueur rapporterait environ {payout} pièces. (placeholder `payout` String) |
| `mtcNoShowInfo` | This match is eligible for no-show handling by the organizers. | Ce match peut être traité comme forfait par les organisateurs. |
| `mtcScoreA` | {name} score | Score de {name} (placeholder `name` String) |
| `mtcRecordingUrl` | Recording link (optional) | Lien de l'enregistrement (facultatif) |
| `mtcPickScreenshot` | Choose screenshot | Choisir une capture |
| `mtcChangeScreenshot` | Change screenshot | Changer la capture |
| `mtcScreenshotRequired` | A screenshot is required. | Une capture d'écran est requise. |
| `mtcUploading` | Uploading screenshot… | Envoi de la capture… |
| `mtcSubmitting` | Submitting… | Envoi… |
| `mtcValScore` | Enter a whole number from 0 to 99. | Saisissez un entier de 0 à 99. |
| `mtcLobbyResultTitle` | Lobby result | Résultat du lobby |
| `mtcPlacement` | Placement | Classement |
| `mtcKills` | Kills | Éliminations |
| `mtcValPlacement` | Enter a whole number from 1 to 100. | Saisissez un entier de 1 à 100. |
| `mtcValKills` | Enter a whole number from 0 to 100. | Saisissez un entier de 0 à 100. |
| `mtcFixturesTitle` | Your fixtures | Vos matchs |
| `mtcNextMatch` | Next match | Prochain match |
| `mtcNextLobby` | Next lobby | Prochain lobby |
| `mtcSubmitPrompt` | You have a match awaiting your result. | Un match attend votre résultat. |
| `mtcLobbySubmitted` | Result submitted | Résultat soumis |
| `mtcRoomCodeReady` | Room details are ready | Les détails de la salle sont prêts |
| `mtcBannerQualified` | You qualified in {title} ({round}). | Vous êtes qualifié dans {title} ({round}). (String,String) |
| `mtcBannerAwaiting` | Waiting for your opponent. | En attente de votre adversaire. |
| `mtcBannerEliminated` | You were eliminated from {title} ({round}). | Vous avez été éliminé de {title} ({round}). (String,String) |
| `mtcRegistrationsHeading` | Your registrations | Vos inscriptions |
| `mtcPaymentPending` | Payment pending | Paiement en attente |
| `mtcPaymentPaid` | Paid | Payé |
| `mtcEcGeneric` | Something went wrong. Please try again. | Une erreur est survenue. Veuillez réessayer. |
| `mtcEcNetwork` | No connection. Check your internet and try again. | Pas de connexion. Vérifiez votre internet et réessayez. |
| `mtcEcSession` | Your session expired. Please log in again. | Votre session a expiré. Reconnectez-vous. |
| `mtcEcInProgress` | Still processing your request. Please wait a moment and try again. | Traitement en cours. Patientez un instant puis réessayez. |
| `mtcEcUploadFailed` | Screenshot upload failed. Please try again. | L'envoi de la capture a échoué. Réessayez. |
| `mtcEcMatchNotFound` | Match not found. | Match introuvable. |
| `mtcEcNotParticipant` | You're not playing in this match. | Vous ne jouez pas dans ce match. |
| `mtcEcNotMatchDay` | You can check in once it's match day. | Vous pourrez pointer le jour du match. |
| `mtcEcCheckInClosed` | This match is no longer open for check-in. | Le pointage est fermé pour ce match. |
| `mtcEcBye` | This is a bye — there is no result to submit. | Match exempt — aucun résultat à soumettre. |
| `mtcEcCancelled` | This match was cancelled. | Ce match a été annulé. |
| `mtcEcAlreadyConfirmed` | This result is already confirmed. | Ce résultat est déjà confirmé. |
| `mtcEcSubmissionLocked` | Your submission is under review and can no longer be edited. | Votre soumission est en cours d'examen et ne peut plus être modifiée. |
| `mtcEcValidation` | Please check what you entered. | Vérifiez votre saisie. |
| `mtcEcResultNotConfirmed` | You can rate your opponent once the result is confirmed. | Vous pourrez noter votre adversaire une fois le résultat confirmé. |
| `mtcEcCannotRateSelf` | You can't rate yourself. | Vous ne pouvez pas vous noter. |
| `mtcEcNotRatable` | This match can't be rated. | Ce match ne peut pas être noté. |
| `mtcEcAlreadyRated` | You've already rated this match. | Vous avez déjà noté ce match. |
| `mtcEcPendingDeletion` | Your account is pending deletion. | Votre compte est en cours de suppression. |
| `mtcEcOwnMatch` | You can't wager on your own match. | Vous ne pouvez pas parier sur votre propre match. |
| `mtcEcInvalidPick` | Pick one of the two players in this match. | Choisissez l'un des deux joueurs de ce match. |
| `mtcEcWindowClosed` | Wagering is closed for this match. | Les paris sont fermés pour ce match. |
| `mtcEcInsufficientCoins` | Not enough SX Coins for this stake. | Pas assez de SX Coins pour cette mise. |
| `mtcEcNotInLobby` | You're not in this lobby. | Vous n'êtes pas dans ce lobby. |
| `mtcEcLobbyConfirmed` | This lobby is confirmed and can no longer be edited. | Ce lobby est confirmé et ne peut plus être modifié. |
| `mtcEcResultConfirmed` | Your result is confirmed and can no longer be edited. | Votre résultat est confirmé et ne peut plus être modifié. |
| `mtcHomeFixtures` | Fixtures | Matchs |

Also add the entry tile keys only if Task 9 needs them (it does not).

- [ ] **Step 2: Regenerate and confirm parity**

Run: `flutter gen-l10n && flutter test test/core/l10n_test.dart`
Expected: PASS.

- [ ] **Step 3: Write the failing test** — `test/features/match/match_error_copy_test.dart`: build `AppLocalizationsEn()`; assert every code listed in the Interfaces block returns non-empty copy that is **not** `mtcEcGeneric` and that the set of distinct outputs has at least 22 members; assert `'submit_failed'`, `'check_in_failed'`, `'wager_failed'`, `'something_new'` and `''` return `mtcEcGeneric`.

- [ ] **Step 4: Run to verify failure, implement, run again**

Run: `flutter test test/features/match/match_error_copy_test.dart` → FAIL (file not found). Implement `matchErrorCopy` as a `switch` mapping each code to its `mtcEc*` getter (`network`→`mtcEcNetwork`, `unauthorized`→`mtcEcSession`, `idempotency_in_progress`→`mtcEcInProgress`, `upload_failed`→`mtcEcUploadFailed`, `match_not_found`→`mtcEcMatchNotFound`, `not_participant`/`not_a_participant`→`mtcEcNotParticipant`, `not_match_day`, `check_in_closed`, `bye_no_result`→`mtcEcBye`, `match_cancelled`→`mtcEcCancelled`, `already_confirmed`, `submission_locked`, `screenshot_required`→`mtcScreenshotRequired`, `validation_failed`→`mtcEcValidation`, `result_not_confirmed_yet`→`mtcEcResultNotConfirmed`, `cannot_rate_self`, `not_ratable`, `already_rated`, `pending_deletion`, `own_match`, `invalid_pick`, `window_closed`→`mtcEcWindowClosed`, `insufficient_coins`, `not_in_lobby`, `lobby_confirmed`, `result_confirmed`, default → `mtcEcGeneric`).
Expected after implementing: PASS.

- [ ] **Step 5: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/core/l10n lib/features/match/match_error_copy.dart test/features/match
git commit -m "feat(l10n): Phase 2b copy (en+fr) and match error-code copy"
```

---

### Task 3: `WriteFlow` — the one idempotent-write notifier

**Files:**
- Create: `lib/core/utils/write_flow.dart`, `test/core/write_flow_test.dart`

**Interfaces:**
- Consumes: `ApiException` (`lib/core/api/api_client.dart`), `newIdempotencyKey()` (2a).
- Produces:

```dart
enum WritePhase { idle, submitting, done, failed }
class WriteState { final WritePhase phase; final String? errorCode; final Map<String, String> fieldErrors; bool get busy; }
final writeFlowProvider = NotifierProvider.autoDispose.family<WriteFlow, WriteState, String>(WriteFlow.new); // family arg = a scope string, e.g. 'rating:<matchId>'
class WriteFlow extends Notifier<WriteState> {
  Future<bool> run(Future<void> Function(String idempotencyKey) call); // true on success; ignored (returns false) while busy
  void reset();                 // back to idle AND mints a fresh key next time
  String get currentKey;        // visible for tests
}
```

Semantics (implement exactly): `run` ignores calls while `busy`. It sets `submitting` **before its first `await`**, takes `_key ??= newIdempotencyKey()`, awaits `call(key)`, and after every `await` checks `ref.mounted`. On success: `_key = null`, phase `done`, return `true`. On failure: phase `failed` with `errorCode` = `'unauthorized'` when `ApiException.isUnauthorized`, else the `ApiException.code`, else `'network'` for any non-`ApiException`; `fieldErrors` from `ApiException.fields`. **Key kept** iff the failure is a non-`ApiException`, or code ∈ {`network`, `idempotency_in_progress`, `bad_response`}; otherwise `_key = null`.

- [ ] **Step 1: Write the failing tests** — `test/core/write_flow_test.dart`, using a `ProviderContainer` with `container.listen(writeFlowProvider('s'), (_, _) {})` to keep the autoDispose provider alive (copy the `_Rig` idea from `test/features/compete/registration_flow_test.dart`). Tests:
  1. success → `done`, returns true, and the next `run` after `reset()` uses a different key.
  2. network `ApiException(status:0, code:'network')` → `failed`/`network`; retry reuses the **same** key.
  3. `idempotency_in_progress` (409) and `bad_response` (504) both keep the key.
  4. `already_rated` (409), `insufficient_coins` (400), `window_closed`, any other code → next `run` uses a **new** key.
  5. a non-`ApiException` (`Exception('x')`) → `failed`/`network` and the key is kept.
  6. 401 → `errorCode == 'unauthorized'`.
  7. `fieldErrors` copied from `ApiException.fields`.
  8. a second `run` while the first is in flight (gate with a `Completer`) is ignored: the `call` closure runs once.
  9. success clears the key: two consecutive successful runs (without reset) use different keys.
  10. after the container is disposed mid-call, completing the call does not throw (`ref.mounted` guard).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/write_flow_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Implement `lib/core/utils/write_flow.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'idempotency_key.dart';

enum WritePhase { idle, submitting, done, failed }

class WriteState {
  const WriteState({this.phase = WritePhase.idle, this.errorCode, this.fieldErrors = const {}});
  final WritePhase phase;
  final String? errorCode;
  final Map<String, String> fieldErrors;
  bool get busy => phase == WritePhase.submitting;
}

final writeFlowProvider =
    NotifierProvider.autoDispose.family<WriteFlow, WriteState, String>(WriteFlow.new);

class WriteFlow extends Notifier<WriteState> {
  WriteFlow(this.scope);
  final String scope;

  String? _key;

  @override
  WriteState build() => const WriteState();

  String get currentKey => _key ??= newIdempotencyKey();

  void reset() {
    _key = null;
    state = const WriteState();
  }

  Future<bool> run(Future<void> Function(String idempotencyKey) call) async {
    if (state.busy) return false;
    state = const WriteState(phase: WritePhase.submitting);
    try {
      await call(currentKey);
    } catch (e) {
      if (!ref.mounted) return false;
      // Same key only when the request may not have been processed; every real response, error or
      // not, is stored server-side under the key and would be replayed on reuse.
      final keep = e is! ApiException ||
          e.code == 'network' ||
          e.code == 'idempotency_in_progress' ||
          e.code == 'bad_response';
      if (!keep) _key = null;
      state = e is ApiException
          ? WriteState(phase: WritePhase.failed, errorCode: e.isUnauthorized ? 'unauthorized' : e.code, fieldErrors: e.fields)
          : const WriteState(phase: WritePhase.failed, errorCode: 'network');
      return false;
    }
    if (!ref.mounted) return true;
    _key = null;
    state = const WriteState(phase: WritePhase.done);
    return true;
  }
}
```

- [ ] **Step 4: Run and commit**

Run: `flutter test test/core/write_flow_test.dart` → Expected: PASS.

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/core/utils/write_flow.dart test/core/write_flow_test.dart
git commit -m "feat(core): WriteFlow generic idempotent-write notifier with the Idempotency-Key policy"
```

---

### Task 4: Screenshot pick + upload-once submitter

**Files:**
- Create: `lib/features/match/evidence.dart`, `test/features/match/evidence_test.dart`

**Interfaces:**
- Consumes: `WriteFlow` (Task 3), `ApiException`, `supabaseClientProvider`.
- Produces:

```dart
class PickedImage { const PickedImage({required this.name, required this.bytes, this.mimeType}); final String name; final Uint8List bytes; final String? mimeType; }
String evidencePath({required String userId, required String scopeId, required String fileName, required DateTime now});
abstract class EvidenceUploader { Future<String> upload({required String userId, required String scopeId, required PickedImage image}); }   // returns the storage path
abstract class ImagePickerPort { Future<PickedImage?> pickScreenshot(); }                                                                   // null = user cancelled
final evidenceUploaderProvider = Provider<EvidenceUploader>(...);   // SupabaseEvidenceUploader(supabaseClientProvider)
final imagePickerProvider = Provider<ImagePickerPort>(...);         // PluginImagePicker()
/// Uploads at most once per picked image, then runs [send] through the given WriteFlow.
class ResultSubmitter {
  ResultSubmitter({required this.uploader, required this.userId, required this.scopeId});
  Future<bool> submit({
    required WriteFlow flow,
    required PickedImage image,
    required Future<void> Function(String screenshotPath, String idempotencyKey) send,
  });
}
```

Rules: `evidencePath` = `'$userId/$scopeId/${now.millisecondsSinceEpoch}-$safe'` where `safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')` (identical to the website). `ResultSubmitter` memoizes the uploaded path **per `PickedImage` instance** (`identical(image, _lastImage)`): a retry after a failed POST reuses the path and never uploads again; picking a different image uploads again. An upload that throws anything is converted to `ApiException(status: 0, code: 'upload_failed', message: 'Screenshot upload failed.')` **thrown inside the `flow.run` closure**, so `WriteFlow` mints a new key for it (nothing was sent) and the screen shows `mtcEcUploadFailed`.

- [ ] **Step 1: Write the failing tests** — `test/features/match/evidence_test.dart` with a `_FakeUploader` (records calls, can be told to throw) and a `ProviderContainer` + `writeFlowProvider('result:m1')`:
  1. `evidencePath` sanitizes `'my shot (1).png'` to `u1/m1/1700000000000-my_shot__1_.png` for a fixed `now`.
  2. success: uploads once, calls `send` with the uploaded path and a key, returns `true`.
  3. **POST fails with a server error, retry with the same `PickedImage` instance**: the uploader is called exactly **once** across both attempts and `send` receives the same path both times; the second attempt uses a **new** key (server error) — assert via the keys `send` received.
  4. POST fails with `network`: retry reuses the same key and the same path, one upload.
  5. a **different** `PickedImage` instance triggers a second upload.
  6. upload throws: `flow.state.errorCode == 'upload_failed'`, `send` is never called, and the next `submit` (upload now succeeds) uses a **new** key.

- [ ] **Step 2: Run to verify failure, then implement.** `SupabaseEvidenceUploader.upload` builds the path with `evidencePath(now: DateTime.now())` and calls `client.storage.from('match-evidence').uploadBinary(path, image.bytes, fileOptions: FileOptions(upsert: false, contentType: image.mimeType))`, returns `path`. `PluginImagePicker.pickScreenshot` uses `ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80)` (this is the spec's "compress before upload"), returns `null` on cancel, else `PickedImage(name: file.name, bytes: await file.readAsBytes(), mimeType: file.mimeType)`. `ResultSubmitter.submit` is `flow.run((key) async { path = memoOrUpload(); await send(path, key); })` with the memo and the `upload_failed` conversion described above.
Run: `flutter test test/features/match/evidence_test.dart` → Expected: FAIL first, then PASS.

- [ ] **Step 3: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/match/evidence.dart test/features/match/evidence_test.dart
git commit -m "feat(match): screenshot picker, upload-once result submitter"
```

---

### Task 5: Reads, providers and the bracket / standings / champion screens

**Files:**
- Create: `lib/features/match/match_reads_repository.dart`, `lib/features/match/match_repository.dart`, `lib/features/match/match_providers.dart`, `lib/features/bracket/bracket_screen.dart`, `lib/features/bracket/stage_standings_screen.dart`, `test/fakes/fake_match_repositories.dart`, `test/features/bracket/bracket_screen_test.dart`, `test/features/bracket/stage_standings_screen_test.dart`, `test/features/match/match_reads_test.dart`
- Modify: `lib/features/compete/compete_detail_screen.dart` (champion card + Stages entry), `test/features/compete/compete_detail_screen_test.dart`

**Interfaces:**
- Consumes: Task 1 models/client, `supabaseClientProvider`, `apiClientProvider`.
- Produces:

```dart
class StageInfo { String id; int seq; String name; String status; factory StageInfo.fromJson(Map<String,dynamic>); }
class MatchInfo { String id; String? tournamentId; String? tournamentTitle; String round; String status; int? scoreA; int? scoreB; String? scheduledAt; bool isFullDay; String? streamUrl; String? replayUrl; String? playerAId; String? playerBId; String nameA; String nameB; factory MatchInfo.fromJson(Map<String,dynamic>); }
abstract class MatchReadsRepository { Future<MatchInfo> fetchMatch(String matchId); Future<List<StageInfo>> fetchStages(String tournamentId); }
abstract class MatchRepository {   // wraps ApiClient so tests inject fakes
  Future<BracketView> bracket(String tournamentId);
  Future<List<PointsStandingRow>> stageStandings(String tournamentId, String stageId);
  Future<TournamentResults> results(String tournamentId);
  Future<MatchCentre> centre(String matchId);
  Future<void> checkIn(String matchId);
  Future<void> submitResult(String matchId, {required int scoreA, required int scoreB, required String recordingUrl, required String screenshotPath, required String idempotencyKey});
  Future<void> rate(String matchId, {required int stars, required String idempotencyKey});
  Future<void> wager(String matchId, {required String pickPlayerId, required int stakeCoins, required String idempotencyKey});
  Future<void> submitLobbyResult(String lobbyId, {required int placement, required int kills, required String screenshotPath, required String idempotencyKey});
  Future<MeSummary> summary();
}
final matchReadsRepositoryProvider, matchRepositoryProvider;
final matchInfoProvider = FutureProvider.autoDispose.family<MatchInfo, String>(...);
final bracketProvider = FutureProvider.autoDispose.family<BracketView, String>(...);
final stagesProvider = FutureProvider.autoDispose.family<List<StageInfo>, String>(...);
final stageStandingsProvider = FutureProvider.autoDispose.family<List<PointsStandingRow>, ({String tournamentId, String stageId})>(...);
final tournamentResultsProvider = FutureProvider.autoDispose.family<TournamentResults, String>(...);
final matchCentreProvider = FutureProvider.autoDispose.family<MatchCentre, String>(...);
final meSummaryProvider = FutureProvider.autoDispose<MeSummary?>(...);   // null when signed out; never calls the API signed out
```

T1 columns (verified in Task 0): match row `id, tournament_id, round, status, score_a, score_b, scheduled_at, is_full_day, youtube_stream_url, replay_url, player_a_id, player_b_id, team_a_id, team_b_id, tournaments(title), player_a:profiles!matches_player_a_id_fkey(username, display_name), player_b:profiles!matches_player_b_id_fkey(username, display_name), team_a:squads!matches_team_a_id_fkey(name), team_b:squads!matches_team_b_id_fkey(name)`; `nameA` = team name when `team_a` present, else `display_name ?? username ?? '—'`. Stages: `id, seq, name, status` from `tournament_stages` where `tournament_id`, ordered by `seq`. `MatchInfo.fromJson` must accept `tournaments`/profile joins as a map **or** a one-element list (PostgREST returns either).

`BracketScreen(tournamentId, onMatchTap(String matchId), onStageTap(StageInfo))`. Behavior:
- Loads `bracketProvider(id)`. Error → `cmpLoadError` + `cmpRetry` (reuse the 2a keys `cmpLoadError`/`cmpRetry`); never a raw exception. Pull-to-refresh invalidates.
- Champion banner (`mtcChampion`: name, plus `mtcThirdPlace` if set) shown above the tabs when `champion != null`.
- Three tabs (`TabBar`, keys `tab-groups`, `tab-fixtures`, `tab-knockout`), each shown **only** when the view has that content (`hasGroups`, any fixtures, `hasKnockout` or `projected` non-empty). When `!hasGroups && !hasKnockout && fixtures empty` → single message `mtcNoDrawYet`, no tabs.
- Groups tab: per group a `DataTable`-style table (use a horizontally scrollable `SingleChildScrollView` with fixed column widths so 375px never overflows): rank, name (ellipsized), P W D L GD Pts; rows with `advancing` marked (`mtcAdvancing` semantic label + a colored dot — no color-only meaning).
- Fixtures tab: four collapsible sections (`mtcFixtLive/Upcoming/Completed/Disputed`), empty ones omitted; each row `nameA vs nameB`, score `a – b` **only when both non-null** else the schedule (`mtcTbd` when `scheduledAt == null`; date only when `isFullDay`), status text from `mtcStatus*`; row tap → `onMatchTap(id)`. Byes (`status == 'bye'`) show `mtcStatusBye` and are not tappable.
- Knockout tab: each `KnockoutRound` as a vertical section headed by the API `label`; matches as rows (same row widget); `projected` rounds listed after as `label` + `mtcProjectedMatches(count)`; `thirdPlaceMatch` shown under its own heading `mtcThirdPlace` when non-null.
- A "Stages" section at the bottom when `stagesProvider(id)` returns ≥1 stage: one row per stage (`mtcStages`), tap → `onStageTap(stage)`. Its failure is silent (section omitted).

`StageStandingsScreen(tournamentId, stage)`: table from `stageStandingsProvider`, columns rank, name, P, Pts, Kills; `advancing` marked; rows with non-empty `unresolvedTieWith` show `mtcTieUnresolved`; empty → `mtcNoDrawYet`; error → friendly copy + retry.

Tournament detail (2a): when `tournament.status == 'completed'` and `tournamentResultsProvider(id)` has a champion, show a card with champion name, runner-up, prize pool; when `noWinner` show `mtcNoWinner`. Failure → nothing shown (never blocks the page). Replace the "View bracket" button's callback contract only if needed; it already passes the resolved id (2a fix).

- [ ] **Step 1: Fakes + failing tests**
  - `test/fakes/fake_match_repositories.dart`: `FakeMatchReads` (holds `MatchInfo` map + stages; can `failAll`), `FakeMatchRepository` (holds `BracketView bracket`, `centre`, `results`, `summary`; records `checkIns`, `resultCalls`, `ratingCalls`, `wagerCalls`, `lobbyCalls` including the keys; per-method queues of results-or-exceptions like `FakeRegistrationRepository`; optional `Completer` gates).
  - `match_reads_test.dart`: `MatchInfo.fromJson` — full row; team match (team names win); join returned as list; `score_a: null`; missing profile join → `'—'`; `StageInfo.fromJson`.
  - `bracket_screen_test.dart`, at 375×800 (`pumpCompete`): groups-only view shows the Groups tab and hides Knockout; knockout-only hides Groups; neither → `The draw hasn't been made yet.` and no `TabBar`; champion banner with and without `thirdPlace`; `null` champion shows no banner; a fixture with `null` scores shows the schedule not `null – null`; a bye row is not tappable and shows `Bye`; tapping a normal row calls `onMatchTap` with its id; empty fixture buckets are omitted; a 60-char team name and 5 knockout rounds produce no overflow (`tester.takeException()` null); load failure shows friendly copy without `Exception`; a stage row calls `onStageTap`; the stages failure hides the section only.
  - `stage_standings_screen_test.dart`: rows render rank/name/points/kills; `advancing` marker present; `unresolvedTieWith` shows the tie copy; empty and error states.
  - `compete_detail_screen_test.dart` additions: completed + champion → champion card; completed + `noWinner` → no-winner text; results failure → page still renders; non-completed → results endpoint never called (assert on the fake).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/match test/features/bracket test/features/compete/compete_detail_screen_test.dart`
Expected: FAIL (files not found / new expectations unmet).

- [ ] **Step 3: Implement** the repositories, providers and screens to satisfy the behavior above. `matchRepositoryProvider` = a class wrapping `ref.watch(apiClientProvider)`. `meSummaryProvider` awaits `ref.watch(meProvider.future)` and returns `null` without touching the API when signed out. Keep widgets small (`_FixtureRow`, `_GroupTable`, `_RoundSection`).

- [ ] **Step 4: Run and commit**

Run: `flutter test test/features/match test/features/bracket test/features/compete`
Expected: PASS.

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib test
git commit -m "feat(bracket): bracket, group standings, stage standings and champion card"
```

---

### Task 6: Match Centre (read view, check-in, wager entry)

**Files:**
- Create: `lib/features/match/match_centre_screen.dart`, `lib/features/match/wager_sheet.dart`, `test/features/match/match_centre_screen_test.dart`, `test/features/match/wager_sheet_test.dart`

**Interfaces:**
- Consumes: `matchInfoProvider`, `matchCentreProvider`, `writeFlowProvider`, `matchRepositoryProvider`, `matchErrorCopy`, `meProvider`, `url_launcher`.
- Produces:

```dart
class MatchCentreScreen extends ConsumerWidget {
  const MatchCentreScreen({super.key, required this.matchId, required this.onLogin, required this.onSubmitResult, required this.onRate});
  final String matchId;
  final VoidCallback onLogin;
  final void Function(MatchInfo match) onSubmitResult;   // opens ResultSubmissionScreen (Task 7)
  final void Function(MatchInfo match) onRate;           // opens the rating sheet (Task 7) — a callback so this task does not depend on it
}
Future<void> showWagerSheet(BuildContext context, {required MatchInfo match, required MatchCentre centre});
```

Behavior (exact):
- Loads `matchInfoProvider(id)` (T1, names/score/stream) and `matchCentreProvider(id)` (API). Either failing → friendly `cmpLoadError` + `cmpRetry` retrying both. Pull-to-refresh invalidates both. Never shows raw exceptions.
- Header: tournament title (when known), round label as given (`MatchInfo.round` is a code like `quarter_final` — display it through a tiny private `_roundLabel` that title-cases the code with underscores→spaces; **do not** add a per-round ARB table), status chip via `mtcStatus*` (unknown status → chip hidden, never blank text), `nameA` vs `nameB`, and the score `a – b` **only when the match is `completed` and both scores non-null**. `bye`/`cancelled`/`forfeited`/`disputed` show their status text and hide the score.
- Schedule line from `centre.scheduledAt` (date only when `isFullDay`, `mtcTbd` when null).
- Watch buttons: `mtcWatchLive` when `streamUrl != null`, `mtcWatchReplay` when `replayUrl != null`; open with `launchUrl(..., mode: LaunchMode.externalApplication)`; only `http`/`https` URLs are opened.
- **Guest** (`meProvider` null): no check-in/submit/rate controls; wager card shows `mtcWagerLoginPrompt` with a login button (`onLogin`).
- **Participant** (`centre.isParticipant`): 
  - check-in row: shows `mtcCheckedIn` / `mtcNotCheckedIn` for each side (a side is checked in when its player id is in `checkedInPlayerIds`; the match's player ids come from `MatchInfo`); the "I'm here" button (`key: check-in-button`) appears **only when `centre.canCheckIn`**; tap → `matchRepository.checkIn(id)` (no key) with a local busy flag (double tap sends one request); success → SnackBar `mtcCheckInSuccess` + `ref.invalidate(matchCentreProvider(id))`; failure → SnackBar `matchErrorCopy(code)`.
  - "Submit result" button (`key: submit-result-button`) shown when `status` is not one of `completed|cancelled|bye|forfeited` → `onSubmitResult(match)`.
  - "Rate your opponent" button (`key: rate-button`) shown only when `status == 'completed'` → `onRate(match)`.
  - the wager card is **not** shown to participants.
- **Signed-in non-participant**: no check-in/submit/rate; wager card (below).
- `centre.noShowEligible` → informational `mtcNoShowInfo` text (no action).
- **Wager card** (non-participant, signed in): shows pools `mtcWagerPool(a,b)`, fee `mtcWagerFee` (`(feeRate*100)` formatted without trailing `.0`), and `mtcWagerEstimate` using `wager.estimatedPayoutIfIStakeA100` exactly as returned. If `!windowOpen` → `mtcWagerClosed` and no button. If `myStakeCoins != null` → `mtcWagerYourPick(coins, name-of-pick)` and the button reads `mtcWagerChange`, else `mtcWagerPlace`. Button opens `showWagerSheet`.

`WagerSheet`: two radio options (the two players' names from `MatchInfo`, values = their player ids; team matches have no wagering picks by id — if either `playerAId`/`playerBId` is null, show `mtcWagerClosed` and no form), a numeric stake field (`mtcWagerStake`, hint `mtcWagerStakeRange(min,max)` from `centre.wager`), pre-filled from `myPickPlayerId`/`myStakeCoins` when present. Client validation: integer within `[minStake, maxStake]`, else inline `mtcWagerStakeRange`; a pick is required. Submit → `WriteFlow` scope `wager:<matchId>` → `matchRepository.wager(...)`; success → close, SnackBar `mtcWagerPlaced`, `ref.invalidate(matchCentreProvider(id))`; failure → inline `matchErrorCopy(code)` and keep the sheet open; while busy: submit disabled, close disabled (`PopScope`, `enableDrag: false`). `own_match`/`window_closed`/`insufficient_coins` show their specific copy.

- [ ] **Step 1: Failing tests** (`FakeMatchReads` + `FakeMatchRepository` + `competeBaseOverrides()`; 375×800):
  - `match_centre_screen_test.dart`: completed match shows the score; a live match with `null` scores shows no `null`; `bye`/`cancelled`/`disputed`/`forfeited` show their status and no score; unknown status string renders without crash; guest sees no check-in/submit/rate and sees the login prompt (tap calls `onLogin`); participant with `canCheckIn: false` has no check-in button; with `canCheckIn: true` tap calls `checkIn` once even on a double tap (gate), then shows the success snackbar and re-reads the centre (`centreCalls` grows); check-in error `not_match_day` shows the localized copy, not server text; participant sees submit-result for `scheduled|live|disputed`, not for `completed|cancelled|bye|forfeited`; rate button only for `completed`; participant never sees the wager card; non-participant sees the wager card, no participant controls; `noShowEligible` shows the info text; watch buttons only when URLs exist and a `javascript:` URL is not launchable (test the pure helper `isLaunchableUrl(String)` exported from the screen file); load failure shows retry; pull-to-refresh re-reads; team match (`playerAId == null`) renders names and hides the wager form; long 60-char names at 375px no overflow.
  - `wager_sheet_test.dart`: stake below min / above max / non-numeric blocks the call and shows range copy; no pick blocks; a valid wager calls `wager` once with `(pickPlayerId, stakeCoins)` and a key, closes and shows `Wager placed.`; a network failure then a second tap reuses the **same** key; `insufficient_coins` shows its copy and the next tap uses a **new** key; `window_closed` shows its copy; existing wager pre-fills pick and stake; close disabled while busy.

- [ ] **Step 2: Run to verify failure, implement, run again**

Run: `flutter test test/features/match/match_centre_screen_test.dart test/features/match/wager_sheet_test.dart`
Expected: FAIL first, then PASS.

- [ ] **Step 3: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/match test/features/match
git commit -m "feat(match): Match Centre with check-in and wager sheet"
```

---

### Task 7: Result submission and rating

**Files:**
- Create: `lib/features/match/result_submission_screen.dart`, `lib/features/match/rating_sheet.dart`, `test/features/match/result_submission_screen_test.dart`, `test/features/match/rating_sheet_test.dart`, `test/fakes/fake_evidence.dart`

**Interfaces:**
- Consumes: `ResultSubmitter`, `evidenceUploaderProvider`, `imagePickerProvider`, `writeFlowProvider`, `matchRepositoryProvider`, `MatchInfo`, `matchErrorCopy`, `meProvider`.
- Produces:

```dart
class ResultSubmissionScreen extends ConsumerStatefulWidget { const ResultSubmissionScreen({super.key, required this.match}); final MatchInfo match; }
Future<void> showRatingSheet(BuildContext context, {required MatchInfo match});
```
`fake_evidence.dart`: `FakeUploader` (records `upload` calls, optional throw) and `FakePicker` (returns a queued `PickedImage?`).

`ResultSubmissionScreen` behavior:
- Title `mtcSubmitResult`; labels `mtcScoreA(nameA)` / `mtcScoreA(nameB)` for two integer fields (keys `score-a`, `score-b`), an optional `mtcRecordingUrl` field (`recording-url`), a screenshot button (`mtcPickScreenshot`, becomes `mtcChangeScreenshot` after a pick; key `pick-screenshot`) showing the chosen file **name** (no image decode needed) and `mtcScreenshotRequired` under it when submit is attempted without one.
- Validation before any I/O: both scores integers `0..99` else `mtcValScore` under the field; screenshot required. Nothing is uploaded or sent while invalid.
- Submit (key `submit-result`) → `ResultSubmitter.submit(flow: writeFlow('result:<matchId>'), image, send: (path, key) => matchRepository.submitResult(matchId, scoreA, scoreB, recordingUrl.trim(), path, key))`. States: while uploading show `mtcUploading`, while sending `mtcSubmitting` (you may show `mtcSubmitting` for both); fields and buttons disabled while `busy`.
- Success → the screen is replaced by a confirmation panel `mtcResultSubmitted` (never a score-as-fact, never "you won") with a Done button that pops; also `ref.invalidate(matchCentreProvider(matchId))`.
- Failure → inline `matchErrorCopy(code)`; keeps all entered values and the picked image; `submission_locked`, `already_confirmed`, `match_cancelled`, `bye_no_result` are terminal messages (no retry hint needed but the form stays visible). Field errors from `validation_failed` map to `mtcValScore`.
- Signed out (`meProvider` null) → a login-needed message and no form (the route is only linked for participants, this is a guard).
- The screen holds one `ResultSubmitter` in state (created in `initState` with `userId = me.id`); the picked `PickedImage` instance is kept so the upload-once memo works across retries.

`RatingSheet` behavior: five tappable stars (keys `star-1`..`star-5`; semantic labels "1 star"…"5 stars" — use the material `Icon(Icons.star)` toggled), a submit button; no default selection (submit disabled until chosen). Submit → `WriteFlow` scope `rating:<matchId>` → `matchRepository.rate(matchId, stars, key)`; success → close + SnackBar `mtcRated`; `already_rated` → show its copy and keep the sheet (the user can close); `result_not_confirmed_yet`, `cannot_rate_self`, `not_ratable`, `not_a_participant` show their copy. Busy → disabled + not dismissible (same `PopScope` rule as the wager sheet). Star selection is remembered across a failed attempt.

- [ ] **Step 1: Failing tests**
  - `result_submission_screen_test.dart`: invalid score (`-1`, `100`, `abc`, empty) blocks with `Enter a whole number from 0 to 99.` and makes **zero** upload/send calls; missing screenshot blocks with `A screenshot is required.`; a cancelled picker (`null`) leaves no image; happy path: pick → enter `2`/`1` → submit → uploader called once with `(userId, matchId, image)`, repo received `scoreA 2, scoreB 1, screenshotPath <uploaded>`, a key, confirmation panel shown with `Result submitted — awaiting confirmation.` and **no** score/"won" text; **server error then retry** (queue `submission_locked`, then success): uploader still called **once**, second attempt uses a **new** key; **network error then retry**: same key, one upload; upload failure shows `Screenshot upload failed. Please try again.`, repo never called; double tap on Submit sends one request (gate); a 60-char name in labels at 375px no overflow; signed out shows the login message and no form; `recording-url` trimmed and sent as `''` when blank.
  - `rating_sheet_test.dart`: submit disabled until a star is chosen; choosing 4 and submitting calls `rate(matchId, 4, key)` once and closes with `Thanks for rating!`; `already_rated` shows `You've already rated this match.` and keeps the sheet; network failure then retry reuses the key and the star; server error then retry uses a new key; busy disables close.

- [ ] **Step 2: Run to verify failure, implement, run again**

Run: `flutter test test/features/match/result_submission_screen_test.dart test/features/match/rating_sheet_test.dart`
Expected: FAIL first, then PASS.

- [ ] **Step 3: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/match test/features/match test/fakes
git commit -m "feat(match): result submission with screenshot upload and opponent rating"
```

---

### Task 8: Lobby result (points-race formats)

**Files:**
- Create: `lib/features/match/lobby_result_screen.dart`, `test/features/match/lobby_result_screen_test.dart`

**Interfaces:**
- Consumes: `ResultSubmitter`, `writeFlowProvider('lobby:<lobbyId>')`, `matchRepositoryProvider.submitLobbyResult`, `matchErrorCopy`, `meProvider`, `NextLobby` (for the header).
- Produces: `class LobbyResultScreen extends ConsumerStatefulWidget { const LobbyResultScreen({super.key, required this.lobbyId, this.lobby}); final String lobbyId; final NextLobby? lobby; }` — `lobby` is optional header info (tournament title, stage, `label`, round) passed from the dashboard card via router `extra`; the screen works without it.

Behavior: same shape as `ResultSubmissionScreen` with two integer fields — placement (`placement`, `1..100`, `mtcValPlacement`) and kills (`kills`, `0..100`, `mtcValKills`) — plus the required screenshot (path scope = the lobby id). Same upload-once, key policy, busy handling, confirmation panel (`mtcResultSubmitted`) and error copy (`not_in_lobby`, `lobby_confirmed`, `result_confirmed` terminal messages). After success `ref.invalidate(meSummaryProvider)`. Signed-out guard as in Task 7. Title `mtcLobbyResultTitle` plus the `lobby.label` when provided.

- [ ] **Step 1: Failing tests** mirror Task 7's result-screen tests with the lobby fields: invalid placement (`0`, `101`) and kills (`-1`, `101`) block with zero I/O; happy path sends `(placement, kills, path, key)` and shows the confirmation; server error then retry → one upload, new key; network error then retry → same key; upload failure; double tap; `not_in_lobby` copy; header shows the label when `lobby` is given and still renders without it; invalidates `meSummaryProvider` on success (count fake `summary()` calls).
- [ ] **Step 2: Run to verify failure, implement, run again, commit**

Run: `flutter test test/features/match/lobby_result_screen_test.dart` → FAIL first, then PASS.

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/match test/features/match
git commit -m "feat(match): lobby result submission"
```

---

### Task 9: Dashboard fixtures card

**Files:**
- Create: `lib/features/match/fixtures_card.dart`, `test/features/match/fixtures_card_test.dart`
- Modify: `lib/features/home/home_screen.dart` (one line), `test/features/home_screen_test.dart`

**Interfaces:**
- Consumes: `meSummaryProvider`, `MeSummary`.
- Produces: `class FixturesCard extends ConsumerWidget { const FixturesCard({super.key, required this.onGoTo}); final void Function(String path, {Object? extra}) onGoTo; }`. **Note:** `HomeScreen.onGoTo` is `void Function(String path)` today; add an optional second callback instead of changing that signature: `HomeScreen({..., this.onOpenLobby})` with `final void Function(String lobbyId, NextLobby lobby)? onOpenLobby;` and have `FixturesCard` take `onGoTo` (paths only) plus `onOpenLobby`. Keep `HomeScreen`'s existing constructor call sites compiling.

Behavior: renders **nothing** (`SizedBox.shrink`) when signed out, while loading, on error, or when the summary is entirely empty (no next match, no next lobby, no banners, no pending registrations) — Home must never show an error because of this card. Otherwise a card titled `mtcFixturesTitle` with, in order:
1. banners: `qualified` → `mtcBannerQualified(title, round)` plus `mtcBannerAwaiting` when `awaitingOpponent`; `eliminated` → `mtcBannerEliminated`. (`round` is the API string; render it as given, underscores→spaces.)
2. `nextMatch` → tile `mtcNextMatch`: tournament title, round, schedule (`mtcTbd` when null; date-only when `isFullDay`), tap → `onGoTo('/matches/<id>')`; when `hasSubmittableMatch` a `mtcSubmitPrompt` line under it.
3. `nextLobby` → tile `mtcNextLobby`: tournament title, stage/label, schedule; `hasRoomCode` shows `mtcRoomCodeReady`; if `submitted` show `mtcLobbySubmitted` and no tap; else tap → `onOpenLobby(lobbyId, lobby)`.
4. `registrations` with `paymentStatus == 'pending'` → row `tournamentTitle` + `mtcPaymentPending`, tap → `onGoTo('/tournaments/<slug>')`; paid registrations are not listed (the list is a "needs attention" surface).

- [ ] **Step 1: Failing tests** (`fixtures_card_test.dart`): signed out → nothing; summary error → nothing (no exception text); empty summary → nothing; next match renders and taps to `/matches/<id>` (record `onGoTo`); `hasSubmittableMatch` prompt; next lobby not submitted → tap calls `onOpenLobby(lobbyId, lobby)`; submitted lobby shows the submitted text and is not tappable; room-code line; qualified with/without awaiting; eliminated; pending registration row taps to `/tournaments/<slug>`, paid not listed; `null` schedule → `To be announced`; 375px no overflow with 60-char titles. `home_screen_test.dart`: Home renders `FixturesCard` (a fake summary with a next match shows `Next match`), and Home still renders (existing tests untouched) when `meSummaryProvider` errors.
- [ ] **Step 2: Run to verify failure, implement, run again, commit**

Run: `flutter test test/features/match/fixtures_card_test.dart test/features/home_screen_test.dart` → FAIL first, then PASS.

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib test
git commit -m "feat(home): dashboard fixtures card (next match, lobby, banners, pending payments)"
```

---

### Task 10: Routes, deep links, retire the temporary slice

**Files:**
- Modify: `lib/router/app_router.dart`, `lib/core/routing/web_links.dart`, `test/router/app_router_test.dart`, `test/core/web_links_test.dart`, `test/support/pump_app.dart`
- Delete: `lib/data/`, `lib/models/`, `lib/features/tournaments/` (including `tournaments_providers.dart`, `bracket_screen.dart`), `test/fakes/fake_tournaments_repository.dart`, `test/features/bracket_screen_test.dart`

Routes (added/changed only):

| Path | Screen |
|---|---|
| `/tournaments/:id/bracket` | **replaced** → `BracketScreen(tournamentId: id, onMatchTap: (mid) => context.push('/matches/$mid'), onStageTap: (s) => context.push('/tournaments/$id/stages/${s.id}', extra: s))` |
| `/tournaments/:id/stages/:stageId` | new (child of `:id`) → `StageStandingsScreen(tournamentId: id, stage: state.extra as StageInfo? …)`; if `extra` is null, build a `StageInfo` stub from the path so a cold deep link still renders the table |
| `/matches/:id` | new, in the Compete branch (add a second `GoRoute` to the same `StatefulShellBranch` as `/tournaments`, so the tab bar stays) → `MatchCentreScreen(matchId, onLogin: push('/login'), onSubmitResult: (m) => push('/matches/${m.id}/result', extra: m), onRate: (m) => showRatingSheet(context, match: m))` |
| `/matches/:id/result` | new child of `/matches/:id` → `ResultSubmissionScreen(match: state.extra as MatchInfo)`; if `extra` is null (cold link) load `matchInfoProvider(id)` first and show the screen when it resolves |
| `/lobbies/:id/result` | new top-level → `LobbyResultScreen(lobbyId: id, lobby: state.extra as NextLobby?)` |

`resolveWebLink`: add `matches/<id>` → `/matches/<id>` (two segments, first `matches`). Do **not** map `tournaments/<slug>/bracket` (the bracket API needs an id). Existing rules stay.

Home: wire `FixturesCard` with `onGoTo: (p) => context.go(p)` and `onOpenLobby: (id, lobby) => context.push('/lobbies/$id/result', extra: lobby)` from the router builder (append only).

- [ ] **Step 1: Delete the retired slice** — first `grep -rn "lib/data\|lib/models\|features/tournaments\|fake_tournaments_repository\|pumpRouterWithRepo\|pumpWithRepo\|TournamentsRepository" lib test` and remove every remaining reference; update `test/support/pump_app.dart` to drop the old repository parameter/imports (keep the helper names other tests use, backed by the Compete/Match fakes). Run `flutter analyze` to prove nothing dangling.
- [ ] **Step 2: Failing tests** — `test/router/app_router_test.dart`: `/tournaments/t1/bracket` renders `BracketScreen` (uses `FakeMatchRepository`); tapping a fixture navigates to `/matches/<id>`; `/matches/m1` renders the Match Centre inside the tab shell (bottom navigation still present); `/matches/m1/result` with `extra` renders the result screen; the same path **without** `extra` loads the match then renders; `/lobbies/l1/result` renders the lobby screen with and without `extra`; `/tournaments/t1/stages/s1` without `extra` renders the standings table. `web_links_test.dart`: `/matches/abc` and `/fr/matches/abc?x=1` → `/matches/abc`; `/matches` alone → null; `/tournaments/some-slug/bracket` → null (unchanged); locale-prefixed and www hosts accepted.
- [ ] **Step 3: Run to verify failure, implement, run again**

Run: `flutter test test/router test/core/web_links_test.dart` → FAIL first, then PASS. Then `flutter analyze && flutter test`.

- [ ] **Step 4: Commit**

```bash
git checkout -- linux macos windows
git add -A lib test
git commit -m "feat(router): match, bracket, stage and lobby routes; retire the temporary tournaments slice"
```

---

### Task 11: Whole-branch verification and the deferred device checklist

**Files:**
- Create: `docs/agent-handoffs/2026-09-26-mobile-phase2b-flutter-notes.md` (untracked handoff, same format as `2026-09-26-mobile-phase2a-flutter-notes.md`)
- Modify: `TESTING-NOTES.md` (append the checklist below as "pending")

- [ ] **Step 1: Full gates**

```bash
flutter analyze
flutter test
```
Expected: no issues; all pass. **Do not** diff or re-copy `api/openapi.json` against a single web file on the integration base (it is a union); instead confirm `api_contract_test.dart` passes and all twelve 2b operations are present. Record in the handoff note that the contract must be regenerated from the merged web repo.

- [ ] **Step 2: Coverage check against the spec** — walk the 2b spec §4–§8 once: reads (Tasks 1, 5), Match Centre (6), check-in (6), result (7), rating (7), wager (6), lobby result (8), dashboard fixtures (9), idempotency on `result/rating/wager/lobby result` (3, 4, 7, 8), squads (client only, 1). List every deviation and every "Deferred / known gaps" item in the handoff note.

- [ ] **Step 3: Append the device checklist to `TESTING-NOTES.md`** (**do not run it now**; the owner tests all phases together). Setup: staging Supabase `ofxmoxpvwbemfouaowoa` + web dev server on the branch with Paystack test keys, a staging `zzqa_` account with two test players and an admin session on the web for confirming results.

  | # | Check |
  |---|---|
  | 1 | Bracket for a group+knockout tournament: standings tables, fixtures buckets, knockout rounds; compare group tables and the champion against the web page for 3 tournaments |
  | 2 | A points-race tournament: Stages → standings table matches the web |
  | 3 | Match Centre as a guest, as a participant, as a non-participant (each control set as specified) |
  | 4 | Check-in on match day; before match day shows the localized "match day" message; double-tap sends one request |
  | 5 | Submit a result with a screenshot: file appears in `match-evidence/<uid>/<matchId>/…` on staging; the web admin review page shows the pending result; app shows "awaiting confirmation" only |
  | 6 | Airplane-mode toggle during submit, retry: exactly **one** `api_idempotency_keys` row, one `match_results` row, one storage object |
  | 7 | Admin confirms on web → pull-to-refresh: score appears, Rate button appears; rate 5★ → `+20` SX Score event exists once; rate again → "already rated" |
  | 8 | Wager as a third player: place, change, insufficient coins, window closed; coin ledger correct |
  | 9 | Lobby result from the Home card; second submit after admin confirm shows the locked message |
  | 10 | Home fixtures card: next match, submit prompt, banners, pending payment row |
  | 11 | Deep link `/matches/<id>` from a browser opens the Match Centre |
  | 12 | 375px: no overflow on every screen above |

- [ ] **Step 4: Write the handoff note** (branch, HEAD, worktree, test counts, deviations, what is verified vs not — every live-server behavior and the screenshot upload are **not** verified — and "nothing pushed"). Do not commit the note or this plan (untracked by repo convention). Commit only `TESTING-NOTES.md`:

```bash
git add TESTING-NOTES.md
git commit -m "docs: pending device checklist for Phase 2b"
```

- [ ] **Step 5: Report** the branch, HEAD, test counts and open items to the owner. **Do not push** and do not open a PR without the owner's OK.

---

## Self-review (against the spec)

- **Spec coverage.** §4 reads → Tasks 1, 5, 6; §5 writes with idempotency → Tasks 1, 3, 4, 6, 7, 8 (squads: client methods only, screens deferred with reason); §6 opponent rating → Task 7; §7 dashboard fixtures → Task 9; §8 exit criteria → Task 11 checklist (live proofs deferred to the joint device round; server-side idempotency proofs belong to the web plan).
- **Placeholder scan.** No TBD/TODO. Widget layers (Tasks 5–9) are specified by exact behavior plus a complete test list rather than full widget code; state/logic layers (Tasks 1, 3, 4) are fully specified with code or exact semantics. If the executor wants full widget code, ask before starting Task 5.
- **Type consistency.** `BracketFixture` (not `BracketMatch`, which the retired slice still defines until Task 10). `WriteFlow` scope strings: `result:<matchId>`, `rating:<matchId>`, `wager:<matchId>`, `lobby:<lobbyId>`. `MatchInfo` is produced in Task 5 and consumed in Tasks 6–8, 10. `NextLobby` from Task 1 is consumed in Tasks 8–10. `meSummaryProvider` (Task 5) is consumed in Tasks 8–9.
- **Review Focus coverage.** #1 → Tasks 3, 6, 7, 8; #2 → Task 4, 7; #3 → Tasks 6, 7; #4 → Task 6; #5 → Tasks 5, 6, 9.
