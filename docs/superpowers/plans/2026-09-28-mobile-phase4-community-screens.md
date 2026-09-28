# Mobile Phase 4 (Flutter) — Community Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. (No superpowers skills available, e.g. Codex? Follow the steps in order yourself: failing test first, watch it fail, minimal code, watch it pass, commit; keep a running log in `docs/agent-handoffs/`.)

**Goal:** Build Sentinel X mobile's Community pillar — feed (pinned/boosted posts, 4-emoji reactions, flat comments, weekly-challenges rail, Best Play of the Week voting, status-rings tray, top members, upcoming events, gallery, stats bar), post detail, compose (text + up to 5 images, boost for 200 coins), statuses/stories (post, view, author-only viewer list), report (post/comment), delete-own (post/comment) — backed by the 24 `/api/mobile/v1/community/*` endpoints Stage B already shipped to `sentinelx`'s `main`, plus genuine live-new-post/-reaction/-comment/-status realtime. No staff moderation UI (Phase 8's).

**Architecture:** Same shape as Phases 1–3b/2b. Hand-written `ApiClient` methods + plain-Dart models with `fromJson`, one `CommunityRepository` thin wrapper, Riverpod `AsyncNotifier`s for the feed (paginated, with local optimistic mutation for reactions/boost/delete) and post detail, plain `FutureProvider`s for the read-only rails (challenges, Best Play, statuses, top members, upcoming events, gallery, stats). Every idempotent write reuses the existing generic `WriteFlow` (`lib/core/utils/write_flow.dart`, built in Phase 2b) — no new Idempotency-Key machinery. Screens are `ConsumerWidget`s. New code lives in `lib/features/community/`.

**Tech Stack:** Flutter (stable), Dart ^3.11, `flutter_riverpod` ^3.3 (manual providers), `go_router` ^17, `dio`, `supabase_flutter`, `image_picker` (already a dependency since Phase 2b). **One new dev dependency: `fake_async`**, to deterministically test the realtime debounce helper (Task 4).

**Spec:** web repo (`C:\Users\gorok\Videos\sentinelx`) `docs/superpowers/specs/2026-09-27-mobile-phase4-community-design.md` (binding in full — §2 current-state table, §3 read-path ruling, §4 every write endpoint's exact idempotency/error contract, §5 the new `community_content_reports` table, §6 the moderation-scope ruling, §7 the realtime plan, §8 the eight numbered Rulings). Wire shapes are defined field-for-field by the real committed web files: `lib/mobile-api/endpoints/community-reads.ts` and `community-writes.ts` (zod schemas — authoritative over the spec's prose) on `sentinelx` `main`. Master spec: `docs/superpowers/specs/2026-09-18-flutter-mobile-app-master-design.md` §8.9, §2.4 (public-read), §2.5 (S1–S3 — do not widen direct `profiles` reads). Stage B handoff: `docs/agent-handoffs/2026-09-28-mobile-phase4-web-endpoints-notes.md` (Ruling 4 in that note: `GET /community/posts/{id}/comments` reuses `fetchPostDetail`, capped at 50 rows, no separate pagination). **Read this repo's `CLAUDE.md` and `AGENTS.md` first.** Template for structure/depth: `docs/superpowers/plans/2026-09-26-mobile-phase2b-flutter-screens.md` (its `WriteFlow`, `lib/features/match/evidence.dart`, `rating_sheet.dart`/`wager_sheet.dart` and `match_error_copy.dart` are reused directly here, not rebuilt).

## Global Constraints

- **Writes only through `ApiClient`** (`/api/mobile/v1/community/*`). **One sanctioned Storage exception**, mirroring Phase 2b's evidence screenshot: compose/status images upload straight to the **public** Supabase Storage bucket `community-images` at path `{userId}/{epochMs}-{safeName}` (the bucket's insert policy only requires the first path segment to equal `auth.uid()`; see `supabase/migrations/016_community.sql` in the web repo). Unlike the private `match-evidence` bucket, the API is given the resulting **public URL** (`storage.from('community-images').getPublicUrl(path)`), not a private path — `POST /community/posts`'s `imageUrls` field is `string[]` of URLs, matching the website's own `PostComposer.tsx` exactly. Ledger it as a Ruling in the PR, same as Phase 2b did for `match-evidence`.
- **Reads:** every Community read goes through `/api/mobile/v1/*` (spec §3, Ruling 4) — **no direct-Supabase reads of `community_posts`/`post_comments`/etc.** The only direct-Supabase calls this phase makes are the four realtime `postgres_changes` subscriptions (Task 4) — subscriptions, not reads; every event they observe triggers a debounced refetch of the matching `GET` endpoint, never a client-side merge of the raw changed row. Never read `profiles` directly (S1/S2 — CLAUDE.md §"Key facts").
- **Every new `ApiClient` method is listed in `ApiClient.usedOperations`**, checked against `api/openapi.json` by `test/core/api_contract_test.dart`. On `master`, `api/openapi.json` is a **straight copy** of the web repo's regenerated `openapi/mobile-v1.json` (no union-branch complication — Phase 4 is the only outstanding contract addition; verify this before copying, per Task 0).
- **Idempotency-Key policy (exact, reusing Phase 2b's `WriteFlow` verbatim — do not reimplement):** every `idempotent: true` endpoint per the web spec needs the header: `POST /community/posts`, `POST /community/posts/{id}/boost`, `PUT /community/posts/{id}/reaction`, `POST /community/posts/{id}/comments`, `POST /community/statuses`, `POST /community/best-play/{nominationId}/vote`, `POST /community/posts/{id}/report`, `POST /community/comments/{id}/report`. Everything else (`DELETE /community/posts/{id}`, `DELETE /community/posts/{id}/reaction`, `DELETE /community/comments/{id}`, `DELETE /community/statuses/{id}`, `POST /community/statuses/{id}/view`) is naturally idempotent — no key, exactly per the web spec §4. One key per attempt; reuse it only when the previous outcome was `ApiException.code` `network`, `idempotency_in_progress` (409) or `bad_response`; any other error mints a fresh key on the next attempt; success clears the key. `WriteFlow.run`'s `fingerprint` parameter (added since the 2b plan was written — see the real `lib/core/utils/write_flow.dart`) must be passed on every call whose payload can change between attempts (a different reaction, a different report reason, edited compose text/images), so an edited retry after a kept key never replays the server's response to the old values.
- **No Dart copy of server logic.** Never recompute reaction-count totals from raw rows, boost-liveness/24h-expiry, voting-window-open math, weekly-challenge progress, or feed ordering — render exactly what the API returns, and **after boost or Best Play vote succeeds, invalidate and refetch** the affected provider rather than reordering/incrementing locally (the server's `isBoostLive`/tally logic is the only correct source — see the Stage B handoff's own comment about the "3-week-stale-boost bug"). **One narrow, explicitly-scoped exception (Ruling, Task 5):** a reaction tap applies a same-turn optimistic ±1 delta to `reactionCounts` for the caller's own reaction slot only (mirrors the existing `followerDeltaProvider` pattern in `lib/features/players/players_providers.dart`), with rollback on failure — this is not recomputing aggregate business logic, it's a trivially-correct delta for exactly one user's exactly-one-slot change, and any drift self-heals on the next realtime-triggered refetch.
- **Realtime architecture decision (read before Task 4):** Phase 4 stays on the **disposable-per-screen** subscription pattern documented in `lib/core/notifications/unread_counts.dart`, not a new general-purpose cross-app channel manager. That comment defers the shared manager until the app has **three** real consumers "to design against (bell, DMs, feed)" — DMs is still Phase 5 (unbuilt), so Community is only the *second* real consumer at the app level; building a general manager now would be speculative design against a third consumer that doesn't exist yet, the same bar the precedent itself sets. What Phase 4 *does* add, because it's a genuine need this phase has and the bell didn't: a small **feature-internal** (not cross-app) helper, `debouncedChangeSignal` (Task 4), that merges several `postgres_changes` streams into one 400ms-debounced refetch trigger — because both the feed screen (4 channels) and the post-detail screen (2 channels) need the identical merge-and-debounce logic, and writing it twice would duplicate exactly the kind of logic the shared-manager precedent is about not duplicating. This stays scoped to `lib/features/community/`; it does not touch the bell or become a new app-wide provider.
- **Copy is never hard-coded in widgets.** The web repo's `messages/en.json` has **no existing `community` namespace** beyond a two-line nav label (checked directly: `grep -n '"community"' messages/en.json` returns only nav-menu entries) — per AGENTS.md rule 6, add every new key directly to `lib/core/l10n/app_en.arb` **and** `app_fr.arb` (`test/core/l10n_test.dart` requires identical key sets), run `flutter gen-l10n`, never edit `lib/core/l10n/gen/*` by hand. New keys use the `cmt` prefix (avoids collision with `cmp` — Compete — already in use). Server `error.message` strings are English and are never shown directly: map `error.code` to ARB copy via `communityErrorCopy` (Task 2), falling back to a generic message, mirroring `matchErrorCopy`.
- **Mobile-first at 375px**, no horizontal overflow (long usernames, 500-char posts, 5-image galleries, empty content-only-image posts). `SxColors` only; no new colors. American spelling. Reuse the existing `PlayerAvatar` shared widget (`lib/shared/widgets/player_avatar.dart`) for every author avatar — do not build a new one.
- **Testing against production is forbidden.** The `community_content_reports` table and the `community_posts` realtime-publication grant (both from Stage B's migration `20260928120000_community_content_reports.sql`) are **not applied to any database yet** (confirmed in the Stage B handoff's "Not verified" section) — this blocks a live device pass on report submission and on `community_posts` INSERT realtime specifically (every other table this phase reads/subscribes to is already live), not the Flutter build itself, since every test in this plan runs against a `_FakeAdapter`/fake repository, never live Supabase. Flag this explicitly in the final Stage D report as a **pre-existing blocker outside this plan's scope**, not something to route around.
- **Before every commit:** `flutter analyze` (no issues) and `flutter test` (all pass — baseline on `master` at plan-writing time: **555 tests, clean analyze**, commit `63cee4f`). Regenerate l10n after ARB edits and commit the generated output. After `flutter pub get`/`flutter test`, run `git checkout -- linux macos windows` before committing.

## Review Focus

Failure modes the spec implies that are easy to ship broken, most likely first. Each has a test in the task that owns the code.

1. **Signed-out users see read content but never write affordances silently no-op**: feed/post-detail/gallery/top-members/upcoming-events/stats/Best-Play banner are all `auth: 'public'` and must render fully for a guest; tapping react/comment/report/boost/compose/post-a-status/vote while signed out must redirect to `/login`, never send an unauthenticated request that 401s silently. (Tasks 5, 6, 7, 8, 9, 10, 11)
2. **A retried write after a kept Idempotency-Key must never double-apply, and an edited retry must never replay the old payload's stored response** — covered structurally by reusing `WriteFlow`/its `fingerprint` param, but each write call site must actually pass the right fingerprint (reaction value, report reason+note, compose content+image set, status content). (Tasks 5, 6, 8, 9, 10, 11)
3. **Upload succeeded, POST failed**: a compose/status retry must not re-upload images already uploaded in a prior attempt of the same picked set, and must not lose the picked images; a failed *upload* must say so distinctly from a failed *post*. (Tasks 6, 10)
4. **Boost/vote/report business errors must render their own specific copy, not a generic failure**: `insufficient_coins`, `active_boost_exists`, `already_boosted` (boost); `voting_closed`, `already_voted` (Best Play); `already_reported` (report) — each is a real, expected state a player will hit, not an edge case to lump into `cmtEcGeneric`. (Tasks 9, 11)
5. **Odd/empty data renders correctly, not blank or crashing**: a post with images but no text, a post with text but no images, a `match_result`/`achievement`/`announcement` post (no delete/boost affordance — `canDelete`/`canBoost` come from the server, never inferred client-side from post type), an empty feed, an empty gallery, a status ring with no unseen statuses, a Best Play/Challenges response that is `null` (spec's nullable top-level responses), a comments list at the 50-row cap with no "load more" affordance (Stage B Ruling 4 — there is no pagination for comments). (Tasks 1, 7, 8, 10)

## Coordination (shared-file hotspots)

- **Base: `master`** (`63cee4f` at plan-writing time — the registration-fields contract fix is already merged; the 2a/2b/3a/3b integration is already merged). No other Phase 4 worktree exists yet. Build on a new branch `phase4/screens` cut from `master` in a new worktree `sentinelx_mobile-p4` (Task 0).
- **Other live worktrees, do not touch:** `-p2a`, `-p2b`, `-p3a`, `-p3b`, `-integration`, `-auth-hardening`, `-regfields`.
- Hotspots shared with any future parallel work: `lib/core/api/api_client.dart` (append methods + `usedOperations` lines only), `api/openapi.json` (straight copy from the web repo per Task 0 — do not hand-edit), `lib/router/app_router.dart` (add routes only, replace the `/community` `ComingSoonScreen` branch in place), `lib/core/routing/web_links.dart` (add one case), ARB files + generated l10n. **Never rewrite or reformat those files** — keep every hunk minimal and match surrounding style, per every prior phase's own hard-won lesson (3a's whole-file reformat cost a hand-resolved merge once).
- `home_screen.dart` is **not** touched this phase — Community is a bottom-tab screen, not a Home widget (master spec's Phase 1 route table has no Community entry on Home), unlike Phase 2b's `FixturesCard`.

## Deferred / known gaps (record in the PR, do not build)

- All staff moderation: pin/announce/delete-any, the report review queue, Best Play nomination/confirm, challenge CRUD — Phase 8's (spec §6, Ruling 7, master spec §8.24).
- Threaded comments — the schema has no `parent_comment_id`; comments are flat (spec Ruling 1).
- A player-initiated "submit weekly-challenge progress" action — there isn't one; `GET /community/challenges` is the entire client surface (spec Ruling 2).
- Editing a compose/status submission — the app requires a fresh submit; there is no edit-post/edit-comment endpoint.
- A live device/E2E pass on report submission and on `community_posts` INSERT realtime — blocked on the unapplied Stage B migration (see Global Constraints).

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/api/community_models.dart` (create) | Every response/request model, `fromJson` only: `PlayerRef`, `MatchResultDetail`, `ReactionType`, `ReactionCounts`, `PostType`, `PostView`, `CommentView`, `CommunityFeedPage`, `CommunityPostDetail`, `ChallengeProgress`, `ChallengesWidget`, `BestPlayNomination`, `BestPlayBanner`, `StatusRow`, `StatusRing`, `StatusViewer`, `TopMember`, `UpcomingEvent`, `GalleryItem`, `CommunityGalleryPage`, `CommunityStats`, `ReportReasonCode` |
| `lib/core/api/api_client.dart` (modify) | 24 methods + `usedOperations` lines (append) |
| `lib/features/community/community_repository.dart` (create) | `CommunityRepository` (abstract) + `ApiCommunityRepository`, thin wrapper over the 24 `ApiClient` calls |
| `lib/features/community/community_error_copy.dart` (create) | `communityErrorCopy(l10n, code)` |
| `lib/features/community/community_providers.dart` (create) | `communityRepositoryProvider`, `communityFeedProvider` (+ `CommunityFeedNotifier`, `CommunityFeedState`), `communityPostDetailProvider` (+ `CommunityPostDetailNotifier`), `communityChallengesProvider`, `communityBestPlayProvider`, `communityStatusRingsProvider`, `communityStatusViewersProvider`, `communityTopMembersProvider`, `communityUpcomingEventsProvider`, `communityGalleryProvider`, `communityStatsProvider` |
| `lib/features/community/community_realtime.dart` (create) | `debouncedChangeSignal`, `feedChangeSignal`, `postDetailChangeSignal`, `communityFeedRealtimeProvider`, `communityPostDetailRealtimeProvider` |
| `lib/features/community/community_image_uploader.dart` (create) | `communityImagePath`, `CommunityImageUploader` + Supabase impl, `MultiImagePickerPort` + plugin impl, providers |
| `lib/features/community/compose_submitter.dart` (create) | `CommunityPostSubmitter` (upload-once-per-image-set memo, mirrors `ResultSubmitter`) |
| `lib/features/community/reaction_bar.dart` (create) | `ReactionBar` widget + `PostViewReaction` extension (optimistic `withMyReaction`) |
| `lib/features/community/community_feed_screen.dart` (create) | Feed: status tray, challenges rail, Best Play banner, pinned + paginated posts, discover section (top members/upcoming events/gallery/stats), realtime, pull-to-refresh/load-more |
| `lib/features/community/post_card.dart` (create) | Shared post card (feed + gallery use a compact variant; post detail uses the full one) |
| `lib/features/community/compose_screen.dart` (create) | New post: text + up to 5 images |
| `lib/features/community/post_detail_screen.dart` (create) | Post + comments, comment compose, delete post/comment, realtime |
| `lib/features/community/boost_sheet.dart` (create) | Boost confirm sheet (200 coins) |
| `lib/features/community/status_tray.dart`, `status_viewer_screen.dart`, `status_compose_screen.dart`, `status_viewers_screen.dart` (create) | Stories: tray, full-screen viewer, compose, author-only viewer list |
| `lib/features/community/report_sheet.dart` (create) | Report reason-picker sheet (post + comment) |
| `lib/core/l10n/app_en.arb`, `app_fr.arb` (modify) | New `cmt*` keys (Task 2) |
| `lib/router/app_router.dart` (modify) | Replace the `/community` `ComingSoonScreen` branch; add compose/detail/status routes (Task 12) |
| `lib/core/routing/web_links.dart` (modify) | `/community/<postId>` (Task 12) |
| `pubspec.yaml`, `pubspec.lock` (modify) | `fake_async` dev dependency (Task 0) |
| `test/…` beside each | Fixtures in `test/support/community_fixtures.dart`; fakes in `test/fakes/fake_community_repository.dart`, `test/fakes/fake_community_uploader.dart` |

---

### Task 0: Worktree, base, contract copy, dependency, live checks

**Files:** `api/openapi.json`, `pubspec.yaml`.

- [ ] **Step 1: Create the worktree**

```bash
cd C:\Users\gorok\sentinelx_mobile
git fetch origin
git log origin/master --oneline -3
git worktree add ..\sentinelx_mobile-p4 -b phase4/screens origin/master
cd ..\sentinelx_mobile-p4
flutter pub get
flutter analyze && flutter test
```
Expected: clean analyze, **555 tests passing** (the `master` baseline this plan was written against). If the count differs because `master` has moved on, that's fine as long as it's green — if it's red, stop and report; do not build on a red base.

- [ ] **Step 2: Confirm the pieces this plan consumes from earlier phases**

```bash
findstr /c:"class WriteFlow" lib\core\utils\write_flow.dart
findstr /c:"String newIdempotencyKey" lib\core\utils\idempotency_key.dart
findstr /c:"class PickedImage" lib\features\match\evidence.dart
findstr /c:"class PlayerAvatar" lib\shared\widgets\player_avatar.dart
findstr /c:"_withQuery" lib\core\api\api_client.dart
findstr /c:"competeBaseOverrides" test\support\pump_compete.dart
```
Each must print a match. If a name differs from what this plan says, use the real one everywhere this plan says it.

- [ ] **Step 3: Copy the contract**

The web repo checkout is `C:\Users\gorok\Videos\sentinelx` on this machine (per the Stage A/B/C kickoff note). Confirm it's on `main` with Stage B's commits, then copy its regenerated contract straight over this worktree's `api/openapi.json`:

```bash
git -C C:\Users\gorok\Videos\sentinelx log --oneline -3
findstr /c:"getCommunityFeed" C:\Users\gorok\Videos\sentinelx\openapi\mobile-v1.json
copy /Y C:\Users\gorok\Videos\sentinelx\openapi\mobile-v1.json api\openapi.json
```
Unlike Phase 2b, there is no multi-branch union to preserve here — `master`'s existing contract already came from a single merged web `main`, so a straight copy (not an append-only union) is correct. After copying, verify every operationId this plan's `ApiClient` will call is present:

```bash
findstr /c:"getCommunityFeed" /c:"getCommunityPost" /c:"getCommunityPostComments" /c:"getCommunityChallenges" /c:"getCommunityBestPlay" /c:"getCommunityStatuses" /c:"getCommunityStatusViewers" /c:"getCommunityTopMembers" /c:"getCommunityUpcomingEvents" /c:"getCommunityGallery" /c:"getCommunityStats" /c:"postCommunityPost" /c:"deleteCommunityPost" /c:"postCommunityPostBoost" /c:"putCommunityPostReaction" /c:"deleteCommunityPostReaction" /c:"postCommunityComment" /c:"deleteCommunityComment" /c:"postCommunityStatus" /c:"deleteCommunityStatus" /c:"postCommunityStatusView" /c:"postCommunityBestPlayVote" /c:"postCommunityPostReport" /c:"postCommunityCommentReport" api\openapi.json
```
All 24 must match. If any is missing, **stop and report** — do not hand-write contract entries.

- [ ] **Step 4: Add the `fake_async` dev dependency**

```bash
flutter pub add --dev fake_async
flutter pub get
flutter analyze
```
Used only by Task 4's debounce-merge test, the same way Phase 2b added `image_picker` as a real dependency for its own new need. Commit `pubspec.*` with Task 1.

- [ ] **Step 5: Live checks (read-only, staging project `ofxmoxpvwbemfouaowoa` only — per AGENTS.md never test writes against production)**

Supabase MCP `execute_sql`:

```sql
select id, public from storage.buckets where id = 'community-images';
select table_name, count(*) as cols from information_schema.columns
 where table_schema = 'public' and table_name in ('community_posts', 'post_reactions', 'post_comments', 'player_statuses')
 group by table_name order by table_name;
select to_regclass('public.community_content_reports') as report_table_exists;
```
Expected: `community-images` → one row, `public = true` (confirms the compose/status image-upload bucket already exists and is public, per `016_community.sql`). The four Community tables all return non-zero column counts (they're long-standing tables; Stage B's own reads/writes already depend on them existing). `report_table_exists` is expected to be **`null`** — the Stage B migration adding `community_content_reports` has not been applied anywhere yet (see Global Constraints); this is not a blocker for building the Flutter code (Task 11's tests never hit a live database), only for a live device pass on report submission, which must be flagged in the final report, not silently worked around.

---

### Task 1: Contract models and client methods

**Files:**
- Create: `lib/core/api/community_models.dart`, `test/core/community_models_test.dart`, `test/core/api_client_community_test.dart`, `test/support/community_fixtures.dart`
- Modify: `lib/core/api/api_client.dart`

**Interfaces:**
- Produces (every class has `factory X.fromJson(Map<String, dynamic> j)`, field names are the Dart names — the JSON keys are identical camelCase, per `lib/mobile-api/endpoints/community-reads.ts`/`community-writes.ts`, so no snake_case translation is needed anywhere in this file, unlike `match_models.dart`):

```dart
enum ReactionType { fire, crown, strong, wow }
extension ReactionTypeWire on ReactionType {
  String get wireName => name;
}
ReactionType reactionTypeFromJson(String s) => switch (s) {
      'fire' => ReactionType.fire,
      'crown' => ReactionType.crown,
      'strong' => ReactionType.strong,
      'wow' => ReactionType.wow,
      _ => throw FormatException('Unknown reaction: $s'),
    };

enum PostType { manual, matchResult, achievement, announcement }
PostType postTypeFromJson(String s) => switch (s) {
      'manual' => PostType.manual,
      'match_result' => PostType.matchResult,
      'achievement' => PostType.achievement,
      'announcement' => PostType.announcement,
      _ => throw FormatException('Unknown post type: $s'),
    };

enum ReportReasonCode { spam, harassment, hateSpeech, nudityOrSexualContent, violence, misinformation, other }
extension ReportReasonCodeWire on ReportReasonCode {
  String get wireName => switch (this) {
        ReportReasonCode.spam => 'spam',
        ReportReasonCode.harassment => 'harassment',
        ReportReasonCode.hateSpeech => 'hate_speech',
        ReportReasonCode.nudityOrSexualContent => 'nudity_or_sexual_content',
        ReportReasonCode.violence => 'violence',
        ReportReasonCode.misinformation => 'misinformation',
        ReportReasonCode.other => 'other',
      };
}

class PlayerRef {
  const PlayerRef({this.id, this.username, this.displayName, this.avatarUrl, required this.membershipTier, this.sentinelTier, this.frameUrl});
  final String? id, username, displayName, avatarUrl, sentinelTier, frameUrl;
  final String membershipTier;
  String get name => displayName ?? username ?? '—';
}

class MatchResultDetail {
  const MatchResultDetail({required this.matchId, required this.tournamentTitle, required this.roundLabel, this.scoreA, this.scoreB, this.playerA, this.playerB, this.scheduledAt});
  final String matchId, tournamentTitle, roundLabel;
  final int? scoreA, scoreB;
  final PlayerRef? playerA, playerB;
  final String? scheduledAt;
}

class ReactionCounts {
  const ReactionCounts({required this.fire, required this.crown, required this.strong, required this.wow});
  final int fire, crown, strong, wow;
  int get total => fire + crown + strong + wow;
  int operator [](ReactionType t) => switch (t) {
        ReactionType.fire => fire,
        ReactionType.crown => crown,
        ReactionType.strong => strong,
        ReactionType.wow => wow,
      };
  ReactionCounts _with(ReactionType t, int delta) => switch (t) {
        ReactionType.fire => ReactionCounts(fire: fire + delta, crown: crown, strong: strong, wow: wow),
        ReactionType.crown => ReactionCounts(fire: fire, crown: crown + delta, strong: strong, wow: wow),
        ReactionType.strong => ReactionCounts(fire: fire, crown: crown, strong: strong + delta, wow: wow),
        ReactionType.wow => ReactionCounts(fire: fire, crown: crown, strong: strong, wow: wow + delta),
      };
  ReactionCounts increment(ReactionType t) => _with(t, 1);
  ReactionCounts decrement(ReactionType t) => _with(t, -1);
}

class PostView {
  const PostView({
    required this.id, required this.postType, required this.content, this.imageUrl, required this.imageUrls,
    this.referenceId, required this.isPinned, this.boostedUntil, required this.createdAt, required this.author,
    required this.canDelete, required this.canBoost, required this.reactionCounts, this.myReaction,
    required this.commentCount, this.matchResult, required this.mutedByViewer,
  });
  final String id, content, createdAt;
  final PostType postType;
  final String? imageUrl, referenceId, boostedUntil;
  final List<String> imageUrls;
  final bool isPinned, canDelete, canBoost, mutedByViewer;
  final PlayerRef author;
  final ReactionCounts reactionCounts;
  final ReactionType? myReaction;
  final int commentCount;
  final MatchResultDetail? matchResult;

  PostView copyWith({ReactionCounts? reactionCounts, ReactionType? myReaction, bool clearMyReaction = false, int? commentCount}) => PostView(
        id: id, postType: postType, content: content, imageUrl: imageUrl, imageUrls: imageUrls, referenceId: referenceId,
        isPinned: isPinned, boostedUntil: boostedUntil, createdAt: createdAt, author: author, canDelete: canDelete, canBoost: canBoost,
        reactionCounts: reactionCounts ?? this.reactionCounts,
        myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
        commentCount: commentCount ?? this.commentCount, matchResult: matchResult, mutedByViewer: mutedByViewer,
      );
}

class CommentView {
  const CommentView({required this.id, required this.content, required this.createdAt, required this.author, required this.canDelete});
  final String id, content, createdAt;
  final PlayerRef author;
  final bool canDelete;
}

class CommunityFeedPage {
  const CommunityFeedPage({required this.pinned, required this.posts, required this.hasMore});
  final List<PostView> pinned, posts;
  final bool hasMore;
}

class CommunityPostDetail {
  const CommunityPostDetail({required this.post, required this.comments});
  final PostView post;
  final List<CommentView> comments;
}

class ChallengeProgress {
  const ChallengeProgress({required this.slug, required this.title, required this.description, required this.goal, required this.progress, required this.completed, required this.coinReward, required this.xpReward});
  final String slug, title, description;
  final int goal, progress, coinReward, xpReward;
  final bool completed;
}

class ChallengesWidget {
  const ChallengesWidget({required this.weekLabel, required this.challenges});
  final String weekLabel;
  final List<ChallengeProgress> challenges;
}

class BestPlayNomination {
  const BestPlayNomination({required this.nominationId, required this.postId, required this.content, required this.authorName, required this.voteCount});
  final String nominationId, postId, content, authorName;
  final int voteCount;
}

class BestPlayBanner {
  const BestPlayBanner({required this.nominations, this.myVoteNominationId});
  final List<BestPlayNomination> nominations;
  final String? myVoteNominationId;
}

class StatusRow {
  const StatusRow({required this.id, required this.playerId, this.imageUrl, this.caption, required this.createdAt, required this.expiresAt, required this.authorName, this.authorUsername, this.authorAvatarUrl});
  final String id, playerId, createdAt, expiresAt, authorName;
  final String? imageUrl, caption, authorUsername, authorAvatarUrl;
}

class StatusRing {
  const StatusRing({required this.playerId, required this.authorName, this.authorUsername, this.authorAvatarUrl, required this.statuses, required this.hasUnseen, required this.isSelf, required this.latestAt});
  final String playerId, authorName, latestAt;
  final String? authorUsername, authorAvatarUrl;
  final List<StatusRow> statuses;
  final bool hasUnseen, isSelf;
}

class StatusViewer {
  const StatusViewer({required this.viewerId, required this.name, this.username, this.avatarUrl, required this.viewedAt});
  final String viewerId, name, viewedAt;
  final String? username, avatarUrl;
}

class TopMember {
  const TopMember({required this.rank, required this.id, this.username, this.displayName, this.avatarUrl, required this.membershipTier, required this.xp, this.frameUrl});
  final int rank, xp;
  final String id, membershipTier;
  final String? username, displayName, avatarUrl, frameUrl;
  String get name => displayName ?? username ?? '—';
}

class UpcomingEvent {
  const UpcomingEvent({required this.id, required this.title, required this.date, required this.time, required this.ctaLabel, required this.ctaHref});
  final String id, title, date, time, ctaLabel, ctaHref;
}

class GalleryItem {
  const GalleryItem({required this.id, required this.imageUrl, required this.caption, required this.authorName});
  final String id, imageUrl, caption, authorName;
}

class CommunityGalleryPage {
  const CommunityGalleryPage({required this.items, required this.hasMore});
  final List<GalleryItem> items;
  final bool hasMore;
}

class CommunityStats {
  const CommunityStats({required this.memberCount, required this.countryCount, required this.tournamentCount});
  final int memberCount, countryCount, tournamentCount;
}

// ApiClient additions (all await the standard `_send`; every idempotent write takes
// `required String idempotencyKey` -> header `Idempotency-Key`; every read except
// getCommunityChallenges/getCommunityStatusViewers is `publicRequest: true`):
Future<CommunityFeedPage> getCommunityFeed({int offset = 0, int limit = 20});
Future<CommunityPostDetail> getCommunityPost(String id);
Future<List<CommentView>> getCommunityPostComments(String id);
Future<ChallengesWidget?> getCommunityChallenges();
Future<BestPlayBanner?> getCommunityBestPlay();
Future<List<StatusRing>> getCommunityStatuses();
Future<List<StatusViewer>> getCommunityStatusViewers(String id);
Future<List<TopMember>> getCommunityTopMembers();
Future<List<UpcomingEvent>> getCommunityUpcomingEvents();
Future<CommunityGalleryPage> getCommunityGallery({int offset = 0, int limit = 8});
Future<CommunityStats> getCommunityStats();
Future<String> postCommunityPost({required String content, required List<String> imageUrls, required String idempotencyKey});
Future<void> deleteCommunityPost(String id);
Future<void> postCommunityPostBoost(String id, {required String idempotencyKey});
Future<ReactionType> putCommunityPostReaction(String id, {required ReactionType reaction, required String idempotencyKey});
Future<void> deleteCommunityPostReaction(String id);
Future<String> postCommunityComment(String postId, {required String content, required String idempotencyKey});
Future<void> deleteCommunityComment(String id);
Future<String> postCommunityStatus({String? imageUrl, String? caption, required String idempotencyKey});
Future<void> deleteCommunityStatus(String id);
Future<void> postCommunityStatusView(String id);
Future<void> postCommunityBestPlayVote(String nominationId, {required String idempotencyKey});
Future<void> postCommunityPostReport(String id, {required ReportReasonCode reasonCode, String? note, required String idempotencyKey});
Future<void> postCommunityCommentReport(String id, {required ReportReasonCode reasonCode, String? note, required String idempotencyKey});
```

`operationId -> 'method /path'` lines to append to `usedOperations`: `getCommunityFeed: get /api/mobile/v1/community/feed`, `getCommunityPost: get /api/mobile/v1/community/posts/{id}`, `getCommunityPostComments: get /api/mobile/v1/community/posts/{id}/comments`, `getCommunityChallenges: get /api/mobile/v1/community/challenges`, `getCommunityBestPlay: get /api/mobile/v1/community/best-play`, `getCommunityStatuses: get /api/mobile/v1/community/statuses`, `getCommunityStatusViewers: get /api/mobile/v1/community/statuses/{id}/viewers`, `getCommunityTopMembers: get /api/mobile/v1/community/top-members`, `getCommunityUpcomingEvents: get /api/mobile/v1/community/upcoming-events`, `getCommunityGallery: get /api/mobile/v1/community/gallery`, `getCommunityStats: get /api/mobile/v1/community/stats`, `postCommunityPost: post /api/mobile/v1/community/posts`, `deleteCommunityPost: delete /api/mobile/v1/community/posts/{id}`, `postCommunityPostBoost: post /api/mobile/v1/community/posts/{id}/boost`, `putCommunityPostReaction: put /api/mobile/v1/community/posts/{id}/reaction`, `deleteCommunityPostReaction: delete /api/mobile/v1/community/posts/{id}/reaction`, `postCommunityComment: post /api/mobile/v1/community/posts/{id}/comments`, `deleteCommunityComment: delete /api/mobile/v1/community/comments/{id}`, `postCommunityStatus: post /api/mobile/v1/community/statuses`, `deleteCommunityStatus: delete /api/mobile/v1/community/statuses/{id}`, `postCommunityStatusView: post /api/mobile/v1/community/statuses/{id}/view`, `postCommunityBestPlayVote: post /api/mobile/v1/community/best-play/{nominationId}/vote`, `postCommunityPostReport: post /api/mobile/v1/community/posts/{id}/report`, `postCommunityCommentReport: post /api/mobile/v1/community/comments/{id}/report`.

- [ ] **Step 1: Fixtures** — `test/support/community_fixtures.dart` exports `Map<String, dynamic>` builders with sensible defaults: `playerRefJson({...})`, `postViewJson({id, postType = 'manual', content, imageUrls = const [], isPinned = false, boostedUntil, canDelete = true, canBoost = true, myReaction, commentCount = 0, matchResult})`, `commentViewJson({...})`, `feedPageJson({pinned = const [], posts, hasMore = false})`, `challengesJson()`, `bestPlayJson()`, `statusRingJson()`, `galleryPageJson()`, `communityStatsJson()`. Every later test file uses these.

- [ ] **Step 2: Write the failing model tests** — `test/core/community_models_test.dart`. Cover (each its own `test`):
  1. `PostView.fromJson` round-trips every field, including `imageUrl: null`/`imageUrls: []` (text-only post) and `matchResult: null`.
  2. `postType` parses all four wire values; an unknown value throws `FormatException`.
  3. `reactionTypeFromJson` parses `fire|crown|strong|wow`; unknown throws.
  4. `ReactionCounts.increment`/`decrement` return a new instance with only the targeted field changed; `[]` operator reads the right field per `ReactionType`.
  5. `CommunityFeedPage.fromJson` with a non-empty `pinned` and `hasMore: true`.
  6. `ChallengesWidget?`/`BestPlayBanner?`: both parse from a real object and are `null` when the raw response is JSON `null` (test via the `ApiClient` parse callback, not the model's own `fromJson`, since the nullability lives in the client wrapper — see Step 3).
  7. `StatusRing` with an empty `statuses` list and `hasUnseen: false`.
  8. `CommunityGalleryPage`/`CommunityStats` parse.
  9. `ReportReasonCode.wireName` round-trips all seven values exactly to the spec's wire strings (`nudity_or_sexual_content`, `hate_speech` — the two multi-word ones are the easiest to typo).

- [ ] **Step 3: Write the failing client tests** — `test/core/api_client_community_test.dart` (copy the `_FakeAdapter`/`_json`/`_client`/`_ok` helpers from `test/core/api_client_match_test.dart`). Cover:
  - `getCommunityFeed()` hits `/api/mobile/v1/community/feed` with no query params by default; `getCommunityFeed(offset: 20, limit: 10)` sends both as query params.
  - `getCommunityPost`, `getCommunityPostComments` hit `/community/posts/p1` and `/community/posts/p1/comments`.
  - `getCommunityChallenges()` returns `null` when the fake server returns `{data: null}`, and a real `ChallengesWidget` otherwise.
  - `getCommunityBestPlay()` same null-handling.
  - `getCommunityGallery(offset: 8, limit: 8)` sends both query params; default call sends neither.
  - `postCommunityPost` sends the `Idempotency-Key` header and body `{content, imageUrls}`.
  - `putCommunityPostReaction` sends body `{reaction: 'crown'}` and the header, and parses the response's `{reaction: 'crown'}` back to `ReactionType.crown`.
  - `deleteCommunityPostReaction`, `postCommunityStatusView` send **no** `Idempotency-Key` header.
  - `postCommunityPostReport` sends body `{reasonCode: 'hate_speech', note: 'x'}` and, when `note` is omitted, a body with no `note` key at all (mirrors `postAuthSignup`'s `?ref` pattern — never send `null`).
  - An error envelope (`{error: {code: 'insufficient_coins', message: 'x'}}`, 400) from `postCommunityPostBoost` throws `ApiException(code: 'insufficient_coins', status: 400)`.

- [ ] **Step 4: Run to verify failure**

Run: `flutter test test/core/community_models_test.dart test/core/api_client_community_test.dart`
Expected: FAIL (`community_models.dart` not found / methods not defined).

- [ ] **Step 5: Implement `lib/core/api/community_models.dart`** exactly per the Interfaces block above. Use the same defensive-but-strict helpers already established in `match_models.dart` (`_list<T>`, `_obj`, `_int`, `_intOrNull`) — import or duplicate them; do not invent a third variant.

- [ ] **Step 6: Implement the 24 client methods** in `api_client.dart` (append after the Phase 2b block). Use the existing `_withQuery` helper for the two paginated GETs; `Uri.encodeComponent` every path segment. Nullable top-level responses parse as `(d) => d == null ? null : X.fromJson(d as Map<String, dynamic>)` — note the cast target changes from `d!` (non-null assert) to a plain `as` cast once `d` is allowed to be null.

- [ ] **Step 7: Run tests + contract test**

Run: `flutter test test/core/community_models_test.dart test/core/api_client_community_test.dart test/core/api_contract_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add pubspec.yaml pubspec.lock api/openapi.json lib/core/api test/core test/support
git commit -m "feat(api): Phase 4 Community contract models and client methods"
```

---

### Task 2: Copy (ARB en + fr) and error-code copy

**Files:**
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_fr.arb`
- Create: `lib/features/community/community_error_copy.dart`, `test/features/community/community_error_copy_test.dart`

**Interfaces:**
- Produces: `String communityErrorCopy(AppLocalizations l10n, String code)` — never empty; unknown codes fall back to `l10n.cmtEcGeneric`.

- [ ] **Step 1: Add the keys.** Append to `app_en.arb` (mind commas) and the identical key set to `app_fr.arb`. French is machine-written; flag for native review in the PR, same disclaimer every prior phase used.

| Key | English | French |
|---|---|---|
| `cmtTitle` | Community | Communauté |
| `cmtFeedEmpty` | No posts yet. Be the first to share something! | Aucune publication pour l'instant. Soyez le premier à partager quelque chose ! |
| `cmtFeedLoadError` | Couldn't load the feed. | Impossible de charger le fil. |
| `cmtRetry` | Try again | Réessayer |
| `cmtLoadMore` | Load more | Charger plus |
| `cmtPinnedLabel` | Pinned | Épinglé |
| `cmtBoostedLabel` | Boosted | Boosté |
| `cmtComposeFab` | New post | Nouvelle publication |
| `cmtSignInToPost` | Log in to post | Connectez-vous pour publier |
| `cmtSignInToReact` | Log in to react | Connectez-vous pour réagir |
| `cmtSignInToComment` | Log in to comment | Connectez-vous pour commenter |
| `cmtSignInToVote` | Log in to vote | Connectez-vous pour voter |
| `cmtSignInToReport` | Log in to report | Connectez-vous pour signaler |
| `cmtCommentCount` | {count} comments | {count} commentaires (placeholder `count` int) |
| `cmtReactFire` | Fire | Feu |
| `cmtReactCrown` | Crown | Couronne |
| `cmtReactStrong` | Strong | Fort |
| `cmtReactWow` | Wow | Wow |
| `cmtMatchResultLabel` | Match result | Résultat du match |
| `cmtAchievementLabel` | Achievement | Succès |
| `cmtAnnouncementLabel` | Announcement | Annonce |
| `cmtComposeTitle` | New post | Nouvelle publication |
| `cmtComposeHint` | What's happening in the SentinelX community? | Que se passe-t-il dans la communauté SentinelX ? |
| `cmtComposeAddImage` | Add photo | Ajouter une photo |
| `cmtComposeImagesCount` | {count}/5 | {count}/5 (placeholder `count` int) |
| `cmtComposePost` | Post | Publier |
| `cmtComposePosting` | Posting… | Publication… |
| `cmtComposeCancel` | Cancel | Annuler |
| `cmtComposeValidation` | Write something or add a photo first. | Écrivez quelque chose ou ajoutez une photo. |
| `cmtComposeRemoveImage` | Remove image | Retirer l'image |
| `cmtPostDetailTitle` | Post | Publication |
| `cmtCommentsTitle` | Comments | Commentaires |
| `cmtCommentsEmpty` | No comments yet. | Aucun commentaire pour l'instant. |
| `cmtCommentsCapNotice` | Showing the first 50 comments. | Affichage des 50 premiers commentaires. |
| `cmtCommentHint` | Add a comment… | Ajouter un commentaire… |
| `cmtCommentSend` | Send | Envoyer |
| `cmtDeletePost` | Delete post | Supprimer la publication |
| `cmtDeletePostConfirm` | Delete this post? This can't be undone. | Supprimer cette publication ? Cette action est irréversible. |
| `cmtDeleteComment` | Delete comment | Supprimer le commentaire |
| `cmtDeleteCommentConfirm` | Delete this comment? | Supprimer ce commentaire ? |
| `cmtDeleteConfirmYes` | Delete | Supprimer |
| `cmtDeleteConfirmCancel` | Cancel | Annuler |
| `cmtBoostAction` | Boost (200 coins) | Booster (200 pièces) |
| `cmtBoostConfirmTitle` | Boost this post? | Booster cette publication ? |
| `cmtBoostConfirmBody` | Your post will be pinned to the top of the feed for 24 hours for 200 SX Coins. | Votre publication sera épinglée en haut du fil pendant 24 heures pour 200 SX Coins. |
| `cmtBoostConfirm` | Boost | Booster |
| `cmtBoostSuccess` | Post boosted! | Publication boostée ! |
| `cmtStatusesTitle` | Stories | Stories |
| `cmtStatusAddYours` | Your story | Votre story |
| `cmtStatusPost` | Post story | Publier la story |
| `cmtStatusCaptionHint` | Add a caption (optional) | Ajouter une légende (facultatif) |
| `cmtStatusEmpty` | No stories yet. | Aucune story pour l'instant. |
| `cmtStatusViewersTitle` | Viewers | Vues |
| `cmtStatusViewersEmpty` | No one has viewed this yet. | Personne n'a encore vu ceci. |
| `cmtStatusDelete` | Delete story | Supprimer la story |
| `cmtStatusDeleteConfirm` | Delete this story? | Supprimer cette story ? |
| `cmtStatusValidation` | Add a photo or a caption. | Ajoutez une photo ou une légende. |
| `cmtChallengesTitle` | Weekly challenges | Défis hebdomadaires |
| `cmtChallengesSignedOut` | Log in to track weekly challenges. | Connectez-vous pour suivre les défis hebdomadaires. |
| `cmtChallengeCompleted` | Completed | Terminé |
| `cmtChallengeProgress` | {progress}/{goal} | {progress}/{goal} (int, int) |
| `cmtBestPlayTitle` | Best Play of the Week | Meilleure action de la semaine |
| `cmtBestPlayEmpty` | No nominations this week. | Aucune nomination cette semaine. |
| `cmtBestPlayVote` | Vote | Voter |
| `cmtBestPlayVoted` | Voted | Voté |
| `cmtBestPlayVoteSuccess` | Vote recorded! | Vote enregistré ! |
| `cmtTopMembersTitle` | Top members | Meilleurs membres |
| `cmtUpcomingEventsTitle` | Upcoming events | Événements à venir |
| `cmtGalleryTitle` | Gallery | Galerie |
| `cmtStatsMembers` | {count} members | {count} membres (int) |
| `cmtStatsCountries` | {count} countries | {count} pays (int) |
| `cmtStatsTournaments` | {count} tournaments | {count} tournois (int) |
| `cmtReportPost` | Report post | Signaler la publication |
| `cmtReportComment` | Report comment | Signaler le commentaire |
| `cmtReportTitle` | Report content | Signaler ce contenu |
| `cmtReportReasonSpam` | Spam | Spam |
| `cmtReportReasonHarassment` | Harassment | Harcèlement |
| `cmtReportReasonHateSpeech` | Hate speech | Discours de haine |
| `cmtReportReasonNudity` | Nudity or sexual content | Nudité ou contenu sexuel |
| `cmtReportReasonViolence` | Violence | Violence |
| `cmtReportReasonMisinformation` | Misinformation | Désinformation |
| `cmtReportReasonOther` | Other | Autre |
| `cmtReportNoteHint` | Add details (optional) | Ajouter des détails (facultatif) |
| `cmtReportSubmit` | Submit report | Envoyer le signalement |
| `cmtReportSubmitted` | Report submitted. Thank you. | Signalement envoyé. Merci. |
| `cmtEcGeneric` | Something went wrong. Please try again. | Une erreur est survenue. Veuillez réessayer. |
| `cmtEcNetwork` | No connection. Check your internet and try again. | Pas de connexion. Vérifiez votre internet et réessayez. |
| `cmtEcSession` | Your session expired. Please log in again. | Votre session a expiré. Reconnectez-vous. |
| `cmtEcInProgress` | Still processing your request. Please wait a moment and try again. | Traitement en cours. Patientez un instant puis réessayez. |
| `cmtEcValidation` | Write something or add a photo first. | Écrivez quelque chose ou ajoutez une photo. |
| `cmtEcNotFound` | This content is no longer available. | Ce contenu n'est plus disponible. |
| `cmtEcForbidden` | You can only do this for your own content. | Vous ne pouvez faire cela que pour votre propre contenu. |
| `cmtEcAlreadyBoosted` | This post is already boosted. | Cette publication est déjà boostée. |
| `cmtEcActiveBoostExists` | You already have an active boost on another post. | Vous avez déjà un boost actif sur une autre publication. |
| `cmtEcInsufficientCoins` | Not enough SX Coins to boost. | Pas assez de SX Coins pour booster. |
| `cmtEcVotingClosed` | Voting is closed right now. | Les votes sont fermés en ce moment. |
| `cmtEcAlreadyVoted` | You've already voted this week. | Vous avez déjà voté cette semaine. |
| `cmtEcAlreadyReported` | You've already reported this. | Vous avez déjà signalé ceci. |
| `cmtEcUploadFailed` | Image upload failed. Please try again. | L'envoi de l'image a échoué. Réessayez. |

- [ ] **Step 2: Regenerate and confirm parity**

Run: `flutter gen-l10n && flutter test test/core/l10n_test.dart`
Expected: PASS.

- [ ] **Step 3: Write the failing test** — `test/features/community/community_error_copy_test.dart`: build `AppLocalizationsEn()`; assert each of `network`, `unauthorized`, `idempotency_in_progress`, `validation_failed`, `not_found`, `forbidden`, `already_boosted`, `active_boost_exists`, `insufficient_coins`, `boost_failed`, `voting_closed`, `already_voted`, `already_reported`, `report_failed`, `upload_failed` returns non-empty copy, and that the set of distinct outputs for the first 13 of those (excluding the two `*_failed` server-internal codes, which fall through by design) has at least 12 members; assert `'something_new'` and `''` both return `l10n.cmtEcGeneric`, and that `'boost_failed'`/`'report_failed'` also fall through to `cmtEcGeneric` (they're internal 500s, not player-facing business states — see the Stage B handoff Rulings 5/6).

- [ ] **Step 4: Implement, run**

`communityErrorCopy` is a `switch`: `network`→`cmtEcNetwork`, `unauthorized`→`cmtEcSession`, `idempotency_in_progress`→`cmtEcInProgress`, `validation_failed`→`cmtEcValidation`, `not_found`→`cmtEcNotFound`, `forbidden`→`cmtEcForbidden`, `already_boosted`→`cmtEcAlreadyBoosted`, `active_boost_exists`→`cmtEcActiveBoostExists`, `insufficient_coins`→`cmtEcInsufficientCoins`, `voting_closed`→`cmtEcVotingClosed`, `already_voted`→`cmtEcAlreadyVoted`, `already_reported`→`cmtEcAlreadyReported`, `upload_failed`→`cmtEcUploadFailed`, default (incl. `boost_failed`, `report_failed`)→`cmtEcGeneric`.
Run: `flutter test test/features/community/community_error_copy_test.dart` → PASS.

- [ ] **Step 5: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/core/l10n lib/features/community/community_error_copy.dart test/features/community
git commit -m "feat(l10n): Phase 4 Community copy (en+fr) and error-code copy"
```

---

### Task 3: `CommunityRepository` and core providers

**Files:**
- Create: `lib/features/community/community_repository.dart`, `lib/features/community/community_providers.dart`, `test/features/community/community_providers_test.dart`, `test/fakes/fake_community_repository.dart`

**Interfaces:**
- Consumes: `community_models.dart` (Task 1), `apiClientProvider`/`meProvider` (`lib/core/providers.dart`).
- Produces:

```dart
abstract class CommunityRepository {
  Future<CommunityFeedPage> feed({required int offset, required int limit});
  Future<CommunityPostDetail> postDetail(String id);
  Future<ChallengesWidget?> challenges();
  Future<BestPlayBanner?> bestPlay();
  Future<List<StatusRing>> statuses();
  Future<List<StatusViewer>> statusViewers(String statusId);
  Future<List<TopMember>> topMembers();
  Future<List<UpcomingEvent>> upcomingEvents();
  Future<CommunityGalleryPage> gallery({required int offset, required int limit});
  Future<CommunityStats> stats();
  Future<String> createPost({required String content, required List<String> imageUrls, required String idempotencyKey});
  Future<void> deletePost(String id);
  Future<void> boostPost(String id, {required String idempotencyKey});
  Future<ReactionType> setReaction(String postId, ReactionType reaction, {required String idempotencyKey});
  Future<void> removeReaction(String postId);
  Future<String> createComment(String postId, {required String content, required String idempotencyKey});
  Future<void> deleteComment(String id);
  Future<String> postStatus({String? imageUrl, String? caption, required String idempotencyKey});
  Future<void> deleteStatus(String id);
  Future<void> viewStatus(String id);
  Future<void> voteBestPlay(String nominationId, {required String idempotencyKey});
  Future<void> reportPost(String id, {required ReportReasonCode reasonCode, String? note, required String idempotencyKey});
  Future<void> reportComment(String id, {required ReportReasonCode reasonCode, String? note, required String idempotencyKey});
}

class CommunityFeedState {
  const CommunityFeedState({required this.pinned, required this.posts, required this.hasMore, this.loadingMore = false});
  final List<PostView> pinned, posts;
  final bool hasMore, loadingMore;
  CommunityFeedState copyWith({List<PostView>? pinned, List<PostView>? posts, bool? hasMore, bool? loadingMore}) =>
      CommunityFeedState(pinned: pinned ?? this.pinned, posts: posts ?? this.posts, hasMore: hasMore ?? this.hasMore, loadingMore: loadingMore ?? this.loadingMore);
}

class CommunityFeedNotifier extends AsyncNotifier<CommunityFeedState> {
  Future<CommunityFeedState> build();
  Future<void> loadMore();
  Future<void> refresh();
  void updatePost(String id, PostView Function(PostView) transform);
  void removePost(String id);
}
final communityFeedProvider = AsyncNotifierProvider.autoDispose<CommunityFeedNotifier, CommunityFeedState>(CommunityFeedNotifier.new);

class CommunityPostDetailNotifier extends AsyncNotifier<CommunityPostDetail> {
  CommunityPostDetailNotifier(this.postId);
  final String postId;
  Future<CommunityPostDetail> build();
  void updatePost(PostView Function(PostView) transform);
  void addComment(CommentView comment);
  void removeComment(String commentId);
}
final communityPostDetailProvider =
    AsyncNotifierProvider.autoDispose.family<CommunityPostDetailNotifier, CommunityPostDetail, String>(CommunityPostDetailNotifier.new);

final communityRepositoryProvider = Provider<CommunityRepository>((ref) => ApiCommunityRepository(ref.watch(apiClientProvider)));
final communityChallengesProvider = FutureProvider.autoDispose<ChallengesWidget?>((ref) async { /* null when signed out, never calls the API signed out */ });
final communityBestPlayProvider = FutureProvider.autoDispose<BestPlayBanner?>((ref) => ref.watch(communityRepositoryProvider).bestPlay());
final communityStatusRingsProvider = FutureProvider.autoDispose<List<StatusRing>>((ref) => ref.watch(communityRepositoryProvider).statuses());
final communityStatusViewersProvider = FutureProvider.autoDispose.family<List<StatusViewer>, String>((ref, id) => ref.watch(communityRepositoryProvider).statusViewers(id));
final communityTopMembersProvider = FutureProvider.autoDispose<List<TopMember>>((ref) => ref.watch(communityRepositoryProvider).topMembers());
final communityUpcomingEventsProvider = FutureProvider.autoDispose<List<UpcomingEvent>>((ref) => ref.watch(communityRepositoryProvider).upcomingEvents());
final communityGalleryProvider = FutureProvider.autoDispose<CommunityGalleryPage>((ref) => ref.watch(communityRepositoryProvider).gallery(offset: 0, limit: 8));
final communityStatsProvider = FutureProvider.autoDispose<CommunityStats>((ref) => ref.watch(communityRepositoryProvider).stats());
```

`ApiCommunityRepository` implements every method as a one-line delegation to the matching `ApiClient` call (identical shape to `ApiMatchRepository` in `lib/features/match/match_repository.dart` — copy that file's structure, not its content).

- [ ] **Step 1: `test/fakes/fake_community_repository.dart`** — an in-memory `FakeCommunityRepository implements CommunityRepository` matching the shape of `FakeMatchRepository`/`FakePlayersRepository`: constructor takes seed data (`feedPage`, `postDetails` map, etc.) and records every call (`List<String> calls`) so tests can assert on write invocations (payload + idempotency key) without a real Dio stack. Reads return the seeded fixtures; writes append to `calls` and either succeed or throw a seeded `ApiException`.

- [ ] **Step 2: Write the failing tests** — `test/features/community/community_providers_test.dart`, using a `ProviderContainer` with `container.listen(communityFeedProvider, (_, _) {})`-style keep-alive (copy the pattern from `test/core/write_flow_test.dart`). Cover:
  1. `communityFeedProvider`'s initial `build()` calls `feed(offset: 0, limit: 20)` and exposes the seeded pinned/posts/hasMore.
  2. `loadMore()` calls `feed(offset: <current post count>, limit: 20)` and appends; a second concurrent `loadMore()` call while the first is in flight (gate with a `Completer` in the fake) is a no-op (the underlying fake is called once).
  3. `loadMore()` does nothing when `hasMore` is `false`.
  4. `refresh()` replaces `pinned`/`posts`/`hasMore` from a fresh offset-0 fetch (seed the fake to return different data on the second call).
  5. `updatePost('p1', (p) => p.copyWith(commentCount: p.commentCount + 1))` mutates the post wherever it is (pinned or posts), leaves other posts untouched, and is a no-op for an id not present.
  6. `removePost('p1')` removes it from both `pinned` and `posts`.
  7. `communityPostDetailProvider('p1')` calls `postDetail('p1')`; `updatePost`/`addComment`/`removeComment` mutate state and `addComment`/`removeComment` also adjust `post.commentCount` by ±1.
  8. `communityChallengesProvider` never calls `challenges()` when `meProvider` resolves to `null` (signed out) and returns `null` without touching the fake — assert via the fake's `calls` list being empty.

- [ ] **Step 3: Run to verify failure, implement, run again**

Run: `flutter test test/features/community/community_providers_test.dart` → FAIL (files not found). Implement `community_repository.dart` and `community_providers.dart` per the Interfaces block; `CommunityFeedNotifier`/`CommunityPostDetailNotifier` follow the exact `AsyncNotifier` shape and `ref.mounted` guards already established by `MyFollowsNotifier` (`players_providers.dart`) and `WriteFlow`. `communityChallengesProvider`'s body:

```dart
final communityChallengesProvider = FutureProvider.autoDispose<ChallengesWidget?>((ref) async {
  final me = await ref.watch(meProvider.future);
  if (me == null) return null;
  return ref.watch(communityRepositoryProvider).challenges();
});
```

Run: `flutter test test/features/community/community_providers_test.dart` → PASS.

- [ ] **Step 4: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/community/community_repository.dart lib/features/community/community_providers.dart test/features/community test/fakes/fake_community_repository.dart
git commit -m "feat(community): repository and core Riverpod providers"
```

---

### Task 4: Realtime — debounced multi-channel refetch signal

**Files:**
- Create: `lib/features/community/community_realtime.dart`, `test/features/community/community_realtime_test.dart`

**Interfaces:**
- Consumes: `supabaseClientProvider`.
- Produces:

```dart
Stream<void> debouncedChangeSignal(List<Stream<dynamic>> sources, {Duration debounce = const Duration(milliseconds: 400)});
Stream<void> feedChangeSignal(SupabaseClient client);          // community_posts INSERT, post_reactions *, post_comments *, player_statuses INSERT+DELETE (unfiltered — spec §7)
Stream<void> postDetailChangeSignal(SupabaseClient client, String postId); // post_comments *, post_reactions *, both filtered to postId
final communityFeedRealtimeProvider = StreamProvider.autoDispose<void>((ref) => feedChangeSignal(ref.watch(supabaseClientProvider)));
final communityPostDetailRealtimeProvider = StreamProvider.autoDispose.family<void, String>((ref, postId) => postDetailChangeSignal(ref.watch(supabaseClientProvider), postId));
```

Per this plan's **Realtime architecture decision** (Global Constraints): this stays a feature-internal helper reused by exactly two call sites (feed, post detail) inside `lib/features/community/`, not a new cross-app channel manager — the shared-manager precedent in `lib/core/notifications/unread_counts.dart` is deliberately not invoked here since DMs (its named third consumer) doesn't exist yet.

- [ ] **Step 1: Write the failing debounce test** — `test/features/community/community_realtime_test.dart`, using `package:fake_async/fake_async.dart`:

```dart
import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/community/community_realtime.dart';

void main() {
  test('coalesces multiple rapid emissions across sources into one signal after the debounce window', () {
    fakeAsync((async) {
      final a = StreamController<int>();
      final b = StreamController<int>();
      var emitted = 0;
      final sub = debouncedChangeSignal([a.stream, b.stream]).listen((_) => emitted++);
      async.elapse(Duration.zero); // let the merge subscribe
      a.add(1);
      async.elapse(const Duration(milliseconds: 100));
      b.add(1);
      async.elapse(const Duration(milliseconds: 100));
      a.add(1);
      async.elapse(const Duration(milliseconds: 399));
      expect(emitted, 0, reason: 'still inside the debounce window since the last emission');
      async.elapse(const Duration(milliseconds: 1));
      expect(emitted, 1);
      sub.cancel();
      a.close();
      b.close();
    });
  });

  test('a second burst after the first signal fires produces a second signal', () {
    fakeAsync((async) {
      final a = StreamController<int>();
      var emitted = 0;
      final sub = debouncedChangeSignal([a.stream]).listen((_) => emitted++);
      async.elapse(Duration.zero);
      a.add(1);
      async.elapse(const Duration(milliseconds: 400));
      expect(emitted, 1);
      a.add(1);
      async.elapse(const Duration(milliseconds: 400));
      expect(emitted, 2);
      sub.cancel();
      a.close();
    });
  });

  test('cancelling the subscription tears down every source subscription and the timer', () {
    fakeAsync((async) {
      final a = StreamController<int>();
      var emitted = 0;
      final sub = debouncedChangeSignal([a.stream]).listen((_) => emitted++);
      async.elapse(Duration.zero);
      sub.cancel();
      a.add(1); // after cancel — must never schedule a late emission
      async.elapse(const Duration(seconds: 2));
      expect(emitted, 0);
      expect(a.hasListener, isFalse);
      a.close();
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/community/community_realtime_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Implement `lib/features/community/community_realtime.dart`**

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';

/// Merges several change streams into one signal, debounced (matches web's own 400ms coalesce,
/// spec §7). A feature-internal helper for the feed and post-detail screens — not the general-
/// purpose cross-app channel manager `unread_counts.dart` defers until DMs exist (see this plan's
/// Global Constraints "Realtime architecture decision").
Stream<void> debouncedChangeSignal(List<Stream<dynamic>> sources, {Duration debounce = const Duration(milliseconds: 400)}) {
  late StreamController<void> controller;
  Timer? timer;
  final subs = <StreamSubscription<dynamic>>[];
  controller = StreamController<void>.broadcast(
    onListen: () {
      for (final s in sources) {
        subs.add(s.listen((_) {
          timer?.cancel();
          timer = Timer(debounce, () {
            if (!controller.isClosed) controller.add(null);
          });
        }));
      }
    },
    onCancel: () {
      timer?.cancel();
      for (final s in subs) {
        s.cancel();
      }
      subs.clear();
    },
  );
  return controller.stream;
}

Stream<void> _channel(
  SupabaseClient client,
  String name,
  String table, {
  PostgresChangeEvent event = PostgresChangeEvent.all,
  PostgresChangeFilter? filter,
}) {
  late StreamController<void> controller;
  RealtimeChannel? channel;
  controller = StreamController<void>.broadcast(
    onListen: () {
      channel = client.channel(name)
        ..onPostgresChanges(event: event, schema: 'public', table: table, filter: filter, callback: (_) => controller.add(null))
        ..subscribe();
    },
    onCancel: () async {
      final c = channel;
      channel = null;
      if (c != null) await client.removeChannel(c);
    },
  );
  return controller.stream;
}

/// Feed screen: new post, any reaction, any comment (count badges live on the feed too), any
/// status appearing/expiring-by-deletion. Unfiltered — spec §7.
Stream<void> feedChangeSignal(SupabaseClient client) => debouncedChangeSignal([
      _channel(client, 'cmt-feed-posts', 'community_posts', event: PostgresChangeEvent.insert),
      _channel(client, 'cmt-feed-reactions', 'post_reactions'),
      _channel(client, 'cmt-feed-comments', 'post_comments'),
      _channel(client, 'cmt-feed-statuses-ins', 'player_statuses', event: PostgresChangeEvent.insert),
      _channel(client, 'cmt-feed-statuses-del', 'player_statuses', event: PostgresChangeEvent.delete),
    ]);

/// Post-detail screen: comments and reactions for this one post only — spec §7.
Stream<void> postDetailChangeSignal(SupabaseClient client, String postId) => debouncedChangeSignal([
      _channel(client, 'cmt-detail-comments-$postId', 'post_comments',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'post_id', value: postId)),
      _channel(client, 'cmt-detail-reactions-$postId', 'post_reactions',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'post_id', value: postId)),
    ]);

final communityFeedRealtimeProvider = StreamProvider.autoDispose<void>((ref) => feedChangeSignal(ref.watch(supabaseClientProvider)));
final communityPostDetailRealtimeProvider =
    StreamProvider.autoDispose.family<void, String>((ref, postId) => postDetailChangeSignal(ref.watch(supabaseClientProvider), postId));
```

Note: `_channel`/`feedChangeSignal`/`postDetailChangeSignal` themselves have **no dedicated unit test** — mirroring `unread_counts.dart`'s own precedent of leaving the raw Supabase channel wiring untested directly (it's exercised instead by Task 7/8's screen widget tests, which override `communityFeedRealtimeProvider`/`communityPostDetailRealtimeProvider` with a controllable fake `Stream<void>`, never a real channel). Only `debouncedChangeSignal`, the pure/testable logic, gets a direct test.

- [ ] **Step 4: Run and commit**

Run: `flutter test test/features/community/community_realtime_test.dart` → PASS.

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/community/community_realtime.dart test/features/community/community_realtime_test.dart
git commit -m "feat(community): debounced multi-channel realtime refetch signal"
```

---

### Task 5: Reactions — optimistic set/remove

**Files:**
- Create: `lib/features/community/reaction_bar.dart`, `test/features/community/reaction_bar_test.dart`

**Interfaces:**
- Consumes: `WriteFlow`/`writeFlowProvider` (`lib/core/utils/write_flow.dart`), `communityFeedProvider`/`communityPostDetailProvider` (Task 3), `meProvider`.
- Produces:

```dart
extension PostViewReaction on PostView {
  /// Same-turn optimistic delta only (Global Constraints Ruling) — not a recomputation of
  /// server-aggregate logic, a trivially-correct ±1 for exactly the caller's own slot.
  PostView withMyReaction(ReactionType? next);
}

class ReactionBar extends ConsumerWidget {
  const ReactionBar({super.key, required this.post, required this.onUpdate, required this.onSignInRequired});
  final PostView post;
  final void Function(PostView Function(PostView) transform) onUpdate; // wired to feed/detail notifier's updatePost
  final VoidCallback onSignInRequired;
}
```

- [ ] **Step 1: Write the failing tests** — `test/features/community/reaction_bar_test.dart`:
  1. `PostView.withMyReaction`: from no reaction → `fire` increments `fire` by 1 and sets `myReaction`; from `fire` → `fire` again (tap same emoji) is treated by the widget as "remove" (tested at the widget level, not the extension — the extension itself just sets whatever `next` it's given) and `withMyReaction(null)` decrements `fire` and clears `myReaction`; switching `fire` → `crown` decrements `fire` and increments `crown` in one call.
  2. Widget: signed-out (`competeBaseOverrides(signedOut: true)`) — tapping any reaction icon calls `onSignInRequired` and sends **no** API call (assert via the fake repository's `calls` being empty) and does not mutate `onUpdate`.
  3. Widget: signed-in, tap `crown` on a post with `myReaction: null` — `onUpdate` is called synchronously (optimistic) with the incremented count before the fake API call resolves; once the fake resolves successfully, the state stays as applied (no rollback), and `FakeCommunityRepository.calls` recorded `setReaction(post.id, ReactionType.crown, idempotencyKey: <key>)`.
  4. Widget: tap the currently-active reaction — calls `removeReaction`, not `setReaction`.
  5. Widget: the fake repository throws `ApiException(status: 409, code: 'not_found')` on `setReaction` — after the call fails, `onUpdate` is invoked a second time restoring the exact pre-tap `PostView` (rollback), and a `SnackBar`/inline error shows `communityErrorCopy(l10n, 'not_found')`.
  6. Two rapid taps on the same emoji before the first request resolves (gate the fake with a `Completer`) result in exactly one API call — `writeFlowProvider('react:${post.id}')`'s busy guard.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/community/reaction_bar_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Implement**

```dart
extension PostViewReaction on PostView {
  PostView withMyReaction(ReactionType? next) {
    if (next == myReaction) return this;
    var counts = reactionCounts;
    if (myReaction != null) counts = counts.decrement(myReaction!);
    if (next != null) counts = counts.increment(next);
    return copyWith(reactionCounts: counts, myReaction: next, clearMyReaction: next == null);
  }
}
```

`ReactionBar` reads `ref.watch(meProvider).asData?.value` to decide signed-in-ness (never calls the API signed out); on tap:

```dart
Future<void> _tap(WidgetRef ref, ReactionType tapped) async {
  if (ref.read(meProvider).asData?.value == null) return onSignInRequired();
  final next = post.myReaction == tapped ? null : tapped;
  final before = post;
  onUpdate((_) => post.withMyReaction(next));
  final repo = ref.read(communityRepositoryProvider);
  final scope = 'react:${post.id}';
  final ok = await ref.read(writeFlowProvider(scope).notifier).run(
        (key) => next == null ? repo.removeReaction(post.id) : repo.setReaction(post.id, next, idempotencyKey: key),
        fingerprint: next?.wireName ?? 'remove',
      );
  if (!ok) onUpdate((_) => before);
}
```

Four `IconButton`s (`Key('react-fire')` etc.) with semantics labels `l10n.cmtReactFire`/etc., each showing `post.reactionCounts[type]` and highlighted when `post.myReaction == type`; disabled while `ref.watch(writeFlowProvider(scope)).busy`.

- [ ] **Step 4: Run and commit**

Run: `flutter test test/features/community/reaction_bar_test.dart` → PASS.

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/community/reaction_bar.dart test/features/community/reaction_bar_test.dart
git commit -m "feat(community): optimistic reaction set/remove"
```

---

### Task 6: Compose — image upload + create-post

**Files:**
- Create: `lib/features/community/community_image_uploader.dart`, `lib/features/community/compose_submitter.dart`, `lib/features/community/compose_screen.dart`, `test/features/community/compose_submitter_test.dart`, `test/features/community/compose_screen_test.dart`, `test/fakes/fake_community_uploader.dart`

**Interfaces:**
- Consumes: `PickedImage` (from `lib/features/match/evidence.dart` — reused directly, not duplicated), `WriteFlow`, `CommunityRepository`.
- Produces:

```dart
String communityImagePath({required String userId, required String fileName, required DateTime now});
abstract class CommunityImageUploader {
  Future<String> upload({required String userId, required PickedImage image}); // returns a PUBLIC URL, not a path
}
abstract class MultiImagePickerPort {
  Future<List<PickedImage>> pickImages({required int maxCount}); // empty when cancelled/none picked
}
final communityImageUploaderProvider = Provider<CommunityImageUploader>(...);   // SupabaseCommunityImageUploader
final communityMultiImagePickerProvider = Provider<MultiImagePickerPort>(...);  // PluginMultiImagePicker

class CommunityPostSubmitter {
  CommunityPostSubmitter({required this.uploader, required this.userId});
  Future<bool> submit({
    required WriteFlow flow,
    required String content,
    required List<PickedImage> images,
    required Future<void> Function(String content, List<String> imageUrls, String idempotencyKey) send,
  });
}
```

Rules: `communityImagePath` = `'$userId/${now.millisecondsSinceEpoch}-$safe'` (`safe` = the same `[^a-zA-Z0-9._-]` → `_` transform as `evidencePath`), matching the `community-images` bucket's insert policy (`(storage.foldername(name))[1] = auth.uid()::text`, per `016_community.sql`) — one segment shorter than `evidencePath` since there's no per-match scope. `CommunityPostSubmitter` memoizes each picked image's uploaded URL **by identity** (a `Map<PickedImage, String>`, relying on `PickedImage`'s default identity `==`/`hashCode` — it declares neither, so two distinct instances are never equal even with identical bytes): a retry after a failed POST re-uses every already-uploaded image's URL and only uploads images not yet uploaded; picking a *different* image set changes the `fingerprint` passed to `WriteFlow.run` (`'$content:${images.map(identityHashCode).join(',')}'`), forcing a fresh key so an edited retry never replays the old response. Any upload failure is converted to `ApiException(status: 0, code: 'upload_failed', message: 'Image upload failed.')` thrown inside the `flow.run` closure (mirrors `ResultSubmitter`'s screenshot handling exactly).

- [ ] **Step 1: `test/fakes/fake_community_uploader.dart`** — `FakeCommunityUploader implements CommunityImageUploader` returning `'https://fake.test/${image.name}'` per call and recording call count; a `FailingCommunityUploader` variant that always throws. `FakePicker implements MultiImagePickerPort` returning a seeded list.

- [ ] **Step 2: Write the failing submitter tests** — `test/features/community/compose_submitter_test.dart` (mirror `test/features/match/evidence_test.dart`'s structure for `ResultSubmitter`):
  1. Two images, both never uploaded before → both get uploaded (uploader call count 2), `send` receives both URLs in order, success.
  2. A retry (same `flow`, same `images` list instances) after `send` throws a retryable `ApiException(code: 'network')` — the second attempt does **not** re-upload either image (uploader call count stays 2), reuses the same Idempotency-Key.
  3. One image fails to upload — `flow`'s state becomes `failed`/`upload_failed`, `send` is never called, and the *next* attempt (even with the same images) mints a fresh key (nothing was sent to the server).
  4. Swapping in a third, never-seen-before `PickedImage` on retry uploads only that one (call count +1), not the two already-memoized ones.
  5. Empty `images` list with non-empty `content` — `send` is called with `imageUrls: []`, no uploader calls at all.

- [ ] **Step 3: Run to verify failure, implement `community_image_uploader.dart` + `compose_submitter.dart`, run again**

```dart
class SupabaseCommunityImageUploader implements CommunityImageUploader {
  SupabaseCommunityImageUploader(this._client);
  final SupabaseClient _client;
  @override
  Future<String> upload({required String userId, required PickedImage image}) async {
    final path = communityImagePath(userId: userId, fileName: image.name, now: DateTime.now());
    await _client.storage.from('community-images').uploadBinary(path, image.bytes, fileOptions: FileOptions(upsert: false, contentType: image.mimeType));
    return _client.storage.from('community-images').getPublicUrl(path);
  }
}

class PluginMultiImagePicker implements MultiImagePickerPort {
  @override
  Future<List<PickedImage>> pickImages({required int maxCount}) async {
    final files = await ImagePicker().pickMultiImage(limit: maxCount, maxWidth: 1600, imageQuality: 80);
    return Future.wait(files.map((f) async => PickedImage(name: f.name, bytes: await f.readAsBytes(), mimeType: f.mimeType)));
  }
}
```

`CommunityPostSubmitter.submit` follows `ResultSubmitter.submit`'s exact shape (per-image memo instead of a single path). Run: `flutter test test/features/community/compose_submitter_test.dart` → PASS.

- [ ] **Step 4: Write the failing compose screen tests** — `test/features/community/compose_screen_test.dart` (pump via `pumpCompete`/a new `pumpRouterWithRepo`-style helper overriding `communityRepositoryProvider`, `communityImageUploaderProvider`, `communityMultiImagePickerProvider`, plus `competeBaseOverrides`):
  1. Empty content, no images — the post button (`Key('compose-submit')`) is disabled.
  2. Text-only post — enabled; tapping it calls `createPost(content: ..., imageUrls: [])` and, on success, pops the route.
  3. Adding images via the picker shows `l10n.cmtComposeImagesCount(n)` and thumbnails, each with a `Key('compose-remove-image-$i')` button that removes it from the pending list before submit (no upload happens for a removed-before-submit image).
  4. Picking beyond 5 images caps the pending list at 5 (mirrors web's `MAX_POST_IMAGES` clamp).
  5. Submit with images calls the uploader once per image then `createPost` with the returned URLs, in the picked order.
  6. Uploader throws — the screen shows `communityErrorCopy(l10n, 'upload_failed')`, the route does **not** pop, and the picked images remain in the compose form (not cleared) so the player can retry without re-picking.
  7. `createPost` throws `validation_failed` — shows `communityErrorCopy(l10n, 'validation_failed')`.
  8. `PopScope`/back navigation is blocked (`canPop: false`) while the write is in flight (busy), same pattern as `rating_sheet.dart`'s `PopScope(canPop: !busy, ...)`.

- [ ] **Step 5: Run to verify failure, implement `compose_screen.dart`, run again**

`ComposeScreen extends ConsumerStatefulWidget` holding a `TextEditingController` and `List<PickedImage> _images`; on submit, builds a `CommunityPostSubmitter` from `communityImageUploaderProvider` + `ref.read(meProvider).asData!.value!.id`, calls `.submit(flow: ref.read(writeFlowProvider('compose').notifier), content: ..., images: _images, send: (content, urls, key) => ref.read(communityRepositoryProvider).createPost(content: content, imageUrls: urls, idempotencyKey: key))`; on success, `ref.invalidate(communityFeedProvider)` then `Navigator.pop()`. Run: `flutter test test/features/community/compose_screen_test.dart` → PASS.

- [ ] **Step 6: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/community/community_image_uploader.dart lib/features/community/compose_submitter.dart lib/features/community/compose_screen.dart test/features/community test/fakes/fake_community_uploader.dart
git commit -m "feat(community): compose screen — text + up to 5 images"
```

---

### Task 7: Feed screen

**Files:**
- Create: `lib/features/community/community_feed_screen.dart`, `lib/features/community/post_card.dart`, `test/features/community/community_feed_screen_test.dart`, `test/features/community/post_card_test.dart`

**Interfaces:**
- Consumes: every provider from Task 3, `communityFeedRealtimeProvider` (Task 4), `ReactionBar` (Task 5), `boostSheet` (Task 9 — forward-referenced here as a callback the screen wires, built in Task 9; if Task 9 is executed after this one, stub the callback as a no-op parameter until then and wire it for real once Task 9 lands. Prefer executing Task 9 before this one if using subagent-driven execution with parallelizable tasks; if executing tasks strictly in order, this forward reference is resolved by the time Task 9's own step runs).
- Produces:

```dart
class CommunityFeedScreen extends ConsumerWidget {
  const CommunityFeedScreen({super.key, required this.onCompose, required this.onPostTap, required this.onLogin, required this.onStatusTap, required this.onAddStatus});
  final VoidCallback onCompose, onLogin, onAddStatus;
  final void Function(PostView post) onPostTap;
  final void Function(StatusRing ring) onStatusTap;
}
class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, required this.onTap, required this.onSignInRequired, this.compact = false});
  final PostView post;
  final VoidCallback onTap, onSignInRequired;
  final bool compact; // compact: no reaction bar/comment affordance, used by the gallery grid
}
```

- [ ] **Step 1: Write the failing `PostCard` tests** — `test/features/community/post_card_test.dart`:
  1. Renders author name/avatar (`PlayerAvatar`), content, image (when `imageUrl != null`), reaction bar, comment count via `l10n.cmtCommentCount(post.commentCount)`.
  2. A pinned post shows `l10n.cmtPinnedLabel`; a live-boosted post (`boostedUntil` in the future) shows `l10n.cmtBoostedLabel`; neither badge for a plain post.
  3. `canDelete: false`/`canBoost: false` (e.g. a `match_result`/`announcement` post, or someone else's post) render **no** delete/boost menu item at all — not a disabled one.
  4. Text-only post (`imageUrl: null`) renders no image widget and no broken-image placeholder.
  5. `compact: true` renders no `ReactionBar` and no comment-count row (gallery-grid usage).
  6. Tapping the card body (not a reaction icon) calls `onTap`.

- [ ] **Step 2: Run to verify failure, implement `PostCard`, run again**

Layout: `Card` > `InkWell(onTap: onTap)` wrapping `Column` with author row (`PlayerAvatar(avatarUrl: post.author.avatarUrl, frameUrl: post.author.frameUrl)` + name + relative-or-raw `createdAt`), badges row (pinned/boosted `Chip`s, `visualDensity: VisualDensity.compact`, matching `_TournamentCard`'s status-chip style), content `Text`, `Image.network(post.imageUrl!, errorBuilder: (_, _, _) => const SizedBox.shrink())` when present (additional `imageUrls` beyond the first render as a horizontal thumbnail strip only on the **full**, non-`compact` card), and, when not `compact`, a bottom row: `ReactionBar(post: post, onUpdate: ..., onSignInRequired: onSignInRequired)` + a comment-count `TextButton` showing `l10n.cmtCommentCount(post.commentCount)` that also calls `onTap`. Run tests → PASS.

- [ ] **Step 3: Write the failing feed screen tests** — `test/features/community/community_feed_screen_test.dart` (pump the real widget tree with fake providers, `Size(375, 800)`):
  1. Loading → `CircularProgressIndicator`; error → retry button that calls `ref.invalidate(communityFeedProvider)` (mirror `_LoadError` in `compete_list_screen.dart`).
  2. Empty feed (`pinned: [], posts: [], hasMore: false`) shows `l10n.cmtFeedEmpty`, and the challenges/Best-Play/status/top-members/upcoming-events/gallery/stats sections still render from their own independent providers (a post-empty feed doesn't hide the rest of the page).
  3. Pinned posts render in their own section above the regular posts, in the order the API returned them (no client-side re-sort).
  4. `hasMore: true` shows a `Key('feed-load-more')` control; tapping it calls `communityFeedProvider.notifier.loadMore()` and appends without losing scroll position (assert the pinned section + first post are still present after load-more resolves).
  5. Pull-to-refresh (`RefreshIndicator`) calls `refresh()`.
  6. Signed-out (`competeBaseOverrides(signedOut: true)`): the FAB / `Key('feed-compose-fab')` still renders (visible affordance) but tapping it calls `onLogin`, not `onCompose`; challenges rail shows `l10n.cmtChallengesSignedOut` instead of calling the API (`communityChallengesProvider` never invoked — assert via a fake that throws if called while signed out, since Task 3's provider already early-returns null but the *screen* must not additionally gate-call something else).
  7. Signed-in: FAB calls `onCompose`.
  8. Best Play banner: `null` response renders nothing (no empty banner shell); a populated response shows nominations with vote counts and a `Key('bestplay-vote-<nominationId>')` button per nomination; tapping one signed-in calls `voteBestPlay` and, on success, invalidates `communityBestPlayProvider`; `voting_closed`/`already_voted` errors show their mapped copy inline, not a generic failure (Review Focus #4); signed-out, tapping shows `onLogin` instead of calling the API.
  9. Challenges rail: `null` renders nothing; a populated response lists each `ChallengeProgress` with `l10n.cmtChallengeProgress(progress, goal)` and, when `completed`, `l10n.cmtChallengeCompleted` — read-only, no controls (Global Constraints — no player-initiated write path).
  10. Top members / upcoming events / gallery / stats each render their own loading/empty/data states independently (one section's error doesn't blank the others — each is backed by its own `FutureProvider`, rendered with its own `.when`).
  11. Status tray forwards taps to `onStatusTap`/`onAddStatus` (full behavior covered in Task 10; here only the wiring is asserted, via a fake `StatusTray` substitute or a `Key`-based `find.byKey` + `tester.tap`).
  12. Realtime: override `communityFeedRealtimeProvider` with a controllable `StreamController<void>`; after the feed's first successful load, pushing an event and pumping invalidates and refetches `communityFeedProvider` (assert the fake repository's `feed()` call count increases by exactly one per emitted event, not per raw table row).

- [ ] **Step 4: Run to verify failure, implement `community_feed_screen.dart`, run again**

`CustomScrollView` with `RefreshIndicator` wrapping it (or `RefreshIndicator` around the whole `CustomScrollView`, matching Flutter's documented pattern for slivers) containing, in order: status tray, challenges rail, Best Play banner, pinned-posts section, posts `SliverList` + load-more footer, then a trailing "Discover" section (top members, upcoming events, gallery grid, stats bar) — **Ruling**: this ordering isn't specified exactly by the spec (which lists the rails without a strict layout order); primary feed content is placed first and discovery widgets after, appropriate for a single mobile scroll column. `ref.listen(communityFeedRealtimeProvider, (prev, next) { if (next.hasValue) ref.invalidate(communityFeedProvider); })` inside `build`. FAB: `FloatingActionButton(key: const Key('feed-compose-fab'), onPressed: () { if (ref.read(meProvider).asData?.value == null) return onLogin(); onCompose(); }, child: const Icon(Icons.add))`. Run tests → PASS.

- [ ] **Step 5: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/community/community_feed_screen.dart lib/features/community/post_card.dart test/features/community
git commit -m "feat(community): feed screen — pinned/boosted posts, rails, realtime"
```

