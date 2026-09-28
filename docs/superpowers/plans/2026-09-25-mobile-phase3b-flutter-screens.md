# Mobile Phase 3b (Flutter) — Player Profiles, Follow, My Progress & Histories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the player directory, public profile (with Follow), followers/following lists, and the owner-only "My progress" area (XP/tier, SX Score, coins, season standing, three cursor-paged histories) in the Flutter app, backed by the eleven Phase 3b web endpoints, matching the web profile page.

**Architecture:** Same shape as Phase 3a: hand-written `ApiClient` methods + plain-Dart models with `fromJson`; one repository per feature behind a Riverpod `Provider`; screens are `ConsumerWidget`s that read `FutureProvider`/`AsyncNotifier`s. New feature folders `lib/features/{players,progress}/`; shared files are touched by *appended lines* only. Follow is the phase's only write: an optimistic controller that rolls back on failure and reuses one `Idempotency-Key` per tap.

**Tech Stack:** Flutter (stable), Dart ^3.11, `flutter_riverpod` ^3.3 (manual providers, no codegen), `go_router` ^17, `dio`, `flutter_test`. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-24-mobile-phase3b-profiles-progress-design.md` **in the web repo** (`C:\Users\gorok\Videos\sentinelx`), §1, §4–§7 especially. Web-side plan: `docs/superpowers/plans/2026-09-24-mobile-phase3b-web-api.md` (same web repo). Wire shapes are defined by `lib/mobile-api/endpoints/players-schemas.ts`, `progress.ts` and `histories.ts` in the web repo (branch `phase3b/web-endpoints`, worktree `C:\Users\gorok\Videos\sentinelx-p3b-web`); Task 1's models match them field-for-field. Read this repo's `CLAUDE.md` first. Master spec: §8.8 (profile), §8.13 (XP/SX/coins display).

## Global Constraints

- **All reads and the one write go through `ApiClient`** (`/api/mobile/v1/*`). Never read or write Supabase/PostgREST directly for these screens. Screens never construct a repository or `ApiClient` — they read providers.
- **Every new `ApiClient` method must be listed in `ApiClient.usedOperations`** (operationId → `'method /api/mobile/v1/path'`); `test/core/api_contract_test.dart` checks each against `api/openapi.json`. `api/openapi.json` is a **copy** of the web repo's `openapi/mobile-v1.json` — copy it, never hand-edit it.
- **Copy is never hard-coded in widgets.** The web `messages/en.json` has no profile/progress namespace (verified 2026-09-25: only the nav label `players`), so add the new keys **directly to `lib/core/l10n/app_en.arb`** and run `flutter gen-l10n`; never edit `lib/core/l10n/gen/*` by hand. `test/core/l10n_test.dart` requires `app_fr.arb` to define exactly the keys of `app_en.arb`, so every new key **also goes into `app_fr.arb`** (French text; flag it for native review in the PR).
- **Do not touch the temporary tournaments slice** (`lib/data`, `lib/models`, `lib/features/tournaments`).
- **New models live in `lib/core/api/players_models.dart`**, not `models.dart`. Edits to `api_client.dart`, `app_router.dart`, `web_links.dart`, `home_screen.dart`, `account_screen.dart` are **appended lines / new routes only**, except the two signature changes called out in Tasks 2 and 9.
- **No Dart copy of server logic.** Tier math, rank, streak, rarity order and achievement showcase come from the API as-is; never recompute `xpForNextTier`, never re-sort `achievements.unlocked`.
- **Locked achievements:** the API sends only `total` and `unlockedCount` for them. The app renders `total - unlockedCount` anonymous lock tiles and can never show a locked name/description — do not add any client-side catalogue.
- **Viewer state comes only from `GET /me/follows`** ("Following", "Follows you", the Follow button). Public responses carry none. Signed out → never call any `/me/*` endpoint.
- **Cosmetics:** render only the avatar `frameUrl` (site-relative → resolve with `resolveAsset` from 3a's `player_avatar.dart`). `profileTheme` / `usernameColour` slugs are parsed but **not rendered** in this phase (the app has no slug→style map; a follow-up, not a Dart copy of the web tables). Directory rows carry only `equippedAvatarBorder` (a slug), so directory avatars render **without** a frame.
- **Mobile-first at 375px**; no horizontal overflow (including long display names and 300-char bios). Use `SxColors` (`lib/core/theme/sx_colors.dart`); no new colors.
- **Testing against production is forbidden, and Follow is a write.** Run the follow round trip only against a non-production database (Task 10). Test accounts use the `zzqa_` prefix and are logged in `TESTING-NOTES.md`.
- **Before every commit:** `flutter analyze` (no issues) and `flutter test` (all pass). Regenerate l10n after ARB edits and commit the generated output.
- American spelling in new prose/code.

## Review Focus

Failure modes the spec implies but that are easy to ship broken, most likely first. Each has a test in the task that owns the code.

1. **Follow failure paths.** Blocked (403 `follow_blocked`), self (400 `cannot_follow_self`), unknown (404), expired session (401), and network failure must each restore the *exact* pre-tap state and show a distinct message; a rapid second tap while the first is in flight must be ignored; a network-failure retry must reuse the *same* `Idempotency-Key`. (Task 5)
2. **Signed out.** No `/me/follows` or `/me/progress` request is ever made; tapping Follow opens login instead of flipping state; the progress screen shows a login prompt. (Tasks 5, 6, 7)
3. **Tombstones and empty/odd data.** A follower entry with `username == null` renders "Deleted player" and is not tappable; a profile with 0 achievements (`total: 0`), `rank: null`, `bio: null`, no titles/matches/posts renders without a crash or empty gaps; long name/bio at 375px does not overflow; a 404 profile shows a neutral "player not found". (Tasks 6)
4. **History paging.** A failed `loadMore` must show a retry tile and must *not* loop; the last page (`nextCursor == null`) stops fetching; the same page is never requested twice; an unknown `source`/`eventType` code renders a humanized label, never blank or a crash; negative amounts render with a minus. (Tasks 3, 8)
5. **Stale public cache.** `GET /players/{username}` is cached 60 s, so the follower count returned right after a follow is stale; the profile must adjust the displayed count locally for the session (+1 on a created follow, −1 on an unfollow of a followed player) rather than show an unchanged number. (Task 5)

## Coordination (shared-file hotspots)

Phase 3a (Flutter) and Phase 2b are being built in this same repo. **This plan must be based on 3a's branch** (Task 0), because it reuses 3a's `PlayerAvatar`, `resolveAsset`, `commonDeletedPlayer` ARB key and `ApiClient._withQuery`. Hotspots: `lib/core/api/api_client.dart` (append methods/`usedOperations` lines; one optional-param change to `_send`), `api/openapi.json` (re-copy, never merge text), `lib/router/app_router.dart` (add routes only), ARB + generated l10n (regenerate after rebase), `home_screen.dart` (one tile), `account_screen.dart` (one tile + one constructor param). Rebase onto `origin/master` before the final run of the checks; if 3a has merged by then, rebase drops the base commits automatically.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/api/players_models.dart` (create) | `PlayerListItem`, `FollowEntry`, `FollowSets`, `FollowOutcome`, `PlayerProfile` + parts, `MyProgress` + parts, `HistoryPage<T>`, `XpEvent`, `SxScoreEvent`, `CoinTransaction` — `fromJson` only |
| `lib/core/utils/idempotency_key.dart` (create) | `newIdempotencyKey()` — UUID v4 from `Random.secure()` (no new dependency) |
| `lib/core/api/api_client.dart` (modify) | 11 methods + `usedOperations`; `_send` gains optional `headers` |
| `lib/features/players/players_repository.dart` (create) | `PlayersRepository` + `ApiPlayersRepository` |
| `lib/features/players/players_providers.dart` (create) | search query/provider, profile family, follow-list family, `myFollowsProvider`, follow controller, follower delta |
| `lib/features/players/players_directory_screen.dart` (create) | Debounced search + rows |
| `lib/features/players/player_profile_screen.dart` (create) | Profile screen + follow button |
| `lib/features/players/profile_sections.dart` (create) | Stateless section widgets (header, stats, achievements, matches, titles, posts, gallery) |
| `lib/features/players/follow_list_screen.dart` (create) | Followers / following screen (one widget, `FollowListKind`) |
| `lib/features/progress/progress_repository.dart` (create) | `ProgressRepository` + `ApiProgressRepository` |
| `lib/features/progress/progress_providers.dart` (create) | `progressProvider`, `HistoryNotifier<T>`, three history providers |
| `lib/features/progress/history_labels.dart` (create) | `humanizeCode`, `xpSourceLabel`, `scoreEventLabel`, `coinSourceLabel`, `tierLabel` |
| `lib/features/progress/my_progress_screen.dart` (create) | Progress overview |
| `lib/features/progress/history_list_screen.dart` (create) | Generic infinite-scroll history list + three row builders |
| `lib/core/l10n/app_en.arb` (modify) | New keys (Task 3) |
| `lib/router/app_router.dart` (modify) | Player routes in Compete branch; progress routes under `/account` |
| `lib/core/routing/web_links.dart` (modify) | Map `/players…` web paths |
| `lib/features/home/home_screen.dart` (modify) | "Players" entry tile |
| `lib/features/account/account_screen.dart` (modify) | "My progress" tile (signed in only) |
| `test/…` beside each (create) | See tasks; shared fixtures in `test/support/players_fixtures.dart` |

---

### Task 0: Worktree, base, contract, live-schema check

**Files:** none committed except `api/openapi.json` (Task 1).

- [ ] **Step 1: Confirm the base has 3a's shared pieces**

```bash
cd C:\Users\gorok\sentinelx_mobile
git fetch origin
git branch -a --list "*phase3a*"
git ls-tree -r origin/master --name-only | findstr /c:"lib/shared/widgets/player_avatar.dart"
```

- If `player_avatar.dart` is on `origin/master` → base on `origin/master`.
- Else if branch `phase3a/screens` exists (local or remote) and contains it → base on that branch.
- Else **stop and report**: 3a's Flutter Tasks 1–3 (models, client `_withQuery`, `PlayerAvatar` + `commonDeletedPlayer`) must exist first. Do not fork or re-create them.

- [ ] **Step 2: Create the worktree and prove a green base**

```bash
git worktree add ..\sentinelx_mobile-p3b -b phase3b/screens <base>
cd ..\sentinelx_mobile-p3b
flutter pub get
flutter analyze && flutter test
```
Expected: clean and green. If not, stop and report; do not build on a red base.

- [ ] **Step 3: Confirm the three 3a pieces this plan consumes**

```bash
findstr /c:"class PlayerAvatar" /c:"String? resolveAsset" lib\shared\widgets\player_avatar.dart
findstr /c:"_withQuery" lib\core\api\api_client.dart
findstr /c:"commonDeletedPlayer" lib\core\l10n\app_en.arb
```
Each must print a match. If `resolveAsset` has a different signature than `resolveAsset(String? path, String siteUrl)`, use the real one everywhere this plan says `resolveAsset`.

- [ ] **Step 4: Get the contract (do this now; Task 1's client test depends on it)**

The eleven operations exist only on the web branch until web PR 2 merges:

```bash
copy C:\Users\gorok\Videos\sentinelx-p3b-web\openapi\mobile-v1.json api\openapi.json
findstr /c:"getPlayerProfile" /c:"getMyCoinTransactions" /c:"followPlayer" api\openapi.json
```
All three must match. If the web branch has moved, re-copy from the newest of `phase3b/web-endpoints` (or `main` once merged).

- [ ] **Step 5: Live schema check (read-only; needed for Task 3's label maps)**

The web plan's Task 10 Step 1 records the live CHECK value lists in the web PR 2 description. Read them there. If PR 2 has not recorded them, run (Supabase MCP `execute_sql`, **read-only**, against the non-production project):

```sql
select conrelid::regclass as tbl, pg_get_constraintdef(oid) from pg_constraint
 where conrelid in ('public.xp_events'::regclass,'public.sx_score_events'::regclass,'public.sx_coin_transactions'::regclass) and contype='c';
```
Compare with the lists Task 3 hard-codes (from migrations up to 064). **Any code on the live list but not in Task 3's `switch` still renders correctly** (humanized fallback), so a missing MCP connection does not block; add the extra codes to the switch + ARB if you can read them. Record what you found in the PR description.

---

### Task 1: Contract models

**Files:**
- Create: `lib/core/api/players_models.dart`, `test/core/players_models_test.dart`, `test/support/players_fixtures.dart`
- Modify: `api/openapi.json` (already re-copied in Task 0)

**Interfaces:**
- Produces (all in `players_models.dart`; every class has `factory X.fromJson(Map<String, dynamic> j)` unless noted):

```dart
class PlayerListItem { String username; String? displayName; String? avatarUrl; int sxScore; String? sentinelTier; String membershipTier; String? equippedAvatarBorder; String get label; }
class FollowEntry { String id; String? username; String? displayName; String? avatarUrl; String membershipTier; bool get isDeleted; String get label; }
class FollowSets { Set<String> followingIds; Set<String> followerIds; FollowSets copyWith({Set<String>? followingIds, Set<String>? followerIds}); }
class FollowOutcome { bool following; bool created; }            // unfollow parses as created:false
class ProfileHeader { String id; String username; String? displayName; String? avatarUrl; String? frameUrl; String? profileTheme;
  String? usernameColour; String? country; String? bio; String? createdAt; int sxScore; String? sentinelTier; String membershipTier; int xp; String get label; }
class CategoryStat { String category; int scored; int conceded; }
class ProfileStats { int totalMatches; int wins; int losses; int goalsScored; int goalsConceded; int totalTitles; int tournamentsPlayed;
  int currentStreak; int? rank; int? totalRankedPlayers; int followerCount; int followingCount; List<CategoryStat> categoryStats; }
class ProfileTitle { String tournamentTitle; String tournamentSlug; String? gameName; String? date; }
class ProfileMatch { String id; String opponentName; int playerScore; int opponentScore; String outcome; String? tournamentTitle; String? completedAt; }  // outcome: win|loss|draw
class UnlockedAchievement { String slug; String name; String description; String category; String unlockedAt; int unlockCount; }
class Achievements { int total; int unlockedCount; List<UnlockedAchievement> unlocked; List<String> showcase; int get lockedCount; }   // lockedCount = max(0, total - unlockedCount)
class ProfilePost { String id; String content; String postType; String createdAt; }
class GalleryImage { String id; String imageUrl; }
class PlayerProfile { ProfileHeader player; ProfileStats stats; List<ProfileTitle> titles; List<ProfileMatch> recentMatches;
  Achievements achievements; List<ProfilePost> posts; List<GalleryImage> gallery; }
class TierProgress { String current; String next; int xpIntoTier; int xpForNextTier; double get fraction; }  // clamp(0,1); 0 if xpForNextTier <= 0
class SeasonStanding { String? seasonName; int? rank; int points; int pointsAtRankSixteen; int? monthlyRank; int monthlyPoints; }
class MyProgress { int xp; String membershipTier; TierProgress? tierProgress; int sxScore; String? sentinelTier; int coinBalance; SeasonStanding? seasonStanding; }
class HistoryPage<T> { List<T> items; String? nextCursor; }
class XpEvent { String id; int xp; String source; String createdAt; }
class SxScoreEvent { String id; String eventType; int pointsDelta; String? matchId; String createdAt; }
class CoinTransaction { String id; int amount; int balanceAfter; String source; String? description; String createdAt; }
```
`HistoryPage.fromJson` is a static `HistoryPage<T> parse<T>(Map<String, dynamic> j, T Function(Map<String, dynamic>) item)`. Numbers arrive as JSON `num`: parse ints with `(v as num).toInt()`.

- [ ] **Step 1: Write the fixtures**

```dart
// test/support/players_fixtures.dart
Map<String, dynamic> profileJson({
  String id = 'p1',
  String username = 'ada',
  String? bio = 'Plays DLS.',
  int totalAchievements = 5,
  int unlockedAchievements = 2,
  int followerCount = 10,
  int? rank = 3,
  int? totalRanked = 120,
  bool withActivity = true,
}) =>
    {
      'player': {
        'id': id, 'username': username, 'displayName': 'Ada', 'avatarUrl': null, 'frameUrl': null,
        'profileTheme': null, 'usernameColour': null, 'country': 'NG', 'bio': bio,
        'createdAt': '2026-01-05T10:00:00+00:00', 'sxScore': 980, 'sentinelTier': 'trusted',
        'membershipTier': 'guardian', 'xp': 1500,
      },
      'stats': {
        'totalMatches': 20, 'wins': 12, 'losses': 6, 'goalsScored': 40, 'goalsConceded': 22, 'totalTitles': 1,
        'tournamentsPlayed': 4, 'currentStreak': 3, 'rank': rank, 'totalRankedPlayers': totalRanked,
        'followerCount': followerCount, 'followingCount': 4,
        'categoryStats': [
          {'category': 'football', 'scored': 40, 'conceded': 22},
        ],
      },
      'titles': withActivity
          ? [
              {'tournamentTitle': 'Masters Sept', 'tournamentSlug': 'masters-sept', 'gameName': 'DLS', 'date': '2026-09-20'},
            ]
          : [],
      'recentMatches': withActivity
          ? [
              {
                'id': 'm1', 'opponentName': 'Bola', 'playerScore': 3, 'opponentScore': 1, 'outcome': 'win',
                'tournamentTitle': 'Masters Sept', 'completedAt': '2026-09-20T18:00:00+00:00',
              },
              {
                'id': 'm2', 'opponentName': 'TBD', 'playerScore': 0, 'opponentScore': 0, 'outcome': 'draw',
                'tournamentTitle': null, 'completedAt': null,
              },
            ]
          : [],
      'achievements': {
        'total': totalAchievements,
        'unlockedCount': unlockedAchievements,
        'unlocked': [
          for (var i = 0; i < unlockedAchievements; i++)
            {
              'slug': 'a$i', 'name': 'Achievement $i', 'description': 'Desc $i', 'category': 'match',
              'unlockedAt': '2026-02-0${i + 1}T00:00:00+00:00', 'unlockCount': i + 1,
            },
        ],
        'showcase': unlockedAchievements > 0 ? ['a0'] : <String>[],
      },
      'posts': withActivity
          ? [
              {'id': 'po1', 'content': 'GG everyone', 'postType': 'manual', 'createdAt': '2026-09-21T10:00:00+00:00'},
            ]
          : [],
      'gallery': withActivity
          ? [
              {'id': 'g1', 'imageUrl': 'https://img.test/1.png'},
            ]
          : [],
    };

Map<String, dynamic> followEntryJson(String id, String? username, {String tier = 'recruit'}) => {
      'id': id, 'username': username, 'displayName': username == null ? null : username.toUpperCase(),
      'avatarUrl': null, 'membershipTier': tier,
    };
```

- [ ] **Step 2: Write the failing model tests**

```dart
// test/core/players_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';

import '../support/players_fixtures.dart';

void main() {
  test('PlayerProfile parses every section, including nullable rank and match fields', () {
    final p = PlayerProfile.fromJson(profileJson());
    expect(p.player.label, 'Ada');
    expect(p.player.xp, 1500);
    expect(p.stats.rank, 3);
    expect(p.stats.categoryStats.single.category, 'football');
    expect(p.titles.single.gameName, 'DLS');
    expect(p.recentMatches.last.completedAt, isNull);
    expect(p.recentMatches.first.outcome, 'win');
    expect(p.posts.single.postType, 'manual');
    expect(p.gallery.single.imageUrl, 'https://img.test/1.png');
  });

  test('achievements: only unlocked objects exist; locked is a pure count', () {
    final a = PlayerProfile.fromJson(profileJson(totalAchievements: 5, unlockedAchievements: 2)).achievements;
    expect(a.unlocked.map((x) => x.slug), ['a0', 'a1']); // server (rarity) order preserved, never re-sorted
    expect(a.lockedCount, 3);
    expect(a.showcase, ['a0']);
  });

  test('achievements: total 0 and total < unlocked never go negative', () {
    expect(PlayerProfile.fromJson(profileJson(totalAchievements: 0, unlockedAchievements: 0)).achievements.lockedCount, 0);
    expect(PlayerProfile.fromJson(profileJson(totalAchievements: 1, unlockedAchievements: 2)).achievements.lockedCount, 0);
  });

  test('profile with null rank, null bio and no activity parses', () {
    final p = PlayerProfile.fromJson(profileJson(rank: null, totalRanked: null, bio: null, withActivity: false));
    expect(p.stats.rank, isNull);
    expect(p.stats.totalRankedPlayers, isNull);
    expect(p.player.bio, isNull);
    expect(p.titles, isEmpty);
    expect(p.recentMatches, isEmpty);
  });

  test('FollowEntry with a null username is a tombstone with an empty label', () {
    final e = FollowEntry.fromJson(followEntryJson('u1', null));
    expect(e.isDeleted, isTrue);
    expect(e.label, '');
    expect(FollowEntry.fromJson(followEntryJson('u2', 'ada')).isDeleted, isFalse);
  });

  test('PlayerListItem label prefers displayName, falls back to username', () {
    final base = {'username': 'ada', 'displayName': null, 'avatarUrl': null, 'sxScore': 9, 'sentinelTier': null, 'membershipTier': 'recruit', 'equippedAvatarBorder': null};
    expect(PlayerListItem.fromJson(base).label, 'ada');
    expect(PlayerListItem.fromJson({...base, 'displayName': 'Ada'}).label, 'Ada');
  });

  test('FollowSets and FollowOutcome parse', () {
    final s = FollowSets.fromJson({'followingIds': ['a', 'b'], 'followerIds': ['c']});
    expect(s.followingIds, {'a', 'b'});
    expect(s.copyWith(followingIds: {'z'}).followerIds, {'c'});
    expect(FollowOutcome.fromJson({'following': true, 'created': false}).created, isFalse);
    expect(FollowOutcome.fromJson({'following': false}).created, isFalse);
  });

  test('MyProgress: null tierProgress at max tier and null seasonStanding with no season', () {
    final p = MyProgress.fromJson({
      'xp': 60000, 'membershipTier': 'legend', 'tierProgress': null, 'sxScore': 1500, 'sentinelTier': null,
      'coinBalance': 1234, 'seasonStanding': null,
    });
    expect(p.tierProgress, isNull);
    expect(p.seasonStanding, isNull);
    expect(p.coinBalance, 1234);
  });

  test('TierProgress.fraction is clamped and safe against a zero denominator', () {
    TierProgress t(int into, int need) => TierProgress.fromJson({'current': 'recruit', 'next': 'guardian', 'xpIntoTier': into, 'xpForNextTier': need});
    expect(t(250, 1000).fraction, 0.25);
    expect(t(2000, 1000).fraction, 1.0);
    expect(t(5, 0).fraction, 0.0);
  });

  test('SeasonStanding parses nullable ranks', () {
    final s = SeasonStanding.fromJson({
      'seasonName': null, 'rank': null, 'points': 0, 'pointsAtRankSixteen': 40, 'monthlyRank': 7, 'monthlyPoints': 12,
    });
    expect(s.rank, isNull);
    expect(s.monthlyRank, 7);
  });

  test('history rows parse, including negative deltas and nullable fields', () {
    final xp = HistoryPage.parse({'items': [{'id': '1', 'xp': 10, 'source': 'match_won', 'createdAt': '2026-09-01T00:00:00+00:00'}], 'nextCursor': 'c1'}, XpEvent.fromJson);
    expect(xp.items.single.xp, 10);
    expect(xp.nextCursor, 'c1');
    final sx = HistoryPage.parse({'items': [{'id': '2', 'eventType': 'no_show', 'pointsDelta': -15, 'matchId': null, 'createdAt': 'x'}], 'nextCursor': null}, SxScoreEvent.fromJson);
    expect(sx.items.single.pointsDelta, -15);
    expect(sx.items.single.matchId, isNull);
    expect(sx.nextCursor, isNull);
    final coin = HistoryPage.parse({'items': [{'id': '3', 'amount': -200, 'balanceAfter': 50, 'source': 'post_boost', 'description': null, 'createdAt': 'x'}], 'nextCursor': null}, CoinTransaction.fromJson);
    expect(coin.items.single.amount, -200);
    expect(coin.items.single.description, isNull);
  });
}
```

- [ ] **Step 3: Run to fail**

Run: `flutter test test/core/players_models_test.dart`
Expected: FAIL — `players_models.dart` does not exist.

- [ ] **Step 4: Implement `players_models.dart`**

```dart
// lib/core/api/players_models.dart
int _int(Object? v) => (v as num).toInt();
int? _intOrNull(Object? v) => v == null ? null : (v as num).toInt();

List<T> _list<T>(Object? v, T Function(Map<String, dynamic> j) parse) =>
    (v as List<dynamic>).map((e) => parse(e as Map<String, dynamic>)).toList();

T? _opt<T>(Object? v, T Function(Map<String, dynamic> j) parse) => v == null ? null : parse(v as Map<String, dynamic>);

class PlayerListItem {
  const PlayerListItem({
    required this.username, required this.displayName, required this.avatarUrl, required this.sxScore,
    required this.sentinelTier, required this.membershipTier, required this.equippedAvatarBorder,
  });

  factory PlayerListItem.fromJson(Map<String, dynamic> j) => PlayerListItem(
        username: j['username'] as String,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        sxScore: _int(j['sxScore']),
        sentinelTier: j['sentinelTier'] as String?,
        membershipTier: j['membershipTier'] as String,
        equippedAvatarBorder: j['equippedAvatarBorder'] as String?,
      );

  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int sxScore;
  final String? sentinelTier;
  final String membershipTier;
  final String? equippedAvatarBorder;

  String get label => displayName ?? username;
}

class FollowEntry {
  const FollowEntry({required this.id, required this.username, required this.displayName, required this.avatarUrl, required this.membershipTier});

  factory FollowEntry.fromJson(Map<String, dynamic> j) => FollowEntry(
        id: j['id'] as String,
        username: j['username'] as String?,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        membershipTier: j['membershipTier'] as String,
      );

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String membershipTier;

  /// A deleted/anonymised account has no username; the API never invents one.
  bool get isDeleted => username == null;
  String get label => displayName ?? username ?? '';
}

class FollowSets {
  const FollowSets({required this.followingIds, required this.followerIds});

  factory FollowSets.fromJson(Map<String, dynamic> j) => FollowSets(
        followingIds: (j['followingIds'] as List<dynamic>).cast<String>().toSet(),
        followerIds: (j['followerIds'] as List<dynamic>).cast<String>().toSet(),
      );

  final Set<String> followingIds;
  final Set<String> followerIds;

  FollowSets copyWith({Set<String>? followingIds, Set<String>? followerIds}) =>
      FollowSets(followingIds: followingIds ?? this.followingIds, followerIds: followerIds ?? this.followerIds);
}

class FollowOutcome {
  const FollowOutcome({required this.following, required this.created});

  /// PUT returns `{following: true, created}`; DELETE returns `{following: false}` (no `created`).
  factory FollowOutcome.fromJson(Map<String, dynamic> j) =>
      FollowOutcome(following: j['following'] as bool, created: j['created'] as bool? ?? false);

  final bool following;
  final bool created;
}

class ProfileHeader {
  const ProfileHeader({
    required this.id, required this.username, required this.displayName, required this.avatarUrl, required this.frameUrl,
    required this.profileTheme, required this.usernameColour, required this.country, required this.bio,
    required this.createdAt, required this.sxScore, required this.sentinelTier, required this.membershipTier, required this.xp,
  });

  factory ProfileHeader.fromJson(Map<String, dynamic> j) => ProfileHeader(
        id: j['id'] as String,
        username: j['username'] as String,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        frameUrl: j['frameUrl'] as String?,
        profileTheme: j['profileTheme'] as String?,
        usernameColour: j['usernameColour'] as String?,
        country: j['country'] as String?,
        bio: j['bio'] as String?,
        createdAt: j['createdAt'] as String?,
        sxScore: _int(j['sxScore']),
        sentinelTier: j['sentinelTier'] as String?,
        membershipTier: j['membershipTier'] as String,
        xp: _int(j['xp']),
      );

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? frameUrl;
  final String? profileTheme;
  final String? usernameColour;
  final String? country;
  final String? bio;
  final String? createdAt;
  final int sxScore;
  final String? sentinelTier;
  final String membershipTier;
  final int xp;

  String get label => displayName ?? username;
}

class CategoryStat {
  const CategoryStat({required this.category, required this.scored, required this.conceded});
  factory CategoryStat.fromJson(Map<String, dynamic> j) =>
      CategoryStat(category: j['category'] as String, scored: _int(j['scored']), conceded: _int(j['conceded']));
  final String category;
  final int scored;
  final int conceded;
}

class ProfileStats {
  const ProfileStats({
    required this.totalMatches, required this.wins, required this.losses, required this.goalsScored, required this.goalsConceded,
    required this.totalTitles, required this.tournamentsPlayed, required this.currentStreak, required this.rank,
    required this.totalRankedPlayers, required this.followerCount, required this.followingCount, required this.categoryStats,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> j) => ProfileStats(
        totalMatches: _int(j['totalMatches']),
        wins: _int(j['wins']),
        losses: _int(j['losses']),
        goalsScored: _int(j['goalsScored']),
        goalsConceded: _int(j['goalsConceded']),
        totalTitles: _int(j['totalTitles']),
        tournamentsPlayed: _int(j['tournamentsPlayed']),
        currentStreak: _int(j['currentStreak']),
        rank: _intOrNull(j['rank']),
        totalRankedPlayers: _intOrNull(j['totalRankedPlayers']),
        followerCount: _int(j['followerCount']),
        followingCount: _int(j['followingCount']),
        categoryStats: _list(j['categoryStats'], CategoryStat.fromJson),
      );

  final int totalMatches;
  final int wins;
  final int losses;
  final int goalsScored;
  final int goalsConceded;
  final int totalTitles;
  final int tournamentsPlayed;
  final int currentStreak;
  final int? rank;
  final int? totalRankedPlayers;
  final int followerCount;
  final int followingCount;
  final List<CategoryStat> categoryStats;
}

class ProfileTitle {
  const ProfileTitle({required this.tournamentTitle, required this.tournamentSlug, required this.gameName, required this.date});
  factory ProfileTitle.fromJson(Map<String, dynamic> j) => ProfileTitle(
        tournamentTitle: j['tournamentTitle'] as String,
        tournamentSlug: j['tournamentSlug'] as String,
        gameName: j['gameName'] as String?,
        date: j['date'] as String?,
      );
  final String tournamentTitle;
  final String tournamentSlug;
  final String? gameName;
  final String? date;
}

class ProfileMatch {
  const ProfileMatch({
    required this.id, required this.opponentName, required this.playerScore, required this.opponentScore,
    required this.outcome, required this.tournamentTitle, required this.completedAt,
  });
  factory ProfileMatch.fromJson(Map<String, dynamic> j) => ProfileMatch(
        id: j['id'] as String,
        opponentName: j['opponentName'] as String,
        playerScore: _int(j['playerScore']),
        opponentScore: _int(j['opponentScore']),
        outcome: j['outcome'] as String,
        tournamentTitle: j['tournamentTitle'] as String?,
        completedAt: j['completedAt'] as String?,
      );
  final String id;
  final String opponentName;
  final int playerScore;
  final int opponentScore;
  final String outcome;
  final String? tournamentTitle;
  final String? completedAt;
}

class UnlockedAchievement {
  const UnlockedAchievement({
    required this.slug, required this.name, required this.description, required this.category,
    required this.unlockedAt, required this.unlockCount,
  });
  factory UnlockedAchievement.fromJson(Map<String, dynamic> j) => UnlockedAchievement(
        slug: j['slug'] as String,
        name: j['name'] as String,
        description: j['description'] as String,
        category: j['category'] as String,
        unlockedAt: j['unlockedAt'] as String,
        unlockCount: _int(j['unlockCount']),
      );
  final String slug;
  final String name;
  final String description;
  final String category;
  final String unlockedAt;
  final int unlockCount;
}

class Achievements {
  const Achievements({required this.total, required this.unlockedCount, required this.unlocked, required this.showcase});
  factory Achievements.fromJson(Map<String, dynamic> j) => Achievements(
        total: _int(j['total']),
        unlockedCount: _int(j['unlockedCount']),
        unlocked: _list(j['unlocked'], UnlockedAchievement.fromJson),
        showcase: (j['showcase'] as List<dynamic>).cast<String>(),
      );
  final int total;
  final int unlockedCount;
  final List<UnlockedAchievement> unlocked;
  final List<String> showcase;

  int get lockedCount => total > unlockedCount ? total - unlockedCount : 0;
}

class ProfilePost {
  const ProfilePost({required this.id, required this.content, required this.postType, required this.createdAt});
  factory ProfilePost.fromJson(Map<String, dynamic> j) => ProfilePost(
        id: j['id'] as String,
        content: j['content'] as String,
        postType: j['postType'] as String,
        createdAt: j['createdAt'] as String,
      );
  final String id;
  final String content;
  final String postType;
  final String createdAt;
}

class GalleryImage {
  const GalleryImage({required this.id, required this.imageUrl});
  factory GalleryImage.fromJson(Map<String, dynamic> j) => GalleryImage(id: j['id'] as String, imageUrl: j['imageUrl'] as String);
  final String id;
  final String imageUrl;
}

class PlayerProfile {
  const PlayerProfile({
    required this.player, required this.stats, required this.titles, required this.recentMatches,
    required this.achievements, required this.posts, required this.gallery,
  });
  factory PlayerProfile.fromJson(Map<String, dynamic> j) => PlayerProfile(
        player: ProfileHeader.fromJson(j['player'] as Map<String, dynamic>),
        stats: ProfileStats.fromJson(j['stats'] as Map<String, dynamic>),
        titles: _list(j['titles'], ProfileTitle.fromJson),
        recentMatches: _list(j['recentMatches'], ProfileMatch.fromJson),
        achievements: Achievements.fromJson(j['achievements'] as Map<String, dynamic>),
        posts: _list(j['posts'], ProfilePost.fromJson),
        gallery: _list(j['gallery'], GalleryImage.fromJson),
      );
  final ProfileHeader player;
  final ProfileStats stats;
  final List<ProfileTitle> titles;
  final List<ProfileMatch> recentMatches;
  final Achievements achievements;
  final List<ProfilePost> posts;
  final List<GalleryImage> gallery;
}

class TierProgress {
  const TierProgress({required this.current, required this.next, required this.xpIntoTier, required this.xpForNextTier});
  factory TierProgress.fromJson(Map<String, dynamic> j) => TierProgress(
        current: j['current'] as String,
        next: j['next'] as String,
        xpIntoTier: _int(j['xpIntoTier']),
        xpForNextTier: _int(j['xpForNextTier']),
      );
  final String current;
  final String next;
  final int xpIntoTier;
  final int xpForNextTier;

  double get fraction => xpForNextTier <= 0 ? 0.0 : (xpIntoTier / xpForNextTier).clamp(0.0, 1.0);
}

class SeasonStanding {
  const SeasonStanding({
    required this.seasonName, required this.rank, required this.points, required this.pointsAtRankSixteen,
    required this.monthlyRank, required this.monthlyPoints,
  });
  factory SeasonStanding.fromJson(Map<String, dynamic> j) => SeasonStanding(
        seasonName: j['seasonName'] as String?,
        rank: _intOrNull(j['rank']),
        points: _int(j['points']),
        pointsAtRankSixteen: _int(j['pointsAtRankSixteen']),
        monthlyRank: _intOrNull(j['monthlyRank']),
        monthlyPoints: _int(j['monthlyPoints']),
      );
  final String? seasonName;
  final int? rank;
  final int points;
  final int pointsAtRankSixteen;
  final int? monthlyRank;
  final int monthlyPoints;
}

class MyProgress {
  const MyProgress({
    required this.xp, required this.membershipTier, required this.tierProgress, required this.sxScore,
    required this.sentinelTier, required this.coinBalance, required this.seasonStanding,
  });
  factory MyProgress.fromJson(Map<String, dynamic> j) => MyProgress(
        xp: _int(j['xp']),
        membershipTier: j['membershipTier'] as String,
        tierProgress: _opt(j['tierProgress'], TierProgress.fromJson),
        sxScore: _int(j['sxScore']),
        sentinelTier: j['sentinelTier'] as String?,
        coinBalance: _int(j['coinBalance']),
        seasonStanding: _opt(j['seasonStanding'], SeasonStanding.fromJson),
      );
  final int xp;
  final String membershipTier;
  final TierProgress? tierProgress;
  final int sxScore;
  final String? sentinelTier;
  final int coinBalance;
  final SeasonStanding? seasonStanding;
}

class HistoryPage<T> {
  const HistoryPage({required this.items, required this.nextCursor});

  static HistoryPage<T> parse<T>(Map<String, dynamic> j, T Function(Map<String, dynamic> j) item) =>
      HistoryPage(items: _list(j['items'], item), nextCursor: j['nextCursor'] as String?);

  final List<T> items;
  final String? nextCursor;
}

class XpEvent {
  const XpEvent({required this.id, required this.xp, required this.source, required this.createdAt});
  factory XpEvent.fromJson(Map<String, dynamic> j) =>
      XpEvent(id: j['id'] as String, xp: _int(j['xp']), source: j['source'] as String, createdAt: j['createdAt'] as String);
  final String id;
  final int xp;
  final String source;
  final String createdAt;
}

class SxScoreEvent {
  const SxScoreEvent({required this.id, required this.eventType, required this.pointsDelta, required this.matchId, required this.createdAt});
  factory SxScoreEvent.fromJson(Map<String, dynamic> j) => SxScoreEvent(
        id: j['id'] as String,
        eventType: j['eventType'] as String,
        pointsDelta: _int(j['pointsDelta']),
        matchId: j['matchId'] as String?,
        createdAt: j['createdAt'] as String,
      );
  final String id;
  final String eventType;
  final int pointsDelta;
  final String? matchId;
  final String createdAt;
}

class CoinTransaction {
  const CoinTransaction({
    required this.id, required this.amount, required this.balanceAfter, required this.source,
    required this.description, required this.createdAt,
  });
  factory CoinTransaction.fromJson(Map<String, dynamic> j) => CoinTransaction(
        id: j['id'] as String,
        amount: _int(j['amount']),
        balanceAfter: _int(j['balanceAfter']),
        source: j['source'] as String,
        description: j['description'] as String?,
        createdAt: j['createdAt'] as String,
      );
  final String id;
  final int amount;
  final int balanceAfter;
  final String source;
  final String? description;
  final String createdAt;
}
```

- [ ] **Step 5: Run to green, analyze, commit**

```bash
flutter test test/core/players_models_test.dart
flutter analyze
git add api/openapi.json lib/core/api/players_models.dart test/core/players_models_test.dart test/support/players_fixtures.dart
git commit -m "feat(api): player profile, follow, progress and history models

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Idempotency key, `ApiClient` methods, contract entries

**Files:**
- Create: `lib/core/utils/idempotency_key.dart`, `test/core/idempotency_key_test.dart`, `test/core/api_client_players_test.dart`
- Modify: `lib/core/api/api_client.dart` (append methods + `usedOperations`; add optional `headers` to `_send`)

**Interfaces:**
- Consumes: models from Task 1; `_withQuery` (3a).
- Produces:

```dart
String newIdempotencyKey([Random? random]);                                      // UUID v4 string

Future<List<PlayerListItem>> searchPlayers({String q = ''});
Future<PlayerProfile> getPlayerProfile(String username);
Future<List<FollowEntry>> getPlayerFollowers(String username);
Future<List<FollowEntry>> getPlayerFollowing(String username);
Future<FollowSets> getMyFollows();
Future<FollowOutcome> followPlayer(String username, {required String idempotencyKey});
Future<FollowOutcome> unfollowPlayer(String username);
Future<MyProgress> getMyProgress();
Future<HistoryPage<XpEvent>> getMyXpEvents({String? cursor});
Future<HistoryPage<SxScoreEvent>> getMySxScoreEvents({String? cursor});
Future<HistoryPage<CoinTransaction>> getMyCoinTransactions({String? cursor});
```
Method names equal the OpenAPI operationIds.

- [ ] **Step 1: Failing tests**

```dart
// test/core/idempotency_key_test.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/utils/idempotency_key.dart';

void main() {
  final v4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

  test('is a well-formed UUID v4', () {
    for (var i = 0; i < 50; i++) {
      expect(newIdempotencyKey(), matches(v4));
    }
  });

  test('two keys differ; a seeded generator is deterministic', () {
    expect(newIdempotencyKey(), isNot(newIdempotencyKey()));
    expect(newIdempotencyKey(Random(7)), newIdempotencyKey(Random(7)));
  });
}
```

```dart
// test/core/api_client_players_test.dart  (copy the _FakeAdapter/_json/_client helpers from test/core/api_client_progress_test.dart — 3a — or api_client_test.dart; do not import them)
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';

import '../support/players_fixtures.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return respond(options);
  }
  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

ApiClient _client(_FakeAdapter a, {String? token = 'tok'}) => ApiClient.create(
    baseUrl: 'https://api.test', appVersion: '1.2.3', platform: 'android', accessToken: () async => token, adapter: a);

void main() {
  test('searchPlayers sends q only when non-empty', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': <Object>[]}));
    await _client(adapter).searchPlayers(q: 'ada');
    await _client(adapter).searchPlayers();
    expect(adapter.requests[0].uri.path, '/api/mobile/v1/players');
    expect(adapter.requests[0].uri.queryParameters, {'q': 'ada'});
    expect(adapter.requests[1].uri.queryParameters, isEmpty);
  });

  test('getPlayerProfile encodes the username and parses; 404 surfaces as ApiException', () async {
    final adapter = _FakeAdapter((o) => o.uri.path.endsWith('/nobody')
        ? _json(404, {'error': {'code': 'not_found', 'message': 'Not found.'}})
        : _json(200, {'data': profileJson()}));
    final api = _client(adapter);
    expect((await api.getPlayerProfile('ada')).player.username, 'ada');
    await expectLater(api.getPlayerProfile('nobody'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)));
    await api.getPlayerProfile('a b/c');
    expect(adapter.requests.last.uri.path, '/api/mobile/v1/players/a%20b%2Fc');
  });

  test('followers/following hit their own paths and parse bare arrays', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': [followEntryJson('u1', 'ada'), followEntryJson('u2', null)]}));
    final api = _client(adapter);
    final f = await api.getPlayerFollowers('ada');
    expect(f.map((e) => e.isDeleted), [false, true]);
    await api.getPlayerFollowing('ada');
    expect(adapter.requests.map((r) => r.uri.path), ['/api/mobile/v1/players/ada/followers', '/api/mobile/v1/players/ada/following']);
  });

  test('getMyFollows needs the bearer token', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': {'followingIds': ['a'], 'followerIds': []}}));
    final sets = await _client(adapter).getMyFollows();
    expect(sets.followingIds, {'a'});
    expect(adapter.requests.single.headers['Authorization'], 'Bearer tok');
  });

  test('followPlayer sends PUT with the Idempotency-Key header; unfollow sends DELETE without one', () async {
    final adapter = _FakeAdapter((o) => o.method == 'PUT'
        ? _json(200, {'data': {'following': true, 'created': true}})
        : _json(200, {'data': {'following': false}}));
    final api = _client(adapter);
    final put = await api.followPlayer('ada', idempotencyKey: 'key-1');
    expect(put.created, isTrue);
    expect(adapter.requests[0].method, 'PUT');
    expect(adapter.requests[0].headers['Idempotency-Key'], 'key-1');
    final del = await api.unfollowPlayer('ada');
    expect(del.following, isFalse);
    expect(adapter.requests[1].method, 'DELETE');
    expect(adapter.requests[1].headers.containsKey('Idempotency-Key'), isFalse);
    expect(adapter.requests[1].uri.path, '/api/mobile/v1/players/ada/follow');
  });

  test('follow error codes reach the caller (self / blocked)', () async {
    final adapter = _FakeAdapter((_) => _json(403, {'error': {'code': 'follow_blocked', 'message': 'nope'}}));
    await expectLater(
      _client(adapter).followPlayer('ada', idempotencyKey: 'k'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'follow_blocked')),
    );
  });

  test('getMyProgress parses and history methods pass the cursor only when set', () async {
    final adapter = _FakeAdapter((o) {
      if (o.uri.path.endsWith('/me/progress')) {
        return _json(200, {'data': {'xp': 10, 'membershipTier': 'recruit', 'tierProgress': null, 'sxScore': 1, 'sentinelTier': null, 'coinBalance': 0, 'seasonStanding': null}});
      }
      return _json(200, {'data': {'items': <Object>[], 'nextCursor': null}});
    });
    final api = _client(adapter);
    expect((await api.getMyProgress()).xp, 10);
    await api.getMyXpEvents();
    await api.getMyXpEvents(cursor: 'abc_-=');
    await api.getMySxScoreEvents(cursor: 'c2');
    await api.getMyCoinTransactions();
    expect(adapter.requests[1].uri.queryParameters, isEmpty);
    expect(adapter.requests[2].uri.queryParameters, {'cursor': 'abc_-='});
    expect(adapter.requests[3].uri.path, '/api/mobile/v1/me/sx-score-events');
    expect(adapter.requests[4].uri.path, '/api/mobile/v1/me/coin-transactions');
  });
}
```

- [ ] **Step 2: Run to fail**

Run: `flutter test test/core/idempotency_key_test.dart test/core/api_client_players_test.dart`
Expected: FAIL — files/methods missing.

- [ ] **Step 3: Implement `idempotency_key.dart`**

```dart
// lib/core/utils/idempotency_key.dart
import 'dart:math';

final Random _secure = Random.secure();

/// A random (version 4) UUID. The API only requires a non-empty, unique-per-intent key.
String newIdempotencyKey([Random? random]) {
  final r = random ?? _secure;
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant 10xx
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}
```

- [ ] **Step 4: Implement the client methods**

In `api_client.dart` make **two small changes to existing code**: add `import 'players_models.dart';`, and let `_send` take optional per-request headers:

```dart
  Future<T> _send<T>(String method, String path, T Function(Object? data) parse,
      {Object? body, Map<String, String>? headers}) async {
    final Response<dynamic> res;
    try {
      res = await _dio.request<dynamic>(
        '$_base$path',
        data: body,
        options: Options(method: method, responseType: ResponseType.json, headers: headers),
      );
```
(If a parallel branch already added a `headers`/idempotency parameter to `_send`, keep theirs and drop this edit.) Then append to the class, after the last existing method:

```dart
  static String _enc(String username) => Uri.encodeComponent(username);

  Future<List<PlayerListItem>> searchPlayers({String q = ''}) => _send(
        'GET',
        _withQuery('/players', {'q': q.isEmpty ? null : q}),
        (d) => (d! as List<dynamic>).map((e) => PlayerListItem.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Future<PlayerProfile> getPlayerProfile(String username) =>
      _send('GET', '/players/${_enc(username)}', (d) => PlayerProfile.fromJson(d! as Map<String, dynamic>));

  Future<List<FollowEntry>> getPlayerFollowers(String username) => _send(
        'GET',
        '/players/${_enc(username)}/followers',
        (d) => (d! as List<dynamic>).map((e) => FollowEntry.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Future<List<FollowEntry>> getPlayerFollowing(String username) => _send(
        'GET',
        '/players/${_enc(username)}/following',
        (d) => (d! as List<dynamic>).map((e) => FollowEntry.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Future<FollowSets> getMyFollows() => _send('GET', '/me/follows', (d) => FollowSets.fromJson(d! as Map<String, dynamic>));

  Future<FollowOutcome> followPlayer(String username, {required String idempotencyKey}) => _send(
        'PUT',
        '/players/${_enc(username)}/follow',
        (d) => FollowOutcome.fromJson(d! as Map<String, dynamic>),
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<FollowOutcome> unfollowPlayer(String username) =>
      _send('DELETE', '/players/${_enc(username)}/follow', (d) => FollowOutcome.fromJson(d! as Map<String, dynamic>));

  Future<MyProgress> getMyProgress() => _send('GET', '/me/progress', (d) => MyProgress.fromJson(d! as Map<String, dynamic>));

  Future<HistoryPage<XpEvent>> getMyXpEvents({String? cursor}) => _send(
        'GET',
        _withQuery('/me/xp-events', {'cursor': cursor}),
        (d) => HistoryPage.parse(d! as Map<String, dynamic>, XpEvent.fromJson),
      );

  Future<HistoryPage<SxScoreEvent>> getMySxScoreEvents({String? cursor}) => _send(
        'GET',
        _withQuery('/me/sx-score-events', {'cursor': cursor}),
        (d) => HistoryPage.parse(d! as Map<String, dynamic>, SxScoreEvent.fromJson),
      );

  Future<HistoryPage<CoinTransaction>> getMyCoinTransactions({String? cursor}) => _send(
        'GET',
        _withQuery('/me/coin-transactions', {'cursor': cursor}),
        (d) => HistoryPage.parse(d! as Map<String, dynamic>, CoinTransaction.fromJson),
      );
```
Append to `usedOperations`, after the last entry:

```dart
    'searchPlayers': 'get /api/mobile/v1/players',
    'getPlayerProfile': 'get /api/mobile/v1/players/{username}',
    'getPlayerFollowers': 'get /api/mobile/v1/players/{username}/followers',
    'getPlayerFollowing': 'get /api/mobile/v1/players/{username}/following',
    'getMyFollows': 'get /api/mobile/v1/me/follows',
    'followPlayer': 'put /api/mobile/v1/players/{username}/follow',
    'unfollowPlayer': 'delete /api/mobile/v1/players/{username}/follow',
    'getMyProgress': 'get /api/mobile/v1/me/progress',
    'getMyXpEvents': 'get /api/mobile/v1/me/xp-events',
    'getMySxScoreEvents': 'get /api/mobile/v1/me/sx-score-events',
    'getMyCoinTransactions': 'get /api/mobile/v1/me/coin-transactions',
```

- [ ] **Step 5: Run to green**

Run: `flutter test test/core` (includes `api_contract_test.dart`, which proves the copied `openapi.json` holds all eleven operations under these exact method/path strings).
Expected: PASS.

- [ ] **Step 6: Analyze and commit**

```bash
flutter analyze
git add lib/core/utils/idempotency_key.dart lib/core/api/api_client.dart test/core/idempotency_key_test.dart test/core/api_client_players_test.dart
git commit -m "feat(api): player, follow, progress and history client methods

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Copy keys and code→label maps

**Files:**
- Modify: `lib/core/l10n/app_en.arb` (+ regenerate `lib/core/l10n/gen/*`)
- Create: `lib/features/progress/history_labels.dart`, `test/features/history_labels_test.dart`

**Interfaces:**
- Consumes: `AppLocalizations` (generated).
- Produces:

```dart
String humanizeCode(String code);                                  // 'brand_new_thing' -> 'Brand new thing'; '' -> '—'
String xpSourceLabel(AppLocalizations l10n, String code);
String scoreEventLabel(AppLocalizations l10n, String code);
String coinSourceLabel(AppLocalizations l10n, String code);
String tierLabel(AppLocalizations l10n, String code);              // recruit/guardian/elite/sentinel/legend, else humanized
```
Every ARB key below is consumed by Tasks 4–9.

**ARB keys (English only).** Placeholder keys need the `@key` metadata block exactly like `updateRequiredBody`:

```json
  "profileFollowersCount": "{n} followers",
  "@profileFollowersCount": { "placeholders": { "n": { "type": "int" } } },
```

| Key | English |
|---|---|
| `commonLoadError` | `Couldn't load. Tap to retry.` |
| `playersTitle` | `Players` |
| `playersSearchHint` | `Search players` |
| `playersEmpty` | `No players found.` |
| `playersNotFound` | `Player not found.` |
| `profileFollow` | `Follow` |
| `profileFollowing` | `Following` |
| `profileFollowsYou` | `Follows you` |
| `profileFollowersCount` (`n:int`) | `{n} followers` |
| `profileFollowingCount` (`n:int`) | `{n} following` |
| `profileStatMatches` | `Matches` |
| `profileStatWins` | `Wins` |
| `profileStatLosses` | `Losses` |
| `profileStatGoalsFor` | `Goals for` |
| `profileStatGoalsAgainst` | `Goals against` |
| `profileStatTitles` | `Titles` |
| `profileStatTournaments` | `Tournaments` |
| `profileStatStreak` | `Win streak` |
| `profileStatRank` | `Global rank` |
| `profileRankOf` (`rank:int`, `total:int`) | `#{rank} of {total}` |
| `profileRankUnranked` | `Unranked` |
| `profileSxScore` (`n:int`) | `SX Score {n}` |
| `profileCategoryStats` | `Goals by category` |
| `profileTitlesHeading` | `Titles` |
| `profileNoTitles` | `No titles yet.` |
| `profileRecentMatches` | `Recent matches` |
| `profileNoMatches` | `No matches yet.` |
| `profileOutcomeWin` | `Win` |
| `profileOutcomeLoss` | `Loss` |
| `profileOutcomeDraw` | `Draw` |
| `profileAchievements` | `Achievements` |
| `profileAchievementsProgress` (`unlocked:int`, `total:int`) | `{unlocked}/{total} unlocked` |
| `profileAchievementLocked` | `Locked` |
| `profilePosts` | `Recent posts` |
| `profileGallery` | `Gallery` |
| `followErrorSelf` | `You can't follow yourself.` |
| `followErrorBlocked` | `You can't follow this player.` |
| `followErrorNotFound` | `This player no longer exists.` |
| `followErrorGeneric` | `Couldn't update. Please try again.` |
| `followersTitle` | `Followers` |
| `followingTitle` | `Following` |
| `followersEmpty` | `No followers yet.` |
| `followingEmpty` | `Not following anyone yet.` |
| `accountMyProgress` | `My progress` |
| `progressTitle` | `My progress` |
| `progressSignIn` | `Log in to see your progress.` |
| `progressXpHeading` | `XP` |
| `progressXpToNext` (`into:int`, `needed:int`, `tier:String`) | `{into} / {needed} XP to {tier}` |
| `progressMaxTier` | `Max tier reached` |
| `progressSxScore` | `SX Score` |
| `progressCoins` | `Coins` |
| `progressSeasonHeading` | `Season standing` |
| `progressSeasonRank` (`rank:int`) | `Rank #{rank}` |
| `progressSeasonUnranked` | `Unranked` |
| `progressSeasonMonthly` | `This month` |
| `progressSeasonNone` | `No active season.` |
| `progressToRankSixteen` (`n:int`) | `Rank 16 has {n} pts` |
| `progressHistoryXp` | `XP history` |
| `progressHistoryScore` | `SX Score history` |
| `progressHistoryCoins` | `Coin history` |
| `historyEmpty` | `No activity yet.` |
| `historyLoadMoreError` | `Couldn't load more. Tap to retry.` |
| `historyBalanceAfter` (`n:int`) | `Balance {n}` |
| `tierRecruit` / `tierGuardian` / `tierElite` / `tierSentinel` / `tierLegend` | `Recruit` / `Guardian` / `Elite` / `Sentinel` / `Legend` |

XP sources (`xpSource…`): `MatchPlayed` "Match played", `MatchWon` "Match won", `TournamentEntered` "Tournament entered", `TournamentCompleted` "Tournament completed", `TournamentPlacement` "Tournament placement", `AchievementUnlocked` "Achievement unlocked", `DailyLogin` "Daily login", `LoginStreak` "Login streak", `CommunityActivity` "Community activity", `AdminGrant` "Admin grant".

SX events (`scoreEvent…`): `MatchCompleted` "Match completed", `NoShow` "No-show", `RageQuit` "Left a match early", `DisputeLost` "Dispute lost", `RatingReceived` "Rating received", `AdminFlagConduct` "Conduct flag", `AdminFlagCheat` "Cheat flag".

Coin sources (`coinSource…`): `MatchPlayed` "Match played", `MatchWon` "Match won", `TournamentPlacement` "Tournament placement", `DailyLogin` "Daily login", `LoginStreak` "Login streak", `AchievementUnlocked` "Achievement unlocked", `StorePurchase` "Store purchase", `CommunityActivity` "Community activity", `AdminGrant` "Admin grant", `AdminDeduct` "Admin deduction", `WeeklyChallenge` "Weekly challenge", `BestPlayWinner` "Best Play winner", `BestPlayRunnerUp` "Best Play runner-up", `EntryDiscount` "Entry discount", `EntryDiscountRefund` "Entry discount refund", `WagerStake` "Wager stake", `WagerWon` "Wager won", `WagerRefund` "Wager refund", `PostBoost` "Post boost", `ReferralReward` "Referral reward", `ReferralMilestone` "Referral milestone", `FriendlyStake` "Friendly stake", `FriendlyStakePayout` "Friendly payout".

(`scoreEventRageQuit` intentionally reads "Left a match early" — the raw code is jargon.)

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/history_labels_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/progress/history_labels.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async => l10n = await AppLocalizations.delegate.load(const Locale('en')));

  test('humanizeCode turns snake_case into a sentence and survives odd input', () {
    expect(humanizeCode('brand_new_thing'), 'Brand new thing');
    expect(humanizeCode('single'), 'Single');
    expect(humanizeCode('__double__underscore_'), 'Double underscore');
    expect(humanizeCode(''), '—');
    expect(humanizeCode('___'), '—');
  });

  test('known codes map to their localized labels', () {
    expect(xpSourceLabel(l10n, 'match_won'), 'Match won');
    expect(scoreEventLabel(l10n, 'no_show'), 'No-show');
    expect(coinSourceLabel(l10n, 'friendly_stake_payout'), 'Friendly payout');
    expect(tierLabel(l10n, 'guardian'), 'Guardian');
  });

  test('unknown codes fall back to a humanized label — never blank, never a crash', () {
    expect(xpSourceLabel(l10n, 'referral_bonus_v2'), 'Referral bonus v2');
    expect(scoreEventLabel(l10n, 'something_new'), 'Something new');
    expect(coinSourceLabel(l10n, 'brand_new_source'), 'Brand new source');
    expect(tierLabel(l10n, 'mythic'), 'Mythic');
  });

  test('codes whose dedicated label differs from the naive humanization are actually mapped (guards a dropped switch arm)', () {
    // Only codes where the English label != humanizeCode(code); the others (e.g. match_won -> "Match won") are
    // indistinguishable from the fallback and are covered by the known-code test above.
    expect(scoreEventLabel(l10n, 'no_show'), isNot(humanizeCode('no_show')));
    expect(scoreEventLabel(l10n, 'rage_quit'), 'Left a match early');
    expect(scoreEventLabel(l10n, 'admin_flag_conduct'), 'Conduct flag');
    expect(scoreEventLabel(l10n, 'admin_flag_cheat'), 'Cheat flag');
    expect(coinSourceLabel(l10n, 'admin_deduct'), 'Admin deduction');
    expect(coinSourceLabel(l10n, 'best_play_runner_up'), 'Best Play runner-up');
    expect(coinSourceLabel(l10n, 'friendly_stake_payout'), 'Friendly payout');
  });
}
```

- [ ] **Step 2: Run to fail** — `flutter test test/features/history_labels_test.dart` → FAIL.

- [ ] **Step 3: Add the ARB keys, then implement**

Add every key above to `lib/core/l10n/app_en.arb` (with `@key` placeholder metadata where a parameter is listed) **and, with French text, to `lib/core/l10n/app_fr.arb`** (no `@key` blocks needed there), run `flutter gen-l10n`. Then:

```dart
// lib/features/progress/history_labels.dart
import '../../core/l10n/gen/app_localizations.dart';

/// Fallback for a code the app does not know yet: a new DB value must never blank or break a row.
String humanizeCode(String code) {
  final words = code.split('_').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '—';
  final s = words.join(' ');
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

String xpSourceLabel(AppLocalizations l, String code) => switch (code) {
      'match_played' => l.xpSourceMatchPlayed,
      'match_won' => l.xpSourceMatchWon,
      'tournament_entered' => l.xpSourceTournamentEntered,
      'tournament_completed' => l.xpSourceTournamentCompleted,
      'tournament_placement' => l.xpSourceTournamentPlacement,
      'achievement_unlocked' => l.xpSourceAchievementUnlocked,
      'daily_login' => l.xpSourceDailyLogin,
      'login_streak' => l.xpSourceLoginStreak,
      'community_activity' => l.xpSourceCommunityActivity,
      'admin_grant' => l.xpSourceAdminGrant,
      _ => humanizeCode(code),
    };

String scoreEventLabel(AppLocalizations l, String code) => switch (code) {
      'match_completed' => l.scoreEventMatchCompleted,
      'no_show' => l.scoreEventNoShow,
      'rage_quit' => l.scoreEventRageQuit,
      'dispute_lost' => l.scoreEventDisputeLost,
      'rating_received' => l.scoreEventRatingReceived,
      'admin_flag_conduct' => l.scoreEventAdminFlagConduct,
      'admin_flag_cheat' => l.scoreEventAdminFlagCheat,
      _ => humanizeCode(code),
    };

String coinSourceLabel(AppLocalizations l, String code) => switch (code) {
      'match_played' => l.coinSourceMatchPlayed,
      'match_won' => l.coinSourceMatchWon,
      'tournament_placement' => l.coinSourceTournamentPlacement,
      'daily_login' => l.coinSourceDailyLogin,
      'login_streak' => l.coinSourceLoginStreak,
      'achievement_unlocked' => l.coinSourceAchievementUnlocked,
      'store_purchase' => l.coinSourceStorePurchase,
      'community_activity' => l.coinSourceCommunityActivity,
      'admin_grant' => l.coinSourceAdminGrant,
      'admin_deduct' => l.coinSourceAdminDeduct,
      'weekly_challenge' => l.coinSourceWeeklyChallenge,
      'best_play_winner' => l.coinSourceBestPlayWinner,
      'best_play_runner_up' => l.coinSourceBestPlayRunnerUp,
      'entry_discount' => l.coinSourceEntryDiscount,
      'entry_discount_refund' => l.coinSourceEntryDiscountRefund,
      'wager_stake' => l.coinSourceWagerStake,
      'wager_won' => l.coinSourceWagerWon,
      'wager_refund' => l.coinSourceWagerRefund,
      'post_boost' => l.coinSourcePostBoost,
      'referral_reward' => l.coinSourceReferralReward,
      'referral_milestone' => l.coinSourceReferralMilestone,
      'friendly_stake' => l.coinSourceFriendlyStake,
      'friendly_stake_payout' => l.coinSourceFriendlyStakePayout,
      _ => humanizeCode(code),
    };

String tierLabel(AppLocalizations l, String code) => switch (code) {
      'recruit' => l.tierRecruit,
      'guardian' => l.tierGuardian,
      'elite' => l.tierElite,
      'sentinel' => l.tierSentinel,
      'legend' => l.tierLegend,
      _ => humanizeCode(code),
    };
```
If Task 0 Step 5 found live codes missing from these switches, add them (ARB key + switch arm + a line in the test).

- [ ] **Step 4:** `flutter test test/features/history_labels_test.dart test/core/l10n_test.dart` → PASS; `flutter analyze` clean.
- [ ] **Step 5:** Commit `feat(l10n): profile/progress copy and history code labels` (include regenerated `lib/core/l10n/gen/*`, trailer as above).

---

### Task 4: Players repository, providers, directory screen

**Files:**
- Create: `lib/features/players/players_repository.dart`, `lib/features/players/players_providers.dart` (search + profile + follow-list parts only in this task), `lib/features/players/players_directory_screen.dart`
- Create: `test/support/fake_players_repository.dart`
- Test: `test/features/players_directory_screen_test.dart`

**Interfaces:**
- Consumes: `apiClientProvider`, `meProvider`, `PlayerAvatar`/`resolveAsset` (3a), ARB keys.
- Produces:

```dart
abstract class PlayersRepository {
  Future<List<PlayerListItem>> search(String q);
  Future<PlayerProfile> profile(String username);
  Future<List<FollowEntry>> followers(String username);
  Future<List<FollowEntry>> following(String username);
  Future<FollowSets> myFollows();
  Future<FollowOutcome> follow(String username, String idempotencyKey);
  Future<FollowOutcome> unfollow(String username);
}
final playersRepositoryProvider = Provider<PlayersRepository>(...);
final playerSearchQueryProvider = NotifierProvider.autoDispose<PlayerSearchQueryNotifier, String>(PlayerSearchQueryNotifier.new); // .set(String)
final playerSearchProvider = FutureProvider.autoDispose<List<PlayerListItem>>(...);   // own username filtered out
final playerProfileProvider = FutureProvider.autoDispose.family<PlayerProfile, String>(...);
enum FollowListKind { followers, following }
final followListProvider = FutureProvider.autoDispose.family<List<FollowEntry>, (String, FollowListKind)>(...);
class PlayersDirectoryScreen extends ConsumerStatefulWidget { const PlayersDirectoryScreen({super.key, required this.onPlayerTap, this.debounce = const Duration(milliseconds: 300)}); final void Function(String username) onPlayerTap; final Duration debounce; }
```

- [ ] **Step 1: Fake repository (shared by Tasks 4–6)**

```dart
// test/support/fake_players_repository.dart
import 'dart:async';

import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/features/players/players_repository.dart';

import 'players_fixtures.dart';

class FakePlayersRepository implements PlayersRepository {
  Map<String, dynamic> profileData = profileJson();
  Object? profileError;
  List<PlayerListItem> searchResults = const [];
  List<FollowEntry> followerList = const [];
  List<FollowEntry> followingList = const [];
  FollowSets sets = const FollowSets(followingIds: {}, followerIds: {});
  Object? myFollowsError;

  /// One entry is consumed (thrown) per follow() call before a call is allowed to succeed.
  final List<Object> followErrors = [];
  Object? unfollowError;
  FollowOutcome followResult = const FollowOutcome(following: true, created: true);
  Completer<void>? followGate; // set to hold follow() open (double-tap tests)

  final searches = <String>[];
  final profileRequests = <String>[];
  var myFollowsCalls = 0;
  final followCalls = <({String username, String key})>[];
  final unfollowCalls = <String>[];

  @override
  Future<List<PlayerListItem>> search(String q) async {
    searches.add(q);
    return searchResults;
  }

  @override
  Future<PlayerProfile> profile(String username) async {
    profileRequests.add(username);
    if (profileError != null) throw profileError!;
    return PlayerProfile.fromJson(profileData);
  }

  @override
  Future<List<FollowEntry>> followers(String username) async => followerList;

  @override
  Future<List<FollowEntry>> following(String username) async => followingList;

  @override
  Future<FollowSets> myFollows() async {
    myFollowsCalls++;
    if (myFollowsError != null) throw myFollowsError!;
    return sets;
  }

  @override
  Future<FollowOutcome> follow(String username, String idempotencyKey) async {
    followCalls.add((username: username, key: idempotencyKey));
    if (followGate != null) await followGate!.future;
    if (followErrors.isNotEmpty) throw followErrors.removeAt(0);
    return followResult;
  }

  @override
  Future<FollowOutcome> unfollow(String username) async {
    unfollowCalls.add(username);
    if (unfollowError != null) throw unfollowError!;
    return const FollowOutcome(following: false, created: false);
  }
}

ApiException apiError(int status, String code) => ApiException(status: status, code: code, message: code);
```

- [ ] **Step 2: Failing directory tests**

```dart
// test/features/players_directory_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/players/players_directory_screen.dart';
import 'package:sentinelx_mobile/features/players/players_providers.dart';

import '../support/fake_players_repository.dart';

PlayerListItem _p(String u, {String? name}) => PlayerListItem(
    username: u, displayName: name, avatarUrl: null, sxScore: 900, sentinelTier: null, membershipTier: 'recruit', equippedAvatarBorder: null);

MeResponse _me(String username) => MeResponse(
      id: 'me1', email: null, roles: const [], isStaff: false, isAdmin: false,
      profile: MeProfile(username: username, displayName: null, avatarUrl: null, whatsappNumber: null, country: null, locale: 'en', membershipTier: null, kycVerified: false, deletionRequestedAt: null),
    );

Widget _app(FakePlayersRepository repo, {MeResponse? me, void Function(String)? onTap}) => ProviderScope(
      retry: (_, _) => null,
      overrides: [
        playersRepositoryProvider.overrideWithValue(repo),
        meProvider.overrideWith((ref) async => me),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlayersDirectoryScreen(onPlayerTap: onTap ?? (_) {}),
      ),
    );

void main() {
  testWidgets('lists players and reports a tap with the username', (tester) async {
    final repo = FakePlayersRepository()..searchResults = [_p('ada', name: 'Ada'), _p('bola')];
    String? tapped;
    await tester.pumpWidget(_app(repo, onTap: (u) => tapped = u));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('bola'), findsOneWidget);
    await tester.tap(find.byKey(const Key('player-row-ada')));
    expect(tapped, 'ada');
  });

  testWidgets('typing is debounced: three quick edits produce one search with the final text', (tester) async {
    final repo = FakePlayersRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    repo.searches.clear();
    final field = find.byKey(const Key('players-search'));
    await tester.enterText(field, 'a');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'ad');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'ada');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repo.searches, ['ada']);
  });

  testWidgets('the signed-in viewer is filtered out of the results (the API cannot exclude them)', (tester) async {
    final repo = FakePlayersRepository()..searchResults = [_p('me_user', name: 'Me'), _p('ada')];
    await tester.pumpWidget(_app(repo, me: _me('me_user')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('player-row-me_user')), findsNothing);
    expect(find.byKey(const Key('player-row-ada')), findsOneWidget);
  });

  testWidgets('empty result shows the empty state', (tester) async {
    await tester.pumpWidget(_app(FakePlayersRepository()));
    await tester.pumpAndSettle();
    expect(find.text('No players found.'), findsOneWidget);
  });

  testWidgets('a failed search shows a tappable retry, not a stack trace', (tester) async {
    final repo = _ThrowingRepo();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load. Tap to retry."), findsOneWidget);
  });
}

class _ThrowingRepo extends FakePlayersRepository {
  @override
  Future<List<PlayerListItem>> search(String q) => throw apiError(500, 'internal');
}
```

- [ ] **Step 3: Run to fail** — `flutter test test/features/players_directory_screen_test.dart` → FAIL (files missing).

- [ ] **Step 4: Implement repository + providers**

```dart
// lib/features/players/players_repository.dart
import '../../core/api/api_client.dart';
import '../../core/api/players_models.dart';

abstract class PlayersRepository {
  Future<List<PlayerListItem>> search(String q);
  Future<PlayerProfile> profile(String username);
  Future<List<FollowEntry>> followers(String username);
  Future<List<FollowEntry>> following(String username);
  Future<FollowSets> myFollows();
  Future<FollowOutcome> follow(String username, String idempotencyKey);
  Future<FollowOutcome> unfollow(String username);
}

class ApiPlayersRepository implements PlayersRepository {
  ApiPlayersRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<PlayerListItem>> search(String q) => _api.searchPlayers(q: q);
  @override
  Future<PlayerProfile> profile(String username) => _api.getPlayerProfile(username);
  @override
  Future<List<FollowEntry>> followers(String username) => _api.getPlayerFollowers(username);
  @override
  Future<List<FollowEntry>> following(String username) => _api.getPlayerFollowing(username);
  @override
  Future<FollowSets> myFollows() => _api.getMyFollows();
  @override
  Future<FollowOutcome> follow(String username, String idempotencyKey) =>
      _api.followPlayer(username, idempotencyKey: idempotencyKey);
  @override
  Future<FollowOutcome> unfollow(String username) => _api.unfollowPlayer(username);
}
```

```dart
// lib/features/players/players_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/players_models.dart';
import '../../core/providers.dart';
import 'players_repository.dart';

final playersRepositoryProvider = Provider<PlayersRepository>((ref) => ApiPlayersRepository(ref.watch(apiClientProvider)));

class PlayerSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String q) => state = q.trim();
}

final playerSearchQueryProvider =
    NotifierProvider.autoDispose<PlayerSearchQueryNotifier, String>(PlayerSearchQueryNotifier.new);

/// `GET /players` cannot exclude the caller (public, byte-identical for everyone), so the app drops its own row.
final playerSearchProvider = FutureProvider.autoDispose<List<PlayerListItem>>((ref) async {
  final q = ref.watch(playerSearchQueryProvider);
  final results = await ref.watch(playersRepositoryProvider).search(q);
  final myUsername = ref.watch(meProvider).asData?.value?.profile?.username;
  return myUsername == null ? results : results.where((p) => p.username != myUsername).toList();
});

final playerProfileProvider = FutureProvider.autoDispose.family<PlayerProfile, String>(
  (ref, username) => ref.watch(playersRepositoryProvider).profile(username),
);

enum FollowListKind { followers, following }

final followListProvider = FutureProvider.autoDispose.family<List<FollowEntry>, (String, FollowListKind)>((ref, args) {
  final repo = ref.watch(playersRepositoryProvider);
  return args.$2 == FollowListKind.followers ? repo.followers(args.$1) : repo.following(args.$1);
});
```
(Task 5 appends `myFollowsProvider`, the follower-delta provider and the follow controller to this same file.)

- [ ] **Step 5: Implement the screen**

`PlayersDirectoryScreen` (`ConsumerStatefulWidget`): `Scaffold` + `AppBar(title: l10n.playersTitle)`; body = `Column` of a `TextField` (`Key('players-search')`, hint `l10n.playersSearchHint`, `onChanged` restarts a `Timer(widget.debounce, () => ref.read(playerSearchQueryProvider.notifier).set(text))`; cancel the timer in `dispose`), and an `Expanded` result area from `ref.watch(playerSearchProvider)`:
- loading → centered `CircularProgressIndicator`; error → tappable `l10n.commonLoadError` that `ref.invalidate(playerSearchProvider)`; empty → `l10n.playersEmpty`.
- rows: `ListTile(key: Key('player-row-${p.username}'))` with `PlayerAvatar(avatarUrl: p.avatarUrl, frameUrl: null, size: 40)` (**no frame** — the directory only has a slug), title `p.label` (`overflow: TextOverflow.ellipsis`), subtitle `'@${p.username} · ${l10n.profileSxScore(p.sxScore)}'`, trailing `tierLabel(l10n, p.membershipTier)`; `onTap: () => widget.onPlayerTap(p.username)`.
- `RefreshIndicator` invalidating `playerSearchProvider`.

- [ ] **Step 6:** `flutter test test/features/players_directory_screen_test.dart` → PASS; `flutter analyze`.
- [ ] **Step 7:** Commit `feat(players): repository, providers and directory screen`.

---

### Task 5: My follows + optimistic follow controller

**Files:**
- Modify: `lib/features/players/players_providers.dart` (append)
- Test: `test/features/follow_controller_test.dart`

**Interfaces:**
- Consumes: `PlayersRepository`, `newIdempotencyKey`, `meProvider`, `ApiException`.
- Produces (appended to `players_providers.dart`):

```dart
enum FollowFailure { self, blocked, notFound, unauthorized, generic }

/// null when signed out — and then NO request is made.
final myFollowsProvider = AsyncNotifierProvider.autoDispose<MyFollowsNotifier, FollowSets?>(MyFollowsNotifier.new);

class MyFollowsNotifier extends AsyncNotifier<FollowSets?> {
  Future<FollowSets?> build();
  /// Optimistic. Returns null on success or the failure kind after restoring the exact previous state.
  /// Ignored (returns null, no request) while a request for [targetId] is in flight or when signed out.
  Future<FollowFailure?> follow({required String targetId, required String username});
  Future<FollowFailure?> unfollow({required String targetId, required String username});
}

/// Session-local correction to the (60 s cached) public follower count, keyed by target player id.
final followerDeltaProvider = NotifierProvider.autoDispose<FollowerDeltaNotifier, Map<String, int>>(FollowerDeltaNotifier.new);
class FollowerDeltaNotifier extends Notifier<Map<String, int>> { Map<String, int> build() => const {}; void add(String id, int by); }

/// Delay before the single same-key retry of a follow (network failure or 409 idempotency_in_progress). Tests override to zero.
final followRetryDelayProvider = Provider<Duration>((ref) => const Duration(milliseconds: 400));
```

Rules (spec §7): state comes from `GET /me/follows`; PUT sends a **fresh key per tap, reused on the retry of the same tap**; rollback on failure; signed-out → no request; one request per target at a time.

- [ ] **Step 1: Failing tests**

```dart
// test/features/follow_controller_test.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/players/players_providers.dart';

import '../support/fake_players_repository.dart';

MeResponse _me() => const MeResponse(id: 'me1', email: null, roles: [], isStaff: false, isAdmin: false, profile: null);

ProviderContainer _container(FakePlayersRepository repo, {bool signedIn = true}) {
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      playersRepositoryProvider.overrideWithValue(repo),
      meProvider.overrideWith((ref) async => signedIn ? _me() : null),
      followRetryDelayProvider.overrideWithValue(Duration.zero),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<MyFollowsNotifier> _ready(ProviderContainer c) async {
  await c.read(myFollowsProvider.future);
  return c.read(myFollowsProvider.notifier);
}

void main() {
  test('signed out: state is null and /me/follows is never requested', () async {
    final repo = FakePlayersRepository();
    final c = _container(repo, signedIn: false);
    expect(await c.read(myFollowsProvider.future), isNull);
    expect(repo.myFollowsCalls, 0);
    final n = c.read(myFollowsProvider.notifier);
    expect(await n.follow(targetId: 'p1', username: 'ada'), isNull);
    expect(repo.followCalls, isEmpty); // signed out: no write either
  });

  test('follow flips optimistically, sends one PUT with a key, and bumps the follower delta on a created follow', () async {
    final repo = FakePlayersRepository();
    final c = _container(repo);
    final n = await _ready(c);
    final pending = n.follow(targetId: 'p1', username: 'ada');
    expect(c.read(myFollowsProvider).value!.followingIds, {'p1'}); // flipped before the request resolves
    expect(await pending, isNull);
    expect(repo.followCalls.single.username, 'ada');
    expect(repo.followCalls.single.key, isNotEmpty);
    expect(c.read(followerDeltaProvider)['p1'], 1);
  });

  test('a duplicate follow (created:false) does not bump the delta', () async {
    final repo = FakePlayersRepository()..followResult = const FollowOutcome(following: true, created: false);
    final c = _container(repo);
    final n = await _ready(c);
    await n.follow(targetId: 'p1', username: 'ada');
    expect(c.read(followerDeltaProvider)['p1'] ?? 0, 0);
  });

  test('failures roll back to the exact previous state and map to a distinct failure', () async {
    final cases = <(Object, FollowFailure)>[
      (apiError(403, 'follow_blocked'), FollowFailure.blocked),
      (apiError(400, 'cannot_follow_self'), FollowFailure.self),
      (apiError(404, 'not_found'), FollowFailure.notFound),
      (apiError(401, 'unauthorized'), FollowFailure.unauthorized),
      (apiError(500, 'follow_failed'), FollowFailure.generic),
    ];
    for (final (error, expected) in cases) {
      final repo = FakePlayersRepository()
        ..sets = const FollowSets(followingIds: {'x'}, followerIds: {'y'})
        ..followErrors.add(error);
      final c = _container(repo);
      final n = await _ready(c);
      expect(await n.follow(targetId: 'p1', username: 'ada'), expected, reason: '$error');
      final s = c.read(myFollowsProvider).value!;
      expect(s.followingIds, {'x'}, reason: 'rolled back for $error');
      expect(s.followerIds, {'y'});
      expect(c.read(followerDeltaProvider)['p1'] ?? 0, 0);
      expect(repo.followCalls, hasLength(1), reason: 'non-retryable errors are not retried');
    }
  });

  test('a network failure retries once with the SAME Idempotency-Key and then succeeds', () async {
    final repo = FakePlayersRepository()..followErrors.add(apiError(0, 'network'));
    final c = _container(repo);
    final n = await _ready(c);
    expect(await n.follow(targetId: 'p1', username: 'ada'), isNull);
    expect(repo.followCalls, hasLength(2));
    expect(repo.followCalls[0].key, repo.followCalls[1].key);
    expect(c.read(myFollowsProvider).value!.followingIds, {'p1'});
  });

  test('409 idempotency_in_progress is retried once with the same key', () async {
    final repo = FakePlayersRepository()..followErrors.add(apiError(409, 'idempotency_in_progress'));
    final c = _container(repo);
    final n = await _ready(c);
    expect(await n.follow(targetId: 'p1', username: 'ada'), isNull);
    expect(repo.followCalls[0].key, repo.followCalls[1].key);
  });

  test('two network failures in a row roll back (retry is bounded to one)', () async {
    final repo = FakePlayersRepository()..followErrors.addAll([apiError(0, 'network'), apiError(0, 'network')]);
    final c = _container(repo);
    final n = await _ready(c);
    expect(await n.follow(targetId: 'p1', username: 'ada'), FollowFailure.generic);
    expect(repo.followCalls, hasLength(2));
    expect(c.read(myFollowsProvider).value!.followingIds, isEmpty);
  });

  test('a fresh tap after a completed one uses a NEW key', () async {
    final repo = FakePlayersRepository();
    final c = _container(repo);
    final n = await _ready(c);
    await n.follow(targetId: 'p1', username: 'ada');
    await n.unfollow(targetId: 'p1', username: 'ada');
    await n.follow(targetId: 'p1', username: 'ada');
    expect(repo.followCalls[0].key, isNot(repo.followCalls[1].key));
  });

  test('a second tap while the first is in flight is ignored', () async {
    final gate = Completer<void>();
    final repo = FakePlayersRepository()..followGate = gate;
    final c = _container(repo);
    final n = await _ready(c);
    final first = n.follow(targetId: 'p1', username: 'ada');
    await Future<void>.delayed(Duration.zero);
    expect(await n.unfollow(targetId: 'p1', username: 'ada'), isNull); // ignored
    expect(await n.follow(targetId: 'p1', username: 'ada'), isNull); // ignored
    gate.complete();
    await first;
    expect(repo.followCalls, hasLength(1));
    expect(repo.unfollowCalls, isEmpty);
    expect(c.read(myFollowsProvider).value!.followingIds, {'p1'});
  });

  test('unfollow of a followed player removes them and decrements the delta; failure rolls back', () async {
    final repo = FakePlayersRepository()..sets = const FollowSets(followingIds: {'p1'}, followerIds: {});
    final c = _container(repo);
    final n = await _ready(c);
    expect(await n.unfollow(targetId: 'p1', username: 'ada'), isNull);
    expect(c.read(myFollowsProvider).value!.followingIds, isEmpty);
    expect(c.read(followerDeltaProvider)['p1'], -1);

    final repo2 = FakePlayersRepository()
      ..sets = const FollowSets(followingIds: {'p1'}, followerIds: {})
      ..unfollowError = apiError(500, 'unfollow_failed');
    final c2 = _container(repo2);
    final n2 = await _ready(c2);
    expect(await n2.unfollow(targetId: 'p1', username: 'ada'), FollowFailure.generic);
    expect(c2.read(myFollowsProvider).value!.followingIds, {'p1'});
    expect(c2.read(followerDeltaProvider)['p1'] ?? 0, 0);
  });
}
```

- [ ] **Step 2: Run to fail** — FAIL (symbols missing).

- [ ] **Step 3: Implement (append to `players_providers.dart`; add imports for `api_client.dart` and `../../core/utils/idempotency_key.dart`)**

```dart
enum FollowFailure { self, blocked, notFound, unauthorized, generic }

FollowFailure _failureOf(Object e) {
  if (e is ApiException) {
    if (e.code == 'cannot_follow_self') return FollowFailure.self;
    if (e.code == 'follow_blocked') return FollowFailure.blocked;
    if (e.status == 404) return FollowFailure.notFound;
    if (e.status == 401) return FollowFailure.unauthorized;
  }
  return FollowFailure.generic;
}

/// Worth exactly one retry with the SAME key: nothing reached the server, or the server is still finishing that key.
bool _retryable(Object e) => e is ApiException && (e.status == 0 || e.code == 'idempotency_in_progress');

class FollowerDeltaNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};
  void add(String id, int by) => state = {...state, id: (state[id] ?? 0) + by};
}

final followerDeltaProvider =
    NotifierProvider.autoDispose<FollowerDeltaNotifier, Map<String, int>>(FollowerDeltaNotifier.new);

final followRetryDelayProvider = Provider<Duration>((ref) => const Duration(milliseconds: 400));

class MyFollowsNotifier extends AsyncNotifier<FollowSets?> {
  final _inFlight = <String>{};

  @override
  Future<FollowSets?> build() async {
    final me = await ref.watch(meProvider.future);
    if (me == null) return null; // signed out: never touch /me/*
    return ref.watch(playersRepositoryProvider).myFollows();
  }

  Future<FollowFailure?> follow({required String targetId, required String username}) async {
    final before = state.value;
    if (before == null || _inFlight.contains(targetId)) return null;
    _inFlight.add(targetId);
    state = AsyncData(before.copyWith(followingIds: {...before.followingIds, targetId}));
    final key = newIdempotencyKey(); // one key per tap, reused on the retry below
    final repo = ref.read(playersRepositoryProvider);
    try {
      FollowOutcome outcome;
      try {
        outcome = await repo.follow(username, key);
      } catch (e) {
        if (!_retryable(e)) rethrow;
        await Future<void>.delayed(ref.read(followRetryDelayProvider));
        outcome = await repo.follow(username, key);
      }
      if (outcome.created) ref.read(followerDeltaProvider.notifier).add(targetId, 1);
      return null;
    } catch (e) {
      state = AsyncData(before);
      return e is ApiException && _retryable(e) ? FollowFailure.generic : _failureOf(e);
    } finally {
      _inFlight.remove(targetId);
    }
  }

  Future<FollowFailure?> unfollow({required String targetId, required String username}) async {
    final before = state.value;
    if (before == null || _inFlight.contains(targetId)) return null;
    _inFlight.add(targetId);
    final wasFollowing = before.followingIds.contains(targetId);
    state = AsyncData(before.copyWith(followingIds: {...before.followingIds}..remove(targetId)));
    try {
      await ref.read(playersRepositoryProvider).unfollow(username);
      if (wasFollowing) ref.read(followerDeltaProvider.notifier).add(targetId, -1);
      return null;
    } catch (e) {
      state = AsyncData(before);
      return _failureOf(e);
    } finally {
      _inFlight.remove(targetId);
    }
  }
}

/// null when signed out — and then NO request is made.
final myFollowsProvider = AsyncNotifierProvider.autoDispose<MyFollowsNotifier, FollowSets?>(MyFollowsNotifier.new);
```
Note the `catch` mapping: a non-`ApiException` (e.g. a `StateError`) is `generic`; a retryable error that failed twice is also `generic` (not `notFound`, etc.).

- [ ] **Step 4:** `flutter test test/features/follow_controller_test.dart` → PASS; `flutter analyze`.
- [ ] **Step 5:** Commit `feat(players): my-follows state and optimistic follow controller`.

---

### Task 6: Profile screen and followers/following screen

**Files:**
- Create: `lib/features/players/profile_sections.dart`, `lib/features/players/player_profile_screen.dart`, `lib/features/players/follow_list_screen.dart`
- Test: `test/features/player_profile_screen_test.dart`, `test/features/follow_list_screen_test.dart`

**Interfaces:**
- Consumes: `playerProfileProvider`, `myFollowsProvider`, `followerDeltaProvider`, `followListProvider`, `meProvider`, `PlayerAvatar`, `resolveAsset`, `appConfigProvider` (for the site URL — read how 3a's Rankings screen obtains it and do the same), `tierLabel`, ARB keys.
- Produces:

```dart
class PlayerProfileScreen extends ConsumerWidget {
  const PlayerProfileScreen({super.key, required this.username, required this.onLogIn, required this.onOpenFollowers, required this.onOpenFollowing});
  final String username;
  final VoidCallback onLogIn;
  final void Function(String username) onOpenFollowers;
  final void Function(String username) onOpenFollowing;
}
class FollowListScreen extends ConsumerWidget {
  const FollowListScreen({super.key, required this.username, required this.kind, required this.onPlayerTap});
  final String username;
  final FollowListKind kind;
  final void Function(String username) onPlayerTap;
}
```

**Profile behavior.** `ListView` (pull-to-refresh invalidates `playerProfileProvider(username)` and `myFollowsProvider`), in this order:
1. **Header:** `PlayerAvatar(size: 72, frameUrl: resolveAsset(p.frameUrl, siteUrl))`, `p.label` (ellipsis, max 2 lines), `@username`, chips for `tierLabel(membershipTier)` and (if non-null) the humanized `sentinelTier`, country, `l10n.profileSxScore`, bio (if non-null; `softWrap`, no max height issues). Follower/following counts as two tappable texts: `Key('profile-followers')` → `l10n.profileFollowersCount(stats.followerCount + delta)` → `onOpenFollowers(username)`; `Key('profile-following')` → `l10n.profileFollowingCount(stats.followingCount)` → `onOpenFollowing`.
2. **Follow button** (`Key('follow-button')`): hidden when `me?.id == p.id`. Signed out → shows "Follow" and `onPressed: onLogIn`. Signed in → `following = myFollows.value.followingIds.contains(p.id)`; label `l10n.profileFollowing` (filled/tonal) vs `l10n.profileFollow`; **disabled while `myFollowsProvider` is loading**; on press calls `follow`/`unfollow`, and on a non-null `FollowFailure` shows a `SnackBar` with the mapped copy (`self→followErrorSelf`, `blocked→followErrorBlocked`, `notFound→followErrorNotFound`, `unauthorized→ call onLogIn`, `generic→followErrorGeneric`). A `Key('follows-you-chip')` "Follows you" chip shows when `followerIds.contains(p.id)`. **No Friend/Message buttons.**
3. **Stats grid** (`Wrap`/`GridView` of tiles): matches, wins, losses, goals for/against, titles, tournaments, streak, and rank tile `stats.rank == null ? l10n.profileRankUnranked : l10n.profileRankOf(rank, totalRankedPlayers ?? rank)`.
4. **Category stats** (`profileCategoryStats`): one row per `categoryStats` (`category` humanized via `humanizeCode`, `scored / conceded`); omitted when empty.
5. **Titles** (`profileTitlesHeading`; empty → `profileNoTitles`): `tournamentTitle`, `gameName`, `date`.
6. **Recent matches** (`profileRecentMatches`; empty → `profileNoMatches`): per row `Key('match-row-${m.id}')`: outcome badge (`profileOutcomeWin/Loss/Draw`, by `outcome`; unknown → humanized), `vs ${m.opponentName}` (ellipsis), score `${playerScore}–${opponentScore}`, tournament title if any.
7. **Achievements** (`profileAchievements` + `l10n.profileAchievementsProgress(unlockedCount, total)`): a showcase strip of the unlocked entries whose `slug ∈ showcase` (in `showcase` order; missing slugs skipped), then the unlocked grid **in the given order** (`Key('achievement-${slug}')`, name + description), then `lockedCount` anonymous tiles `Key('locked-tile-$i')` each showing a lock icon and `l10n.profileAchievementLocked`. Section hidden when `total == 0`.
8. **Posts** (`profilePosts`; hidden when empty; read-only rows: content ellipsis 3 lines, no tap) and **Gallery** (`profileGallery`; hidden when empty; `GridView` of `Image.network(errorBuilder → grey box)`, 3 columns, non-scrolling).

Loading → centered spinner. Error: `ApiException` with `status == 404` → `Key('player-not-found')` showing `l10n.playersNotFound` (no retry; it will not appear); any other error → tappable `l10n.commonLoadError`. Keep the screen file to layout + wiring and put each numbered section in `profile_sections.dart` as a stateless widget taking plain model values.

**Follow-list behavior.** `AppBar(title: kind == followers ? l10n.followersTitle : l10n.followingTitle)`; rows from `followListProvider((username, kind))`. Row: `PlayerAvatar(avatarUrl, isDeleted: e.isDeleted)`, title `e.isDeleted ? l10n.commonDeletedPlayer : e.label`, subtitle `tierLabel(membershipTier)`, and — from `myFollowsProvider` (never an extra request; nothing when signed out or for the viewer's own row) — a `Key('chip-following-${e.id}')` "Following" chip if `followingIds.contains(e.id)` and a `Key('chip-follows-you-${e.id}')` "Follows you" chip if `followerIds.contains(e.id)`. `onTap` → `onPlayerTap(e.username!)` **only when `!e.isDeleted`** (a tombstone row has no `onTap`). Empty → `followersEmpty` / `followingEmpty`; 404 → `playersNotFound`; other error → retry.

- [ ] **Step 1: Failing profile tests**

```dart
// test/features/player_profile_screen_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/players/player_profile_screen.dart';
import 'package:sentinelx_mobile/features/players/players_providers.dart';

import '../support/fake_players_repository.dart';
import '../support/players_fixtures.dart';

MeResponse _me(String id) => MeResponse(id: id, email: null, roles: const [], isStaff: false, isAdmin: false, profile: null);

Widget _app(FakePlayersRepository repo, {String? meId, VoidCallback? onLogIn, String username = 'ada'}) => ProviderScope(
      retry: (_, _) => null,
      overrides: [
        playersRepositoryProvider.overrideWithValue(repo),
        meProvider.overrideWith((ref) async => meId == null ? null : _me(meId)),
        followRetryDelayProvider.overrideWithValue(Duration.zero),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlayerProfileScreen(
          username: username,
          onLogIn: onLogIn ?? () {},
          onOpenFollowers: (_) {},
          onOpenFollowing: (_) {},
        ),
      ),
    );

void main() {
  // 375 x 812 logical px, like the target devices, so the overflow assertions mean something.
  Future<void> phone(WidgetTester t) async {
    t.view.physicalSize = const Size(375, 812);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('renders header, stats, titles, matches, posts and shows the mixed achievements without overflow', (tester) async {
    await phone(tester);
    final repo = FakePlayersRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsWidgets);
    expect(find.text('Plays DLS.'), findsOneWidget);
    expect(find.text('Masters Sept'), findsWidgets);
    expect(find.byKey(const Key('match-row-m1')), findsOneWidget);
    expect(find.text('GG everyone'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked achievements are anonymous tiles: count only, no names', (tester) async {
    await phone(tester);
    final repo = FakePlayersRepository()..profileData = profileJson(totalAchievements: 5, unlockedAchievements: 2);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('locked-tile-0')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('locked-tile-0')), findsOneWidget);
    expect(find.byKey(const Key('locked-tile-2')), findsOneWidget);
    expect(find.byKey(const Key('locked-tile-3')), findsNothing); // 5 total - 2 unlocked = 3
    expect(find.text('2/5 unlocked'), findsOneWidget);
    expect(find.byKey(const Key('achievement-a0')), findsOneWidget);
  });

  testWidgets('a player with no achievements, no rank, no bio and no activity renders without a crash', (tester) async {
    await phone(tester);
    final repo = FakePlayersRepository()
      ..profileData = profileJson(totalAchievements: 0, unlockedAchievements: 0, rank: null, totalRanked: null, bio: null, withActivity: false);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Unranked'), findsOneWidget);
    expect(find.text('No titles yet.'), findsOneWidget);
    expect(find.text('No matches yet.'), findsOneWidget);
    expect(find.byKey(const Key('locked-tile-0')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a very long display name and bio do not overflow at 375px', (tester) async {
    await phone(tester);
    final data = profileJson(bio: List.filled(300, 'word').join(' '));
    (data['player'] as Map<String, dynamic>)['displayName'] = 'An extremely long display name that keeps going and going and going';
    final repo = FakePlayersRepository()..profileData = data;
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('404 shows the neutral not-found state and no follow button', (tester) async {
    await phone(tester);
    final repo = FakePlayersRepository()..profileError = apiError(404, 'not_found');
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('player-not-found')), findsOneWidget);
    expect(find.byKey(const Key('follow-button')), findsNothing);
  });

  testWidgets('signed out: no /me/follows call, and tapping Follow opens login instead of flipping state', (tester) async {
    await phone(tester);
    var loginOpened = 0;
    final repo = FakePlayersRepository();
    await tester.pumpWidget(_app(repo, onLogIn: () => loginOpened++));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('follow-button')));
    expect(loginOpened, 1);
    expect(repo.myFollowsCalls, 0);
    expect(repo.followCalls, isEmpty);
  });

  testWidgets('own profile has no follow button', (tester) async {
    await phone(tester);
    final repo = FakePlayersRepository()..profileData = profileJson(id: 'me1');
    await tester.pumpWidget(_app(repo, meId: 'me1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('follow-button')), findsNothing);
  });

  testWidgets('follow: optimistic flip, correct PUT, and the follower count moves by one despite the cached body', (tester) async {
    await phone(tester);
    final repo = FakePlayersRepository()..profileData = profileJson(followerCount: 10);
    await tester.pumpWidget(_app(repo, meId: 'me1'));
    await tester.pumpAndSettle();
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('10 followers'), findsOneWidget);
    await tester.tap(find.byKey(const Key('follow-button')));
    await tester.pumpAndSettle();
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('11 followers'), findsOneWidget);
    expect(repo.followCalls.single.username, 'ada');
  });

  testWidgets('blocked follow rolls the button back and shows the blocked message', (tester) async {
    await phone(tester);
    final repo = FakePlayersRepository()..followErrors.add(apiError(403, 'follow_blocked'));
    await tester.pumpWidget(_app(repo, meId: 'me1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('follow-button')));
    await tester.pumpAndSettle();
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text("You can't follow this player."), findsOneWidget);
    expect(find.text('10 followers'), findsOneWidget);
  });

  testWidgets('a session-expired follow (401) sends the user to login', (tester) async {
    await phone(tester);
    var loginOpened = 0;
    final repo = FakePlayersRepository()..followErrors.add(apiError(401, 'unauthorized'));
    await tester.pumpWidget(_app(repo, meId: 'me1', onLogIn: () => loginOpened++));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('follow-button')));
    await tester.pumpAndSettle();
    expect(loginOpened, 1);
    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets('already following: shows Following, and "Follows you" when they follow back; unfollow flips it', (tester) async {
    await phone(tester);
    final repo = FakePlayersRepository()..sets = const FollowSets(followingIds: {'p1'}, followerIds: {'p1'});
    await tester.pumpWidget(_app(repo, meId: 'me1'));
    await tester.pumpAndSettle();
    expect(find.text('Following'), findsOneWidget);
    expect(find.byKey(const Key('follows-you-chip')), findsOneWidget);
    await tester.tap(find.byKey(const Key('follow-button')));
    await tester.pumpAndSettle();
    expect(find.text('Follow'), findsOneWidget);
    expect(repo.unfollowCalls, ['ada']);
  });
}
```

- [ ] **Step 2: Failing follow-list tests**

```dart
// test/features/follow_list_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/players/follow_list_screen.dart';
import 'package:sentinelx_mobile/features/players/players_providers.dart';

import '../support/fake_players_repository.dart';
import '../support/players_fixtures.dart';

Widget _app(FakePlayersRepository repo, {FollowListKind kind = FollowListKind.followers, bool signedIn = false, void Function(String)? onTap}) =>
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        playersRepositoryProvider.overrideWithValue(repo),
        meProvider.overrideWith((ref) async => signedIn
            ? const MeResponse(id: 'me1', email: null, roles: [], isStaff: false, isAdmin: false, profile: null)
            : null),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FollowListScreen(username: 'ada', kind: kind, onPlayerTap: onTap ?? (_) {}),
      ),
    );

void main() {
  testWidgets('a tombstone entry renders "Deleted player" and is not tappable; a live entry navigates', (tester) async {
    final repo = FakePlayersRepository()
      ..followerList = [FollowEntry.fromJson(followEntryJson('u1', 'bola')), FollowEntry.fromJson(followEntryJson('u2', null))];
    String? tapped;
    await tester.pumpWidget(_app(repo, onTap: (u) => tapped = u));
    await tester.pumpAndSettle();
    expect(find.text('Deleted player'), findsOneWidget);
    await tester.tap(find.text('Deleted player'));
    expect(tapped, isNull);
    await tester.tap(find.text('BOLA'));
    expect(tapped, 'bola');
  });

  testWidgets('signed in: Following / Follows you chips come from /me/follows; signed out: no chips and no /me call', (tester) async {
    final repo = FakePlayersRepository()
      ..followerList = [FollowEntry.fromJson(followEntryJson('u1', 'bola')), FollowEntry.fromJson(followEntryJson('me1', 'me_user'))]
      ..sets = const FollowSets(followingIds: {'u1', 'me1'}, followerIds: {'u1'});
    await tester.pumpWidget(_app(repo, signedIn: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chip-following-u1')), findsOneWidget);
    expect(find.byKey(const Key('chip-follows-you-u1')), findsOneWidget);
    expect(find.byKey(const Key('chip-following-me1')), findsNothing); // never for the viewer's own row

    final anon = FakePlayersRepository()..followerList = [FollowEntry.fromJson(followEntryJson('u1', 'bola'))];
    await tester.pumpWidget(_app(anon));
    await tester.pumpAndSettle();
    expect(anon.myFollowsCalls, 0);
    expect(find.byKey(const Key('chip-following-u1')), findsNothing);
  });

  testWidgets('empty followers vs empty following show their own messages', (tester) async {
    await tester.pumpWidget(_app(FakePlayersRepository()));
    await tester.pumpAndSettle();
    expect(find.text('No followers yet.'), findsOneWidget);
    await tester.pumpWidget(_app(FakePlayersRepository(), kind: FollowListKind.following));
    await tester.pumpAndSettle();
    expect(find.text('Not following anyone yet.'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run both files to fail** — FAIL (screens missing).
- [ ] **Step 4: Implement** `profile_sections.dart`, `player_profile_screen.dart`, `follow_list_screen.dart` to the behavior above. Follow-button wiring:

```dart
Future<void> _toggle(BuildContext context, WidgetRef ref, ProfileHeader p, bool following) async {
  final notifier = ref.read(myFollowsProvider.notifier);
  final failure = following
      ? await notifier.unfollow(targetId: p.id, username: p.username)
      : await notifier.follow(targetId: p.id, username: p.username);
  if (failure == null || !context.mounted) return;
  if (failure == FollowFailure.unauthorized) return onLogIn();
  final l10n = AppLocalizations.of(context);
  final message = switch (failure) {
    FollowFailure.self => l10n.followErrorSelf,
    FollowFailure.blocked => l10n.followErrorBlocked,
    FollowFailure.notFound => l10n.followErrorNotFound,
    _ => l10n.followErrorGeneric,
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
```
Follower count shown = `stats.followerCount + (ref.watch(followerDeltaProvider)[p.id] ?? 0)`.

- [ ] **Step 5:** `flutter test test/features/player_profile_screen_test.dart test/features/follow_list_screen_test.dart` → PASS; `flutter analyze` clean.
- [ ] **Step 6:** Commit `feat(players): profile screen with follow, followers/following lists`.

---

### Task 7: My progress overview

**Files:**
- Create: `lib/features/progress/progress_repository.dart`, `lib/features/progress/progress_providers.dart` (overview part only here), `lib/features/progress/my_progress_screen.dart`
- Create: `test/support/fake_progress_repository.dart`
- Test: `test/features/my_progress_screen_test.dart`

**Interfaces:**
- Consumes: `apiClientProvider`, `meProvider`, `tierLabel`, `humanizeCode`, ARB keys.
- Produces:

```dart
abstract class ProgressRepository {
  Future<MyProgress> progress();
  Future<HistoryPage<XpEvent>> xp(String? cursor);
  Future<HistoryPage<SxScoreEvent>> score(String? cursor);
  Future<HistoryPage<CoinTransaction>> coins(String? cursor);
}
final progressRepositoryProvider = Provider<ProgressRepository>(...);
final progressProvider = FutureProvider.autoDispose<MyProgress?>(...);   // null (NO request) when signed out
class MyProgressScreen extends ConsumerWidget { const MyProgressScreen({super.key, required this.onGoTo, required this.onLogIn}); final void Function(String path) onGoTo; final VoidCallback onLogIn; }
```

**Screen behavior.** `AppBar(title: l10n.progressTitle)`; signed out (`meProvider` → null) → `Key('progress-signin')` message `l10n.progressSignIn` + `ElevatedButton(Key('progress-login'), onPressed: onLogIn)` and **no `/me/progress` request**. Signed in → `RefreshIndicator` + `ListView` of cards:
- **XP** (`progressXpHeading`): `tierLabel(membershipTier)`, `p.xp` XP; when `tierProgress != null`: `LinearProgressIndicator(value: fraction)` + `l10n.progressXpToNext(xpIntoTier, xpForNextTier, tierLabel(next))`; when null: `l10n.progressMaxTier`. The app **never computes** these numbers.
- **SX Score** (`progressSxScore`): score + humanized `sentinelTier` when non-null.
- **Coins** (`progressCoins`): `coinBalance`.
- **Season** (`progressSeasonHeading`): `seasonStanding == null` → `progressSeasonNone`; else name (if non-null), `rank == null ? progressSeasonUnranked : progressSeasonRank(rank)`, `seasonsPoints(points)` (3a key), `progressToRankSixteen(pointsAtRankSixteen)`, and a `progressSeasonMonthly` line with `monthlyRank`/`monthlyPoints`.
- Three `ListTile`s (`Key('progress-link-xp')`, `Key('progress-link-score')`, `Key('progress-link-coins')`) → `onGoTo('/account/progress/xp' | '/score' | '/coins')`.
- Error → tappable `l10n.commonLoadError` invalidating `progressProvider`.

- [ ] **Step 1: Fake repository**

```dart
// test/support/fake_progress_repository.dart
import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/features/progress/progress_repository.dart';

typedef Pager<T> = HistoryPage<T> Function(String? cursor);

class FakeProgressRepository implements ProgressRepository {
  Map<String, dynamic> progressData = progressJson();
  Object? progressError;
  var progressCalls = 0;

  Pager<XpEvent>? xpPager;
  Pager<SxScoreEvent>? scorePager;
  Pager<CoinTransaction>? coinPager; // a pager may throw to simulate a failed page
  final xpCursors = <String?>[];
  final scoreCursors = <String?>[];
  final coinCursors = <String?>[];

  @override
  Future<MyProgress> progress() async {
    progressCalls++;
    if (progressError != null) throw progressError!;
    return MyProgress.fromJson(progressData);
  }

  @override
  Future<HistoryPage<XpEvent>> xp(String? cursor) async {
    xpCursors.add(cursor);
    return xpPager!(cursor);
  }

  @override
  Future<HistoryPage<SxScoreEvent>> score(String? cursor) async {
    scoreCursors.add(cursor);
    return scorePager!(cursor);
  }

  @override
  Future<HistoryPage<CoinTransaction>> coins(String? cursor) async {
    coinCursors.add(cursor);
    return coinPager!(cursor);
  }
}

Map<String, dynamic> progressJson({bool maxTier = false, bool withSeason = true}) => {
      'xp': maxTier ? 60000 : 1500,
      'membershipTier': maxTier ? 'legend' : 'guardian',
      'tierProgress': maxTier ? null : {'current': 'guardian', 'next': 'elite', 'xpIntoTier': 500, 'xpForNextTier': 4000},
      'sxScore': 980,
      'sentinelTier': 'trusted',
      'coinBalance': 1234,
      'seasonStanding': withSeason
          ? {'seasonName': 'Season 1', 'rank': 7, 'points': 40, 'pointsAtRankSixteen': 22, 'monthlyRank': null, 'monthlyPoints': 6}
          : null,
    };
```

- [ ] **Step 2: Failing tests**

```dart
// test/features/my_progress_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/progress/my_progress_screen.dart';
import 'package:sentinelx_mobile/features/progress/progress_providers.dart';

import '../support/fake_players_repository.dart';
import '../support/fake_progress_repository.dart';

Widget _app(FakeProgressRepository repo, {bool signedIn = true, void Function(String)? onGoTo, VoidCallback? onLogIn}) => ProviderScope(
      retry: (_, _) => null,
      overrides: [
        progressRepositoryProvider.overrideWithValue(repo),
        meProvider.overrideWith((ref) async => signedIn
            ? const MeResponse(id: 'me1', email: null, roles: [], isStaff: false, isAdmin: false, profile: null)
            : null),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MyProgressScreen(onGoTo: onGoTo ?? (_) {}, onLogIn: onLogIn ?? () {}),
      ),
    );

void main() {
  testWidgets('shows XP with progress to the next tier, SX Score, coins and the season card', (tester) async {
    await tester.pumpWidget(_app(FakeProgressRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Guardian'), findsWidgets);
    expect(find.text('500 / 4000 XP to Elite'), findsOneWidget);
    expect(find.text('1234'), findsWidgets);
    expect(find.text('Rank #7'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('max tier shows the max-tier message and no progress bar', (tester) async {
    await tester.pumpWidget(_app(FakeProgressRepository()..progressData = progressJson(maxTier: true)));
    await tester.pumpAndSettle();
    expect(find.text('Max tier reached'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('no active season shows the empty season card; an unranked player shows Unranked', (tester) async {
    await tester.pumpWidget(_app(FakeProgressRepository()..progressData = progressJson(withSeason: false)));
    await tester.pumpAndSettle();
    expect(find.text('No active season.'), findsOneWidget);
    final unranked = progressJson();
    (unranked['seasonStanding'] as Map<String, dynamic>)['rank'] = null;
    await tester.pumpWidget(_app(FakeProgressRepository()..progressData = unranked));
    await tester.pumpAndSettle();
    expect(find.text('Unranked'), findsWidgets);
  });

  testWidgets('signed out: login prompt, login callback, and NO /me/progress request', (tester) async {
    final repo = FakeProgressRepository();
    var login = 0;
    await tester.pumpWidget(_app(repo, signedIn: false, onLogIn: () => login++));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('progress-signin')), findsOneWidget);
    await tester.tap(find.byKey(const Key('progress-login')));
    expect(login, 1);
    expect(repo.progressCalls, 0);
  });

  testWidgets('history tiles navigate to the three history routes', (tester) async {
    final visited = <String>[];
    await tester.pumpWidget(_app(FakeProgressRepository(), onGoTo: visited.add));
    await tester.pumpAndSettle();
    for (final k in ['progress-link-xp', 'progress-link-score', 'progress-link-coins']) {
      await tester.ensureVisible(find.byKey(Key(k)));
      await tester.tap(find.byKey(Key(k)));
    }
    expect(visited, ['/account/progress/xp', '/account/progress/score', '/account/progress/coins']);
  });

  testWidgets('a failed load shows the retry message, not a stack trace', (tester) async {
    await tester.pumpWidget(_app(FakeProgressRepository()..progressError = apiError(500, 'internal')));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load. Tap to retry."), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run to fail** — FAIL.
- [ ] **Step 4: Implement**

```dart
// lib/features/progress/progress_repository.dart
import '../../core/api/api_client.dart';
import '../../core/api/players_models.dart';

abstract class ProgressRepository {
  Future<MyProgress> progress();
  Future<HistoryPage<XpEvent>> xp(String? cursor);
  Future<HistoryPage<SxScoreEvent>> score(String? cursor);
  Future<HistoryPage<CoinTransaction>> coins(String? cursor);
}

class ApiProgressRepository implements ProgressRepository {
  ApiProgressRepository(this._api);
  final ApiClient _api;
  @override
  Future<MyProgress> progress() => _api.getMyProgress();
  @override
  Future<HistoryPage<XpEvent>> xp(String? cursor) => _api.getMyXpEvents(cursor: cursor);
  @override
  Future<HistoryPage<SxScoreEvent>> score(String? cursor) => _api.getMySxScoreEvents(cursor: cursor);
  @override
  Future<HistoryPage<CoinTransaction>> coins(String? cursor) => _api.getMyCoinTransactions(cursor: cursor);
}
```

```dart
// lib/features/progress/progress_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/players_models.dart';
import '../../core/providers.dart';
import 'progress_repository.dart';

final progressRepositoryProvider =
    Provider<ProgressRepository>((ref) => ApiProgressRepository(ref.watch(apiClientProvider)));

/// Signed out -> null WITHOUT calling the API.
final progressProvider = FutureProvider.autoDispose<MyProgress?>((ref) async {
  final me = await ref.watch(meProvider.future);
  if (me == null) return null;
  return ref.watch(progressRepositoryProvider).progress();
});
```
Then `MyProgressScreen` per the behavior above.

- [ ] **Step 5:** `flutter test test/features/my_progress_screen_test.dart` → PASS; `flutter analyze`.
- [ ] **Step 6:** Commit `feat(progress): my-progress overview screen`.

---

### Task 8: History screens with cursor paging

**Files:**
- Modify: `lib/features/progress/progress_providers.dart` (append)
- Create: `lib/features/progress/history_list_screen.dart`
- Test: `test/features/history_screens_test.dart`

**Interfaces:**
- Consumes: `ProgressRepository`, label maps.
- Produces (appended to `progress_providers.dart`):

```dart
class HistoryState<T> {
  const HistoryState({required this.items, required this.nextCursor, this.loadingMore = false, this.loadMoreFailed = false});
  final List<T> items;
  final String? nextCursor;        // null = last page reached
  final bool loadingMore;
  final bool loadMoreFailed;
  HistoryState<T> copyWith({List<T>? items, Object? nextCursor = _keep, bool? loadingMore, bool? loadMoreFailed});
}

class HistoryNotifier<T> extends AsyncNotifier<HistoryState<T>> {
  HistoryNotifier(this._fetch, this._idOf);
  final Future<HistoryPage<T>> Function(Ref ref, String? cursor) _fetch;
  final String Function(T) _idOf;
  Future<HistoryState<T>> build();                    // first page; requires a signed-in user (else empty, no request)
  Future<void> loadMore({bool retry = false});        // guarded — see rules
}

final xpHistoryProvider = AsyncNotifierProvider.autoDispose<HistoryNotifier<XpEvent>, HistoryState<XpEvent>>(...);
final scoreHistoryProvider = AsyncNotifierProvider.autoDispose<HistoryNotifier<SxScoreEvent>, HistoryState<SxScoreEvent>>(...);
final coinHistoryProvider = AsyncNotifierProvider.autoDispose<HistoryNotifier<CoinTransaction>, HistoryState<CoinTransaction>>(...);
class HistoryListScreen<T> extends ConsumerWidget {
  const HistoryListScreen({super.key, required this.title, required this.provider, required this.rowBuilder});
  final String title;
  final AsyncNotifierProvider<HistoryNotifier<T>, HistoryState<T>> provider;
  final Widget Function(BuildContext context, T item) rowBuilder;
}
```

`loadMore` rules (each is tested): does nothing when there is no state, when `nextCursor == null`, when `loadingMore`, or when `loadMoreFailed && !retry` (**a failure never auto-loops**); sets `loadingMore` before the request; appends the page, **skipping any id already present** (defensive against a duplicated row) and taking the new `nextCursor`; on error sets `loadMoreFailed: true, loadingMore: false` and keeps the items. Signed-out `build()` returns an empty state without a request (the routes are only reachable signed in, but a deep link must not 401-loop).

**Screen behavior.** Loading → spinner; first-page error → tappable `l10n.commonLoadError` (invalidate); empty → `l10n.historyEmpty`. `ListView.builder` with `items.length + (hasFooter ? 1 : 0)` rows, where the footer exists when `nextCursor != null || loadingMore || loadMoreFailed`:
- normal footer (`Key('history-loading-more')`): a small spinner; when built it schedules `loadMore()` via `WidgetsBinding.instance.addPostFrameCallback` (the notifier's guards make repeated builds safe);
- failed footer (`Key('history-retry')`): `TextButton(l10n.historyLoadMoreError)` → `loadMore(retry: true)` — **does not** schedule anything by itself.
`RefreshIndicator` invalidates the provider.

Row builders (in `history_list_screen.dart`, top-level functions used by the router in Task 9): shared date text = `MaterialLocalizations.of(context).formatShortDate(DateTime.parse(createdAt).toLocal())`, falling back to the raw string when `DateTime.tryParse` returns null.
- XP: title `xpSourceLabel(l10n, e.source)`, trailing `+${e.xp} XP`.
- Score: title `scoreEventLabel(l10n, e.eventType)`, trailing signed delta (`+8` green / `-15` red via `SxColors.success` / `Colors.redAccent`; `0` neutral).
- Coins: title `coinSourceLabel(l10n, e.source)`, subtitle description (if non-null) and date, trailing signed amount plus `l10n.historyBalanceAfter(e.balanceAfter)`.

- [ ] **Step 1: Failing tests**

```dart
// test/features/history_screens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/progress/history_list_screen.dart';
import 'package:sentinelx_mobile/features/progress/progress_providers.dart';

import '../support/fake_players_repository.dart';
import '../support/fake_progress_repository.dart';

XpEvent _xp(int i, {String source = 'match_won'}) => XpEvent(id: 'x$i', xp: 10 + i, source: source, createdAt: '2026-09-0${(i % 9) + 1}T10:00:00+00:00');

HistoryPage<XpEvent> _page(List<XpEvent> items, String? next) => HistoryPage(items: items, nextCursor: next);

Widget _xpApp(FakeProgressRepository repo, {bool signedIn = true}) => ProviderScope(
      retry: (_, _) => null,
      overrides: [
        progressRepositoryProvider.overrideWithValue(repo),
        meProvider.overrideWith((ref) async => signedIn
            ? const MeResponse(id: 'me1', email: null, roles: [], isStaff: false, isAdmin: false, profile: null)
            : null),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HistoryListScreen<XpEvent>(title: 'XP history', provider: xpHistoryProvider, rowBuilder: xpRow),
      ),
    );

void main() {
  testWidgets('loads the first page, then follows nextCursor exactly once per page and stops on the last', (tester) async {
    final repo = FakeProgressRepository()
      ..xpPager = (cursor) => switch (cursor) {
            null => _page([_xp(1), _xp(2), _xp(3)], 'c1'),
            'c1' => _page([_xp(4), _xp(5)], null),
            _ => throw StateError('unexpected cursor $cursor'),
          };
    await tester.pumpWidget(_xpApp(repo));
    await tester.pumpAndSettle();
    expect(repo.xpCursors, [null, 'c1']); // second page loaded automatically, third never requested
    expect(find.text('+11 XP'), findsOneWidget);
    expect(find.text('+15 XP'), findsOneWidget);
    expect(find.byKey(const Key('history-loading-more')), findsNothing);
  });

  testWidgets('a failed loadMore shows a retry tile and does NOT loop; tapping it retries the same cursor', (tester) async {
    var failSecondPage = true;
    final repo = FakeProgressRepository()
      ..xpPager = (cursor) {
        if (cursor == 'c1' && failSecondPage) throw apiError(0, 'network');
        return cursor == null ? _page([_xp(1), _xp(2)], 'c1') : _page([_xp(3)], null);
      };
    await tester.pumpWidget(_xpApp(repo));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-retry')), findsOneWidget);
    final callsAfterFailure = repo.xpCursors.length; // [null, 'c1']
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(repo.xpCursors.length, callsAfterFailure, reason: 'a failed page must not be re-requested automatically');
    failSecondPage = false;
    await tester.tap(find.byKey(const Key('history-retry')));
    await tester.pumpAndSettle();
    expect(repo.xpCursors.last, 'c1');
    expect(find.byKey(const Key('history-retry')), findsNothing);
    expect(find.text('+13 XP'), findsOneWidget);
  });

  testWidgets('an id repeated across pages is shown once', (tester) async {
    final repo = FakeProgressRepository()
      ..xpPager = (cursor) => cursor == null ? _page([_xp(1), _xp(2)], 'c1') : _page([_xp(2), _xp(3)], null);
    await tester.pumpWidget(_xpApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('+12 XP'), findsOneWidget);
    expect(find.text('+13 XP'), findsOneWidget);
  });

  testWidgets('an unknown source code renders a humanized label, not blank', (tester) async {
    final repo = FakeProgressRepository()..xpPager = (_) => _page([_xp(1, source: 'referral_bonus_v2')], null);
    await tester.pumpWidget(_xpApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('Referral bonus v2'), findsOneWidget);
  });

  testWidgets('empty history shows the empty state', (tester) async {
    final repo = FakeProgressRepository()..xpPager = (_) => _page(const [], null);
    await tester.pumpWidget(_xpApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('No activity yet.'), findsOneWidget);
  });

  testWidgets('signed out: no request is made', (tester) async {
    final repo = FakeProgressRepository()..xpPager = (_) => _page([_xp(1)], null);
    await tester.pumpWidget(_xpApp(repo, signedIn: false));
    await tester.pumpAndSettle();
    expect(repo.xpCursors, isEmpty);
  });

  testWidgets('score rows show signed deltas; coin rows show a minus for spends and the resulting balance', (tester) async {
    final repo = FakeProgressRepository()
      ..scorePager = (_) => HistoryPage(items: [
            SxScoreEvent.fromJson({'id': 's1', 'eventType': 'no_show', 'pointsDelta': -15, 'matchId': null, 'createdAt': '2026-09-01T10:00:00+00:00'}),
            SxScoreEvent.fromJson({'id': 's2', 'eventType': 'match_completed', 'pointsDelta': 8, 'matchId': 'm1', 'createdAt': '2026-09-02T10:00:00+00:00'}),
          ], nextCursor: null)
      ..coinPager = (_) => HistoryPage(items: [
            CoinTransaction.fromJson({'id': 'c1', 'amount': -200, 'balanceAfter': 50, 'source': 'post_boost', 'description': 'Boosted a post', 'createdAt': '2026-09-01T10:00:00+00:00'}),
          ], nextCursor: null);
    Widget app(Widget home) => ProviderScope(
          retry: (_, _) => null,
          overrides: [
            progressRepositoryProvider.overrideWithValue(repo),
            meProvider.overrideWith((ref) async => const MeResponse(id: 'me1', email: null, roles: [], isStaff: false, isAdmin: false, profile: null)),
          ],
          child: MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: home),
        );
    await tester.pumpWidget(app(HistoryListScreen<SxScoreEvent>(title: 'Score', provider: scoreHistoryProvider, rowBuilder: scoreRow)));
    await tester.pumpAndSettle();
    expect(find.text('-15'), findsOneWidget);
    expect(find.text('+8'), findsOneWidget);
    expect(find.text('No-show'), findsOneWidget);
    await tester.pumpWidget(app(HistoryListScreen<CoinTransaction>(title: 'Coins', provider: coinHistoryProvider, rowBuilder: coinRow)));
    await tester.pumpAndSettle();
    expect(find.text('-200'), findsOneWidget);
    expect(find.text('Balance 50'), findsOneWidget);
    expect(find.text('Boosted a post'), findsOneWidget);
  });
}
```
(`xpRow`, `scoreRow`, `coinRow` are the three row builders exported from `history_list_screen.dart`.)

- [ ] **Step 2: Run to fail** — FAIL (symbols missing).
- [ ] **Step 3: Implement** the notifier (append to `progress_providers.dart`):

```dart
const _keep = Object();

class HistoryState<T> {
  const HistoryState({required this.items, required this.nextCursor, this.loadingMore = false, this.loadMoreFailed = false});
  final List<T> items;
  final String? nextCursor;
  final bool loadingMore;
  final bool loadMoreFailed;

  HistoryState<T> copyWith({List<T>? items, Object? nextCursor = _keep, bool? loadingMore, bool? loadMoreFailed}) => HistoryState(
        items: items ?? this.items,
        nextCursor: identical(nextCursor, _keep) ? this.nextCursor : nextCursor as String?,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

class HistoryNotifier<T> extends AsyncNotifier<HistoryState<T>> {
  HistoryNotifier(this._fetch, this._idOf);
  final Future<HistoryPage<T>> Function(Ref ref, String? cursor) _fetch;
  final String Function(T) _idOf;

  @override
  Future<HistoryState<T>> build() async {
    final me = await ref.watch(meProvider.future);
    if (me == null) return HistoryState<T>(items: const [], nextCursor: null);
    final page = await _fetch(ref, null);
    return HistoryState<T>(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> loadMore({bool retry = false}) async {
    final s = state.value;
    if (s == null || s.nextCursor == null || s.loadingMore) return;
    if (s.loadMoreFailed && !retry) return; // never auto-loop after a failure
    state = AsyncData(s.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final page = await _fetch(ref, s.nextCursor);
      final seen = s.items.map(_idOf).toSet();
      state = AsyncData(HistoryState<T>(
        items: [...s.items, ...page.items.where((e) => !seen.contains(_idOf(e)))],
        nextCursor: page.nextCursor,
      ));
    } catch (_) {
      state = AsyncData(s.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }
}

final xpHistoryProvider = AsyncNotifierProvider.autoDispose<HistoryNotifier<XpEvent>, HistoryState<XpEvent>>(
  () => HistoryNotifier<XpEvent>((ref, c) => ref.read(progressRepositoryProvider).xp(c), (e) => e.id),
);
final scoreHistoryProvider = AsyncNotifierProvider.autoDispose<HistoryNotifier<SxScoreEvent>, HistoryState<SxScoreEvent>>(
  () => HistoryNotifier<SxScoreEvent>((ref, c) => ref.read(progressRepositoryProvider).score(c), (e) => e.id),
);
final coinHistoryProvider = AsyncNotifierProvider.autoDispose<HistoryNotifier<CoinTransaction>, HistoryState<CoinTransaction>>(
  () => HistoryNotifier<CoinTransaction>((ref, c) => ref.read(progressRepositoryProvider).coins(c), (e) => e.id),
);
```
`Ref` comes from `flutter_riverpod`. If the analyzer rejects the `AsyncNotifierProvider<HistoryNotifier<T>, HistoryState<T>>` parameter type on `HistoryListScreen` (Riverpod 3 unifies the auto-dispose types, so it should compile as written), adjust only that type annotation — never the behavior. Then implement `HistoryListScreen` and the three row builders as specified above.

- [ ] **Step 4:** `flutter test test/features/history_screens_test.dart` → PASS; `flutter analyze`.
- [ ] **Step 5:** Commit `feat(progress): cursor-paged XP, SX Score and coin history screens`.

---

### Task 9: Routing, web links, entry points

**Files:**
- Modify: `lib/router/app_router.dart`, `lib/core/routing/web_links.dart`, `lib/features/home/home_screen.dart`, `lib/features/account/account_screen.dart`, `test/features/account_screen_test.dart`
- Test: `test/core/web_links_test.dart` (append), `test/features/players_routes_test.dart` (create), `test/features/home_screen_test.dart` (append), `test/features/account_screen_test.dart` (update + append)

**Interfaces:**
- Consumes: all screens from Tasks 4–8.
- Changes: `AccountScreen` gains `required VoidCallback onOpenProgress`.

- [ ] **Step 1: Failing tests**

Append to `test/core/web_links_test.dart` inside its `main()`:

```dart
  test('maps player web paths (with and without a locale), keeps usernames intact and is idempotent', () {
    expect(resolveWebLink('https://sentinelxesports.com.ng/players'), '/players');
    expect(resolveWebLink('https://sentinelxesports.com.ng/players/ada'), '/players/ada');
    expect(resolveWebLink('https://sentinelxesports.com.ng/fr/players/ada'), '/players/ada');
    expect(resolveWebLink('https://sentinelxesports.com.ng/players/ada/followers'), '/players/ada/followers');
    expect(resolveWebLink('https://sentinelxesports.com.ng/en/players/ada/following?x=1'), '/players/ada/following');
    expect(resolveWebLink('https://sentinelxesports.com.ng/players/a%20b'), '/players/a%20b');
    expect(resolveWebLink('https://sentinelxesports.com.ng/players/ada/unknown'), isNull);
    expect(resolveWebLink('https://evil.example/players/ada'), isNull);
    // idempotent: the router redirect must never loop
    for (final p in ['/players', '/players/ada', '/players/ada/followers', '/players/a%20b']) {
      expect(resolveWebLink(p), p);
    }
    // in-app paths of this phase pass through untouched (null = no redirect)
    expect(resolveWebLink('/account/progress'), isNull);
  });
```

```dart
// test/features/players_routes_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/players/follow_list_screen.dart';
import 'package:sentinelx_mobile/features/players/player_profile_screen.dart';
import 'package:sentinelx_mobile/features/players/players_directory_screen.dart';
import 'package:sentinelx_mobile/features/players/players_providers.dart';
import 'package:sentinelx_mobile/features/progress/history_list_screen.dart';
import 'package:sentinelx_mobile/features/progress/my_progress_screen.dart';
import 'package:sentinelx_mobile/features/progress/progress_providers.dart';
import 'package:sentinelx_mobile/router/app_router.dart';

import '../support/fake_players_repository.dart';
import '../support/fake_progress_repository.dart';

Future<void> _pump(WidgetTester tester, String location) async {
  final progress = FakeProgressRepository()
    ..xpPager = ((_) => const HistoryPage<XpEvent>(items: [], nextCursor: null))
    ..scorePager = ((_) => const HistoryPage<SxScoreEvent>(items: [], nextCursor: null))
    ..coinPager = ((_) => const HistoryPage<CoinTransaction>(items: [], nextCursor: null));
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      playersRepositoryProvider.overrideWithValue(FakePlayersRepository()),
      progressRepositoryProvider.overrideWithValue(progress),
      meProvider.overrideWith((ref) async => const MeResponse(id: 'me1', email: null, roles: [], isStaff: false, isAdmin: false, profile: null)),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: buildAppRouter(initialLocation: location),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('/players resolves to the directory', (tester) async {
    await _pump(tester, '/players');
    expect(find.byType(PlayersDirectoryScreen), findsOneWidget);
  });
  testWidgets('/players/ada resolves to the profile with the username', (tester) async {
    await _pump(tester, '/players/ada');
    expect(tester.widget<PlayerProfileScreen>(find.byType(PlayerProfileScreen)).username, 'ada');
  });
  testWidgets('followers / following resolve with the right kind', (tester) async {
    await _pump(tester, '/players/ada/followers');
    expect(tester.widget<FollowListScreen>(find.byType(FollowListScreen)).kind, FollowListKind.followers);
    await _pump(tester, '/players/ada/following');
    expect(tester.widget<FollowListScreen>(find.byType(FollowListScreen)).kind, FollowListKind.following);
  });
  testWidgets('/account/progress and its three histories resolve inside the Account branch', (tester) async {
    await _pump(tester, '/account/progress');
    expect(find.byType(MyProgressScreen), findsOneWidget);
    await _pump(tester, '/account/progress/xp');
    expect(find.byType(HistoryListScreen<XpEvent>), findsOneWidget);
  });
}
```
(If pumping the real router throws on `Supabase.instance` access in this repo's setup, copy the override set the neighboring router tests use (`test/router/app_router_test.dart`) to stub `apiClientProvider`/`sessionProvider`.)

Append to `test/features/home_screen_test.dart`, following that file's existing pump/override pattern (copy the overrides its neighbor tests use for `onboardingGateProvider`/`sessionStartedProvider`):

```dart
  testWidgets('Home has a Players entry', (tester) async {
    final visited = <String>[];
    // …pump HomeScreen(onGoTo: visited.add) exactly as the other tests in this file do…
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('home-link-players')));
    await tester.tap(find.byKey(const Key('home-link-players')));
    expect(visited, ['/players']);
  });
```

Update **both** existing `AccountScreen(...)` calls in `test/features/account_screen_test.dart` to pass `onOpenProgress: () {}` and add `localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales` to their `MaterialApp` (the new tile uses ARB copy), then append:

```dart
  Widget accountApp(MeResponse? me, VoidCallback onOpenProgress) => ProviderScope(
        retry: (_, _) => null,
        overrides: [meProvider.overrideWith((ref) async => me)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}, onOpenProgress: onOpenProgress),
        ),
      );

  testWidgets('signed in: the My progress tile opens progress', (tester) async {
    var opened = 0;
    const me = MeResponse(id: 'u1', email: 'a@b.com', roles: [], isStaff: false, isAdmin: false, profile: null);
    await tester.pumpWidget(accountApp(me, () => opened++));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-progress')));
    expect(opened, 1);
  });

  testWidgets('signed out: there is no My progress tile', (tester) async {
    await tester.pumpWidget(accountApp(null, () {}));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-progress')), findsNothing);
  });
```
(Add `import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';` to that test file.)

- [ ] **Step 2: Run to fail** — FAIL.
- [ ] **Step 3: Implement**

`web_links.dart` — after the `if (segments.isEmpty) return '/';` line and **before** the `switch` (do not reorder existing cases; 3a's `seasons` line may already be there — keep it):

```dart
  if (segments.first == 'players') {
    if (segments.length == 1) return '/players';
    final username = Uri.encodeComponent(segments[1]);
    if (segments.length == 2) return '/players/$username';
    if (segments.length == 3 && (segments[2] == 'followers' || segments[2] == 'following')) {
      return '/players/$username/${segments[2]}';
    }
    return null;
  }
```

`app_router.dart` — add imports for the new screens, then inside the **first** `StatefulShellBranch` (Compete), after the existing routes (including 3a's), add:

```dart
            GoRoute(
              path: '/players',
              builder: (context, state) => PlayersDirectoryScreen(onPlayerTap: (u) => context.push('/players/${Uri.encodeComponent(u)}')),
              routes: [
                GoRoute(
                  path: ':username',
                  builder: (context, state) {
                    final username = state.pathParameters['username']!;
                    return PlayerProfileScreen(
                      username: username,
                      onLogIn: () => context.push('/login'),
                      onOpenFollowers: (u) => context.push('/players/${Uri.encodeComponent(u)}/followers'),
                      onOpenFollowing: (u) => context.push('/players/${Uri.encodeComponent(u)}/following'),
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'followers',
                      builder: (context, state) => FollowListScreen(
                        username: state.pathParameters['username']!,
                        kind: FollowListKind.followers,
                        onPlayerTap: (u) => context.push('/players/${Uri.encodeComponent(u)}'),
                      ),
                    ),
                    GoRoute(
                      path: 'following',
                      builder: (context, state) => FollowListScreen(
                        username: state.pathParameters['username']!,
                        kind: FollowListKind.following,
                        onPlayerTap: (u) => context.push('/players/${Uri.encodeComponent(u)}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
```
and turn the Account branch's `/account` route into one with children (keep its existing builder, add `onOpenProgress: () => context.push('/account/progress')`):

```dart
              routes: [
                GoRoute(
                  path: 'progress',
                  builder: (context, state) => MyProgressScreen(onGoTo: (p) => context.push(p), onLogIn: () => context.push('/login')),
                  routes: [
                    GoRoute(path: 'xp', builder: (context, state) => HistoryListScreen<XpEvent>(title: AppLocalizations.of(context).progressHistoryXp, provider: xpHistoryProvider, rowBuilder: xpRow)),
                    GoRoute(path: 'score', builder: (context, state) => HistoryListScreen<SxScoreEvent>(title: AppLocalizations.of(context).progressHistoryScore, provider: scoreHistoryProvider, rowBuilder: scoreRow)),
                    GoRoute(path: 'coins', builder: (context, state) => HistoryListScreen<CoinTransaction>(title: AppLocalizations.of(context).progressHistoryCoins, provider: coinHistoryProvider, rowBuilder: coinRow)),
                  ],
                ),
              ],
```
(add imports for `l10n/gen/app_localizations.dart` and `players_models.dart` in the router if not already present.)

`account_screen.dart` — add `required this.onOpenProgress` to the constructor and, in the **signed-in** column only, above the sign-out button:

```dart
                    ListTile(
                      key: const Key('account-progress'),
                      title: Text(AppLocalizations.of(context).accountMyProgress),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: onOpenProgress,
                    ),
```
`home_screen.dart` — after 3a's three tiles (or after the Top Players block if 3a is not on the base), add:

```dart
              ListTile(key: const Key('home-link-players'), title: Text(l10n.playersTitle), trailing: const Icon(Icons.chevron_right), onTap: () => onGoTo('/players')),
```

- [ ] **Step 4:** `flutter test test/core/web_links_test.dart test/features/players_routes_test.dart test/features/home_screen_test.dart test/features/account_screen_test.dart` → PASS; then the whole `flutter analyze && flutter test`.
- [ ] **Step 5:** Commit `feat(router): player and progress routes, web links, home/account entry points`.

---

### Task 10: Rebase, contract re-copy, staging exit check

- [ ] **Step 1: Rebase and refresh**

```bash
git fetch origin && git rebase origin/master
copy C:\Users\gorok\Videos\sentinelx\openapi\mobile-v1.json api\openapi.json   # from web main once PR 2 has merged; else the phase3b/web-endpoints worktree
flutter pub get && flutter gen-l10n
flutter analyze && flutter test
```
Conflicts in ARB/l10n, `api_client.dart`, `app_router.dart`, `home_screen.dart` are append-only: keep both sides, then re-run `flutter gen-l10n`. Never merge `api/openapi.json` textually.

- [ ] **Step 2: Confirm a non-production database exists before any write**

CLAUDE.md still says the only Supabase project is production, but the web plan verifies 3b against a staging project (`sentinelx-staging`, `ofxmoxpvwbemfouaowoa`). **Ask the owner which is true before the follow test.** If no staging exists, run only the read-only checks below, do **not** call `PUT/DELETE …/follow`, and mark the follow round trip "unverified" in the PR.

- [ ] **Step 3: Run against staging** (use the exact dev flags from `README.md` / `TESTING-NOTES.md`) at 375px on a device/emulator:
  - Directory search returns rows, own row absent; profile for a player with locked achievements shows only lock tiles; 404 for a made-up username; followers/following lists open profiles; a deleted account (if one exists) shows "Deleted player".
  - Signed in as a `zzqa_` QA account: Follow → button flips, refresh (pull-to-refresh) keeps it, the web profile shows the same follow, the target has **exactly one** `new_follower` notification; force-quit mid-request and re-tap → still exactly one; Unfollow → gone on web.
  - Account → My progress: XP/tier numbers equal the API; each history list opens, scrolls to the end, ends without a spinner.

- [ ] **Step 4: The exit check (spec §1)** — for 10 players, open the same profile on the **web** (staging) and compare in a table: stats, global rank, current streak, category stats, titles, last-10 matches, unlocked achievements **in the web's rarity order**, follower/following counts, posts/gallery. For one QA account, compare each history list to `select … order by created_at desc, id desc` (count and order; walk the pages to the end). Any mismatch is a bug against this plan or the web plan, not a "known difference". Record both tables in the PR description.

- [ ] **Step 5:** Update `TESTING-NOTES.md` (date, build, QA accounts created and removed with `anonymise_account`, what was verified), push `phase3b/screens`, open the PR. Description must include: base branch/merge order, the Task 0 Step 5 live-CHECK findings, the deviations below, and the exit tables.

---

## Deviations and follow-ups (record in the PR)

1. Directory avatars have no frame (API sends a slug, not a URL; the app has no slug→art table).
2. `profileTheme` / `usernameColour` are parsed but not rendered.
3. `GET /players` includes the viewer; the app filters its own username client-side (web-plan flag 1).
4. Follower count after a follow is corrected locally (+1/−1) because the public body is cached for 60 s.
5. No profile links from the 3a rows (rankings/seasons/hall of fame) — a small follow-up edit after both phases land (spec §1).
6. `AccountScreen` gained a required `onOpenProgress`; its two existing tests were updated.

## Self-Review (run against the spec)

**Spec coverage (§7 and §1 exit criterion)**

| Spec | Task |
|---|---|
| Directory: debounced search, rows → profile | 4 |
| Profile: header (avatar + frame, name, tier badges, country, bio), stats grid, rank/streak, category stats, titles, recent matches, achievements (`unlockedCount/total`, anonymous lock tiles), showcase strip, posts + gallery (read-only), counts → lists | 6 |
| Follow: state from `/me/follows`, optimistic, fresh key per tap (reused on retry), rollback + mapped error on 403/400, signed-out → `/login`, no Friend/Message, none on own profile | 5, 6 |
| Deleted account → neutral "player not found" | 6 |
| Followers/following lists with Following / Follows-you derived from `/me/follows` | 6 |
| My progress: tier/XP + bar, SX Score + sentinel tier, coins, season card | 7 |
| Three histories, infinite scroll on `nextCursor`, empty/error/retry, code→label maps in ARB, unknown-code fallback | 3, 8 |
| Routes incl. `resolveWebLink` for `/players…`; Account "My progress" + Home "Players" entries; tournaments slice untouched | 9 |
| Copy via ARB; new models file; `usedOperations` + contract test | 1–3 |
| Tests: empty/loading/error, follow rollback, locked tiles, cursor paging, signed-out follow redirect | 4–8 |
| §1 exit check (10 profiles, follow round trip, histories vs DB, locked absent) | 10 |

**Placeholder scan:** Task 6's screen layout and Task 7/8's widget trees are specified as structure + keys + exact strings (the 3a plan's precedent for pure layout code) with the behavior pinned by full tests; every logic-bearing unit (models, client, repositories, providers, controller, notifier, label maps, routes, web links) is written out. The one remaining "follow the neighboring test's pump pattern" instruction is Task 9's Home test, which needs the existing `home_screen_test.dart` overrides that only exist in that file.

**Type consistency:** `FollowListKind`, `followListProvider` record key `(String, FollowListKind)`, `myFollowsProvider`/`MyFollowsNotifier.follow/unfollow({targetId, username})`, `followerDeltaProvider`, `HistoryNotifier<T>`/`HistoryState<T>`, `xpRow`/`scoreRow`/`coinRow`, `PlayersRepository.follow(username, key)` vs `ApiClient.followPlayer(username, idempotencyKey:)` are used consistently across Tasks 2–9.