---

### Task 8: Post detail + comments

**Files:**
- Create: `lib/features/community/post_detail_screen.dart`, `test/features/community/post_detail_screen_test.dart`

**Interfaces:**
- Consumes: `communityPostDetailProvider`, `communityPostDetailRealtimeProvider`, `ReactionBar`, `writeFlowProvider`, `report_sheet.dart` (Task 11, same forward-reference note as Task 7/9).
- Produces: `class PostDetailScreen extends ConsumerWidget { const PostDetailScreen({super.key, required this.postId, required this.onLogin, required this.onDeleted}); final String postId; final VoidCallback onLogin, onDeleted; }`

- [ ] **Step 1: Write the failing tests** — `test/features/community/post_detail_screen_test.dart`:
  1. Loading/error/data states for the post itself (same pattern as the feed).
  2. Comments list renders each `CommentView`; empty comments shows `l10n.cmtCommentsEmpty`.
  3. Exactly 50 comments (the API's hard cap, Stage B Ruling 4) shows `l10n.cmtCommentsCapNotice` and **no** load-more control (there is no comments pagination endpoint) — Review Focus #5.
  4. Signed-out: no comment input field is rendered (or it's present but tapping it calls `onLogin` before focusing — pick one, implement and test it; this plan recommends showing a `Key('comment-signin-prompt')` row instead of a text field when signed out, simplest and unambiguous).
  5. Signed-in: typing and submitting a comment (`Key('comment-submit')`) calls `createComment` with the typed content and an Idempotency-Key; on success, `communityPostDetailProvider(postId).notifier.addComment(...)` is reflected (new comment appears, `commentCount` in the header increments by 1) and the input clears.
  6. Empty/whitespace-only comment text disables the submit control.
  7. `canDelete: true` on a comment shows a `Key('comment-delete-<id>')` control; tapping it shows a confirm dialog (`l10n.cmtDeleteCommentConfirm`), and confirming calls `deleteComment` then `removeComment(id)` on the notifier (comment disappears, count decrements); `canDelete: false` shows no control.
  8. `post.canDelete: true` shows a delete-post action (app bar menu); confirming calls `deletePost` then `onDeleted()` (the screen pops itself — deletion of the currently-viewed post can't leave the user on a page for a post that no longer exists).
  9. `post.canBoost: true` and `canBoost: false` gate the boost entry point (full boost-flow behavior is Task 9's; here only assert the entry point's visibility follows `canBoost`, never inferred from `postType`).
  10. Realtime: same pattern as Task 7 Step 3.12, scoped to `communityPostDetailRealtimeProvider(postId)`.
  11. A `match_result`/`achievement`/`announcement` post (server-supplied, `canDelete`/`canBoost` both `false` typically) renders `matchResult` detail inline when present, and no delete/boost affordances — Review Focus #5.

- [ ] **Step 2: Run to verify failure, implement, run again**

`PostDetailScreen` mirrors `MatchCentreScreen`'s composition style (a header section built from the loaded post, then a `ListView`/`Column` of comments, then a comment-compose row pinned above the keyboard via `Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom))`). Delete actions use `showDialog<bool>` with `l10n.cmtDeleteConfirmYes`/`cmtDeleteConfirmCancel` actions, matching the confirm-dialog convention already implied by 2b's `PopScope` usage elsewhere in this codebase (a plain `AlertDialog`, nothing bespoke). Run tests → PASS.

- [ ] **Step 3: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/community/post_detail_screen.dart test/features/community/post_detail_screen_test.dart
git commit -m "feat(community): post detail — comments, delete post/comment, realtime"
```

---

### Task 9: Boost

**Files:**
- Create: `lib/features/community/boost_sheet.dart`, `test/features/community/boost_sheet_test.dart`

**Interfaces:**
- Consumes: `writeFlowProvider`, `CommunityRepository.boostPost`.
- Produces: `Future<void> showBoostSheet(BuildContext context, {required PostView post});`

- [ ] **Step 1: Write the failing tests** — `test/features/community/boost_sheet_test.dart` (mirror `rating_sheet.dart`'s test shape):
  1. Renders `l10n.cmtBoostConfirmTitle`/`cmtBoostConfirmBody`; confirming calls `boostPost(post.id, idempotencyKey: ...)`.
  2. Success: shows `l10n.cmtBoostSuccess`, invalidates `communityFeedProvider` and `communityPostDetailProvider(post.id)`, and pops the sheet.
  3. `insufficient_coins` → `communityErrorCopy(l10n, 'insufficient_coins')` shown inline, sheet stays open, retry re-enabled.
  4. `already_boosted` and `active_boost_exists` each show their own distinct mapped copy (Review Focus #4) — not the same string.
  5. `PopScope(canPop: !busy)` — dragging/back is blocked while the request is in flight (`enableDrag: false` on the sheet, same as `wager_sheet.dart`).
  6. A second tap while busy is a no-op (`WriteFlow`'s own busy guard — assert the fake repository's `boostPost` call count stays 1).

- [ ] **Step 2: Run to verify failure, implement, run again**

Same structural shape as `wager_sheet.dart`: `showModalBottomSheet` → `_BoostSheetBody extends ConsumerWidget` reading `writeFlowProvider('boost:${post.id}')`. Run tests → PASS.

- [ ] **Step 3: Wire into Task 7/8's entry points** (both were built with a `canBoost`-gated placeholder callback — replace it with `onPressed: () => showBoostSheet(context, post: post)`), re-run those tasks' test files to confirm no regression.

- [ ] **Step 4: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/community/boost_sheet.dart test/features/community/boost_sheet_test.dart lib/features/community/community_feed_screen.dart lib/features/community/post_detail_screen.dart
git commit -m "feat(community): boost flow (200 coins)"
```

---

### Task 10: Statuses / stories

**Files:**
- Create: `lib/features/community/status_tray.dart`, `lib/features/community/status_viewer_screen.dart`, `lib/features/community/status_compose_screen.dart`, `lib/features/community/status_viewers_screen.dart`, `test/features/community/status_tray_test.dart`, `test/features/community/status_viewer_screen_test.dart`, `test/features/community/status_compose_screen_test.dart`, `test/features/community/status_viewers_screen_test.dart`

**Interfaces:**
- Consumes: `communityStatusRingsProvider`, `communityStatusViewersProvider`, `CommunityImageUploader`/`MultiImagePickerPort` (reused from Task 6, single-image use: `pickImages(maxCount: 1)`), `CommunityRepository.postStatus/deleteStatus/viewStatus`.
- Produces:

```dart
class StatusTray extends ConsumerWidget {
  const StatusTray({super.key, required this.onRingTap, required this.onAddYours});
  final void Function(StatusRing ring) onRingTap;
  final VoidCallback onAddYours;
}
class StatusViewerScreen extends ConsumerStatefulWidget { // full-screen, one ring's statuses in order, auto-advance
  const StatusViewerScreen({super.key, required this.ring, required this.onOpenViewers});
  final StatusRing ring;
  final void Function(String statusId) onOpenViewers; // only shown when ring.isSelf
}
class StatusComposeScreen extends ConsumerStatefulWidget { const StatusComposeScreen({super.key}); }
class StatusViewersScreen extends ConsumerWidget { const StatusViewersScreen({super.key, required this.statusId}); final String statusId; }
```

- [ ] **Step 1: Write the failing `StatusTray` tests** — `test/features/community/status_tray_test.dart`:
  1. Empty rings list shows only the "add yours" tile (`l10n.cmtStatusAddYours`), which is always present regardless of sign-in state (tapping it while signed out calls a sign-in redirect, same contract as compose).
  2. A ring with `hasUnseen: true` renders with a distinct visual state (e.g. a colored ring border `Key('status-ring-unseen-<playerId>')`) vs. `hasUnseen: false` (`Key('status-ring-seen-<playerId>')`) — the app never guesses seen/unseen client-side, it renders exactly the server's `hasUnseen`.
  3. Tapping a ring calls `onRingTap(ring)`; tapping "add yours" calls `onAddYours`.
  4. No rings at all (`[]`) shows no error — an empty tray is a valid, common state, not a failure (Review Focus #5).

- [ ] **Step 2: Run to verify failure, implement, run again.**

- [ ] **Step 3: Write the failing `StatusViewerScreen` tests** — `test/features/community/status_viewer_screen_test.dart`:
  1. Renders the ring's first `StatusRow`; tapping the right half advances to the next, left half goes back; on the last status, tapping right closes the viewer (pop).
  2. On **open** of each status, calls `viewStatus(status.id)` exactly once per status shown (not re-called on back-then-forward-again within the same screen session — track shown-ids locally) — matches the spec's "best-effort, never surfaces as an error" contract (a thrown `viewStatus` call is swallowed silently, no error UI, per spec §4's `POST /community/statuses/{id}/view`).
  3. `ring.isSelf: true` shows a "viewers" entry point calling `onOpenViewers(status.id)`; `ring.isSelf: false` shows none (author-only, per spec §3's server-enforcement note — the client never even offers the control for someone else's ring).
  4. An expired status (`expiresAt` in the past — can still arrive if the ring was cached slightly stale) renders `l10n.cmtStatusValidation`... **correction**: renders a distinct "expired" placeholder rather than a broken image; this plan does not invent new copy for this rare edge beyond reusing an existing neutral empty-state pattern — implement by checking `DateTime.parse(status.expiresAt).isBefore(DateTime.now())` and, if true, auto-advancing past it without ever calling `viewStatus` for it.

- [ ] **Step 4: Run to verify failure, implement, run again.**

- [ ] **Step 5: Write the failing `StatusComposeScreen` tests** — `test/features/community/status_compose_screen_test.dart` (mirrors Task 6's compose tests at smaller scale — single image, optional caption):
  1. No image and no caption — submit disabled (`l10n.cmtStatusValidation` shown once attempted).
  2. Caption-only submit calls `postStatus(caption: ..., imageUrl: null, idempotencyKey: ...)`.
  3. Image-only submit uploads via `CommunityImageUploader` (same bucket/path helper as Task 6, `communityImagePath`) then calls `postStatus(imageUrl: <url>, caption: null, ...)`.
  4. Upload failure → `communityErrorCopy(l10n, 'upload_failed')`, image stays picked for retry (same contract as compose).
  5. Success invalidates `communityStatusRingsProvider` and pops.

- [ ] **Step 6: Run to verify failure, implement, run again.** (Reuses `CommunityPostSubmitter`'s single-image case, or a thinner dedicated helper if the two diverge enough to be clearer separate — implementer's call, log as a Ruling either way.)

- [ ] **Step 7: Write the failing `StatusViewersScreen` tests** — `test/features/community/status_viewers_screen_test.dart`:
  1. Loading/error/data list of `StatusViewer`s.
  2. Empty viewers list shows `l10n.cmtStatusViewersEmpty`, not a blank screen.
  3. The screen is only ever reachable from `StatusViewerScreen`'s `onOpenViewers`, which only appears for `ring.isSelf` — no separate test needed here beyond confirming the screen itself renders correctly given any `statusId`; the authorization is server-enforced (spec §3) and the previous task's test already confirms the client never offers the entry point for someone else's status.

- [ ] **Step 8: Run to verify failure, implement, run again.**

- [ ] **Step 9: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/community/status_tray.dart lib/features/community/status_viewer_screen.dart lib/features/community/status_compose_screen.dart lib/features/community/status_viewers_screen.dart test/features/community
git commit -m "feat(community): statuses/stories — tray, viewer, compose, author-only viewer list"
```

---

### Task 11: Report

**Files:**
- Create: `lib/features/community/report_sheet.dart`, `test/features/community/report_sheet_test.dart`

**Interfaces:**
- Consumes: `writeFlowProvider`, `CommunityRepository.reportPost/reportComment`.
- Produces: `Future<void> showReportSheet(BuildContext context, {required ReportTarget target});` where `class ReportTarget { const ReportTarget.post(this.id) : isComment = false; const ReportTarget.comment(this.id) : isComment = true; final String id; final bool isComment; }`

- [ ] **Step 1: Write the failing tests** — `test/features/community/report_sheet_test.dart`:
  1. Renders all seven `ReportReasonCode` options as a `RadioGroup<ReportReasonCode>` (mirrors `wager_sheet.dart`'s `RadioGroup` usage) with their `l10n.cmtReportReason*` labels; submit is disabled until one is selected.
  2. An optional note field; submitting with `target.isComment == false` calls `reportPost(id, reasonCode: ..., note: <trimmed or null when empty>, idempotencyKey: ...)`; with `isComment == true` calls `reportComment` instead — same sheet, one branch.
  3. Success shows `l10n.cmtReportSubmitted` and pops.
  4. `already_reported` shows `communityErrorCopy(l10n, 'already_reported')`, distinct from a generic failure (Review Focus #4), and the sheet stays open (the player already knows; closing on this specific error would just make them wonder if it went through — showing the "already reported" state in place is clearer, matching the boost sheet's stay-open-on-business-error pattern from Task 9).
  5. Fingerprinting: changing the selected reason or the note text between attempts changes `WriteFlow`'s fingerprint (assert via two failed-then-retried attempts with different reasons producing two distinct API idempotency keys — mirror `wager_sheet.dart`'s `fingerprint: '$pick:$stake'` test approach).
  6. Signed-out: this sheet is never shown to a signed-out user — the calling screen (post detail / a future comment row) gates the entry point itself, same contract as reactions/comments; this task's tests only cover the sheet's own behavior once opened by an already-signed-in caller. **Note the gating obligation in Task 8's own test suite** if it wasn't already covered there (cross-check when implementing).

- [ ] **Step 2: Run to verify failure, implement, run again**

Same structural shape as `boost_sheet.dart`/`wager_sheet.dart`.

- [ ] **Step 3: Wire the entry points** — a report menu item on `PostCard` (Task 7) and on each comment row in `PostDetailScreen` (Task 8), each gated the same way delete is (signed-in required; report your own content is allowed server-side per the spec, no client-side self-report block since the spec doesn't impose one — don't invent a restriction it doesn't have). Re-run Task 7/8's test files to confirm no regression.

- [ ] **Step 4: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/community/report_sheet.dart test/features/community/report_sheet_test.dart lib/features/community/post_card.dart lib/features/community/post_detail_screen.dart
git commit -m "feat(community): report post/comment"
```

---

### Task 12: Router + web link wiring

**Files:**
- Modify: `lib/router/app_router.dart`, `lib/core/routing/web_links.dart`
- Modify: `test/router/app_router_test.dart` (add cases; do not restructure existing ones)

**Interfaces:** none new — wires everything built in Tasks 1–11 into navigable routes.

- [ ] **Step 1: Write the failing router tests** — append to `test/router/app_router_test.dart` (or a new `test/router/community_router_test.dart` if the existing file is already large — implementer's call, matching whichever the file's current size suggests, per this repo's established practice of splitting router tests when a file grows unwieldy):
  1. `/community` renders `CommunityFeedScreen` inside the tab shell (bottom nav still present) — replacing the old `ComingSoonScreen` assertion.
  2. `/community/compose` renders `ComposeScreen`.
  3. Tapping a post in the feed navigates to `/community/<id>` rendering `PostDetailScreen`.
  4. `/community/statuses/compose` renders `StatusComposeScreen`.
  5. A web link `https://sentinelxesports.com.ng/community/abc123` (via `resolveWebLink`) resolves to `/community/abc123`, not `/community` (mirrors the existing tournament-slug/match-id web-link tests).
  6. Bare `https://sentinelxesports.com.ng/community` still resolves to `/community` (existing case — must not regress).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/router/app_router_test.dart` (or the new file) → FAIL.

- [ ] **Step 3: Implement**

In `app_router.dart`, replace:
```dart
StatefulShellBranch(routes: [
  GoRoute(path: '/community', builder: (context, state) => ComingSoonScreen(title: 'Community', onLogoTap: () => context.go('/'))),
]),
```
with:
```dart
StatefulShellBranch(routes: [
  GoRoute(
    path: '/community',
    builder: (context, state) => CommunityFeedScreen(
      onCompose: () => context.push('/community/compose'),
      onPostTap: (post) => context.push('/community/${post.id}'),
      onLogin: () => context.push('/login'),
      onStatusTap: (ring) => context.push('/community/statuses/${ring.playerId}', extra: ring),
      onAddStatus: () => context.push('/community/statuses/compose'),
    ),
    routes: [
      GoRoute(path: 'compose', builder: (context, state) => const ComposeScreen()),
      GoRoute(
        path: 'statuses/compose',
        builder: (context, state) => const StatusComposeScreen(),
      ),
      GoRoute(
        path: 'statuses/:playerId',
        builder: (context, state) {
          final ring = state.extra as StatusRing?;
          if (ring == null) return const _StatusRouteGate(); // cold deep link with no `extra` — out of scope for push/App-Links this phase (statuses aren't in resolveWebLink's switch); render a graceful fallback that pops, not a crash.
          return StatusViewerScreen(ring: ring, onOpenViewers: (id) => context.push('/community/statuses/$id/viewers'));
        },
      ),
      GoRoute(
        path: 'statuses/:statusId/viewers',
        builder: (context, state) => StatusViewersScreen(statusId: state.pathParameters['statusId']!),
      ),
      GoRoute(
        path: ':id',
        builder: (context, state) => PostDetailScreen(
          postId: state.pathParameters['id']!,
          onLogin: () => context.push('/login'),
          onDeleted: () => context.pop(),
        ),
      ),
    ],
  ),
]),
```
A cold `/community/statuses/:playerId` deep link with no `extra` has no server endpoint in this spec to hydrate a single ring by id (unlike Phase 2b's `/matches/:id/result`, which *does* have `matchInfoProvider` to fetch from — `_ResultRouteGate` there is a genuine loading gate, not a true analog for this case). `_StatusRouteGate` is instead a same-frame redirect back to the tray, since there is nothing to load:

```dart
class _StatusRouteGate extends StatelessWidget {
  const _StatusRouteGate();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/community');
    });
    return const Scaffold(body: SizedBox.shrink());
  }
}
```
Log this as a Ruling — status rings aren't in `resolveWebLink`'s switch and aren't a push/App-Link target this phase, so this is a deliberate, narrow gap (a ring tapped from within the app always carries `extra`; only a hand-typed or externally-constructed URL hits this path), not an oversight.

In `web_links.dart`, add (alongside the existing `tournaments`/`seasons`/`matches` two-segment cases):
```dart
if (segments.length == 2 && segments.first == 'community') {
  return '/community/${Uri.encodeComponent(segments[1])}';
}
```
placed **before** the `switch (segments.join('/'))` block's bare `'community'` case (unreachable otherwise since a 2-segment path never matches a 1-segment switch case, but ordering it consistently with the existing `tournaments`/`matches` checks above the switch keeps the file's structure uniform).

- [ ] **Step 4: Run and commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/router/app_router.dart lib/core/routing/web_links.dart test/router
git commit -m "feat(community): router wiring — feed, compose, post detail, statuses"
```

---

## Final verification (before handing off for review)

```bash
flutter analyze
flutter test
git status
```
Expected: analyze clean, all tests passing (555 baseline + every test added across Tasks 1–12). Record the final count in the Stage D handoff note, the same way every prior phase's handoff has. Get this reviewed (fresh-context review pass, same mechanism every prior phase used), fix findings, re-verify green, then merge and push directly to mobile `master` immediately — no PR, per the project's standing practice (see `[[feedback-merge-and-push-immediately]]`-equivalent guidance already followed by every prior phase's handoff note).

Report explicitly in the handoff: the branch + HEAD, final test count, every Ruling made across all 12 tasks, what's deferred (see "Deferred / known gaps" above), and — prominently, not buried — that report-submission and `community_posts`-INSERT-realtime cannot be verified live until the Stage B migration (`community_content_reports` table + `community_posts` realtime publication) is applied to a real database, which is outside this plan's scope to fix.
