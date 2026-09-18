# Tournament List → Detail → Bracket Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a fresh Flutter project wired to the live SentinelX Supabase project, and
build the smallest fully-connected read path — Tournament List → Tournament Detail →
Bracket — reading `tournaments`, `matches`, `games`, `profiles`, and `squads` directly via
`supabase_flutter`. No auth, no writes, no other screens.

**Architecture:** A single `TournamentsRepository` abstraction (interface +
`SupabaseTournamentsRepository` implementation) is the only thing that talks to Supabase.
Three screens (`TournamentListScreen`, `TournamentDetailScreen`, `BracketScreen`) take the
repository via constructor injection — no state-management package, just `StatefulWidget` +
`FutureBuilder`, per `CLAUDE.md`'s "no state-management package chosen yet." `go_router`
wires the three screens together behind a `buildAppRouter({repository})` factory, so tests
can swap in a fake repository at the router level, not just per-screen.

**Tech Stack:** Flutter 3.41.9 (stable) / Dart 3.11.5, `supabase_flutter`, `go_router`,
`flutter_test` (bundled). Verified run targets on this machine: `windows` (desktop) and
`chrome`/`edge` (web) — no Android/iOS device attached, though the Android toolchain is
installed.

**Spec:** `docs/superpowers/specs/2026-09-18-flutter-mobile-app-phase1-design.md` — see
§3 ("Tournament list / detail" and "Bracket page" rows) and §7.3 (recommends this exact
slice as the first fully-connected path).

## Global Constraints

- Supabase project: `itxubrkbropttfdackmi` (`https://itxubrkbropttfdackmi.supabase.co`).
  This is the live production database — read-only queries only in this plan, no writes,
  no schema migrations.
- Publishable key: `sb_publishable_bsIF_bY19uFCno5BjS4sMQ_PiEbY6zs`.
- No auth in this slice — every query must work against the `tournaments_public_read`,
  `matches_public_read`, `games_public_read`, `profiles_public_read`, and
  `squads_public_read` RLS policies (all `USING (true)`, confirmed live against the project
  on 2026-09-18 via `pg_policies`), using the anon/publishable client with no signed-in
  session.
- No state-management package (Provider/Riverpod/Bloc/etc.) — confirmed against
  `CLAUDE.md`. Use constructor-injected repositories + `StatefulWidget`/`FutureBuilder`.
- Do not touch auth, registration, wallet, or any other Phase 1 screen — stop once this
  slice runs end-to-end against live data.

## Verified schema (read directly from the live project, 2026-09-18)

`tournaments` (all columns used below confirmed to exist, with these exact names/types):
`id uuid`, `title text`, `slug text`, `description text?`, `banner_url text?`,
`card_image_url text?`, `status text` (seen live: `active`, `completed`, `cancelled`; also
`draft` per default — excluded from the list query), `format text` (seen: `group_knockout`),
`competition_format text`, `entry_unit text` (`solo` | `squad`), `prize_pool int`,
`prize_second int?`, `prize_third int?`, `registration_fee int`, `max_players int?`,
`registration_start timestamptz?`, `registration_end timestamptz?`,
`tournament_start timestamptz?`, `tournament_end timestamptz?`, `rules text?`,
`game_id uuid` (FK → `games.id`, single unambiguous FK, no embed hint needed).

`matches`: `id uuid`, `tournament_id uuid` (FK → `tournaments.id`), `round text` (seen
live: `group`, `round_of_16`, `quarter_final`, `semi_final`, `third_place`, `final`),
`player_a_id uuid?` (FK `matches_player_a_id_fkey` → `profiles.id`), `player_b_id uuid?`
(FK `matches_player_b_id_fkey` → `profiles.id`), `team_a_id uuid?` (FK
`matches_team_a_id_fkey` → `squads.id`), `team_b_id uuid?` (FK `matches_team_b_id_fkey` →
`squads.id`), `score_a int?`, `score_b int?`, `status text` (seen live: `completed`,
`disputed`, `bye`; schema also allows others such as `scheduled`), `scheduled_at
timestamptz?`, `completed_at timestamptz?`.

`games`: `id uuid`, `name text`. `profiles`: `id uuid`, `username text?`,
`display_name text?`. `squads`: `id uuid`, `name text`.

Because `matches` has two FKs each to `profiles` and `squads`, PostgREST embeds must use
the exact constraint name to disambiguate (confirmed via `pg_constraint`):
`matches_player_a_id_fkey`, `matches_player_b_id_fkey`, `matches_team_a_id_fkey`,
`matches_team_b_id_fkey`.

**Design decision (not from spec, made here):** the tournament list query excludes
`status = 'draft'` client-side. RLS permits reading drafts (`USING (true)`), but an
unpublished draft tournament is not meant to be public-facing content — this mirrors how a
product surface should behave even though the database would allow it.

---

### Task 1: Scaffold the Flutter project, dependencies, and Supabase bootstrap

**Files:**
- Create: entire Flutter project skeleton via `flutter create .` (`pubspec.yaml`,
  `lib/main.dart`, `android/`, `windows/`, `web/`, `ios/`, `macos/`, `linux/`, `test/`)
- Modify: `lib/main.dart`
- Create: `lib/core/env.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Produces: `SupabaseEnv.url` (`String`), `SupabaseEnv.publishableKey` (`String`) — read by
  Task 2's `SupabaseTournamentsRepository` construction site in `main.dart`.
- Produces: a running `SentinelXApp` widget booted from `main()` after
  `Supabase.initialize(...)` completes — every later screen assumes Supabase is already
  initialized by the time it runs.

- [ ] **Step 1: Create the Flutter project in place**

Run (from `C:\Users\gorok\sentinelx_mobile`):

```bash
flutter create . --project-name sentinelx_mobile --description "Sentinel X mobile app"
```

This is safe to run in a non-empty directory — `flutter create` only adds the files it
generates and does not touch `CLAUDE.md` or `docs/`.

- [ ] **Step 2: Add dependencies**

```bash
flutter pub add supabase_flutter go_router
flutter pub get
```

- [ ] **Step 3: Confirm the installed `Supabase.initialize` signature**

Package APIs drift between versions — verify the exact parameter name before writing code
against it, rather than assuming:

```bash
grep -n "static Future<Supabase> initialize" "$(find ~/AppData/Local/Pub/Cache/hosted -maxdepth 2 -iname 'supabase_flutter-*' -type d | sort -V | tail -1)/lib/src/supabase_manager.dart"
```

(If the path differs on this machine, `flutter pub deps` or the `.dart_tool/package_config.json`
entry for `supabase_flutter` gives the resolved package location.) Confirm the parameter
used to pass the API key is named `anonKey` — as of current `supabase_flutter` releases it
accepts both legacy anon JWTs and the new `sb_publishable_...` key format under that same
parameter name. Adjust Step 5 below if the installed version differs.

- [ ] **Step 4: Write the Supabase environment constants**

`lib/core/env.dart`:

```dart
class SupabaseEnv {
  const SupabaseEnv._();

  static const url = 'https://itxubrkbropttfdackmi.supabase.co';
  static const publishableKey = 'sb_publishable_bsIF_bY19uFCno5BjS4sMQ_PiEbY6zs';
}
```

- [ ] **Step 5: Wire Supabase bootstrap into `main.dart`**

Replace the generated `lib/main.dart` entirely with:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseEnv.url,
    anonKey: SupabaseEnv.publishableKey,
  );
  runApp(const SentinelXApp());
}

class SentinelXApp extends StatelessWidget {
  const SentinelXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentinel X',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('Sentinel X')),
      ),
    );
  }
}
```

This is a deliberately minimal placeholder `home` — Task 7 replaces
`MaterialApp(home: ...)` with `MaterialApp.router(routerConfig: buildAppRouter())` once the
real screens exist.

- [ ] **Step 6: Replace the generated smoke test**

`flutter create` generates `test/widget_test.dart` referencing a counter app that no longer
exists. Replace its contents with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/main.dart';

void main() {
  testWidgets('SentinelXApp boots and shows the placeholder home', (tester) async {
    await tester.pumpWidget(const SentinelXApp());

    expect(find.text('Sentinel X'), findsOneWidget);
  });
}
```

- [ ] **Step 7: Run the test and confirm it passes**

```bash
flutter test test/widget_test.dart
```

Expected: 1 test, PASS. This does not require network access — it pumps `SentinelXApp`
directly without calling `Supabase.initialize` a second time, since app construction and
Supabase bootstrap are separate steps in `main()`.

- [ ] **Step 8: Commit**

```bash
git init
git add -A
git commit -m "chore: scaffold Flutter project with Supabase bootstrap"
```

(This is the first commit — `flutter create` does not initialize git on its own here since
the directory wasn't already a repo.)

---

### Task 2: Tournament model + repository (list + detail)

**Files:**
- Create: `lib/models/tournament.dart`
- Create: `lib/data/tournaments_repository.dart`
- Create: `lib/data/supabase_tournaments_repository.dart`
- Test: `test/models/tournament_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1 directly (models are pure Dart).
- Produces: `Tournament` class with `fromJson(Map<String, dynamic>)` factory and fields
  listed in Step 1 — consumed by Task 3 (list screen), Task 4 (detail screen), and Task 7
  (router). Produces `abstract class TournamentsRepository` with
  `Future<List<Tournament>> fetchTournaments()` and
  `Future<Tournament> fetchTournament(String id)` — consumed by every later task.
  `SupabaseTournamentsRepository` will gain a third method, `fetchBracket`, in Task 5 (the
  same class, extended in place — not a new class).

- [ ] **Step 1: Write the failing model test**

`test/models/tournament_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/models/tournament.dart';

void main() {
  group('Tournament.fromJson', () {
    test('parses a fully populated row with an embedded game name', () {
      final json = {
        'id': '88a63aee-bd27-4fa7-b517-469df2ca8adf',
        'title': 'FC Mobile Premier League — Season 2',
        'slug': 'fc-mobile-premier-league-season-2',
        'description': 'The second season of the FC Mobile Premier League.',
        'banner_url': 'https://example.com/banner.png',
        'card_image_url': 'https://example.com/card.png',
        'status': 'active',
        'format': 'group_knockout',
        'competition_format': 'head_to_head',
        'entry_unit': 'solo',
        'prize_pool': 50000,
        'prize_second': 20000,
        'prize_third': 10000,
        'registration_fee': 500,
        'max_players': 32,
        'registration_start': '2026-09-01T00:00:00+00:00',
        'registration_end': '2026-09-10T00:00:00+00:00',
        'tournament_start': '2026-09-11T00:00:00+00:00',
        'tournament_end': null,
        'rules': 'Standard rules apply.',
        'games': {'name': 'EA FC Mobile'},
      };

      final tournament = Tournament.fromJson(json);

      expect(tournament.id, '88a63aee-bd27-4fa7-b517-469df2ca8adf');
      expect(tournament.title, 'FC Mobile Premier League — Season 2');
      expect(tournament.status, 'active');
      expect(tournament.entryUnit, 'solo');
      expect(tournament.prizePool, 50000);
      expect(tournament.maxPlayers, 32);
      expect(tournament.tournamentStart, DateTime.parse('2026-09-11T00:00:00+00:00'));
      expect(tournament.tournamentEnd, isNull);
      expect(tournament.gameName, 'EA FC Mobile');
    });

    test('falls back to "Unknown game" when the games embed is missing', () {
      final json = {
        'id': 'e04f3194-75f2-4c03-92c9-eadffcdd5c00',
        'title': 'DRY RUN — Clash Squad 2v2',
        'slug': 'dry-run-clash-squad-2v2-team-test',
        'description': null,
        'banner_url': null,
        'card_image_url': null,
        'status': 'completed',
        'format': 'group_knockout',
        'competition_format': 'head_to_head',
        'entry_unit': 'squad',
        'prize_pool': 0,
        'prize_second': null,
        'prize_third': null,
        'registration_fee': 500,
        'max_players': null,
        'registration_start': null,
        'registration_end': null,
        'tournament_start': null,
        'tournament_end': null,
        'rules': null,
        'games': null,
      };

      final tournament = Tournament.fromJson(json);

      expect(tournament.gameName, 'Unknown game');
      expect(tournament.tournamentStart, isNull);
    });
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
flutter test test/models/tournament_test.dart
```

Expected: FAIL — `Error: Couldn't resolve the package 'sentinelx_mobile'` or
`Target of URI doesn't exist: 'package:sentinelx_mobile/models/tournament.dart'`, since
`lib/models/tournament.dart` doesn't exist yet.

- [ ] **Step 3: Write the `Tournament` model**

`lib/models/tournament.dart`:

```dart
class Tournament {
  const Tournament({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.bannerUrl,
    required this.cardImageUrl,
    required this.status,
    required this.format,
    required this.competitionFormat,
    required this.entryUnit,
    required this.prizePool,
    required this.prizeSecond,
    required this.prizeThird,
    required this.registrationFee,
    required this.maxPlayers,
    required this.registrationStart,
    required this.registrationEnd,
    required this.tournamentStart,
    required this.tournamentEnd,
    required this.rules,
    required this.gameName,
  });

  final String id;
  final String title;
  final String slug;
  final String? description;
  final String? bannerUrl;
  final String? cardImageUrl;
  final String status;
  final String format;
  final String competitionFormat;
  final String entryUnit;
  final int prizePool;
  final int? prizeSecond;
  final int? prizeThird;
  final int registrationFee;
  final int? maxPlayers;
  final DateTime? registrationStart;
  final DateTime? registrationEnd;
  final DateTime? tournamentStart;
  final DateTime? tournamentEnd;
  final String? rules;
  final String gameName;

  factory Tournament.fromJson(Map<String, dynamic> json) {
    final gameJson = json['games'] as Map<String, dynamic>?;
    return Tournament(
      id: json['id'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      bannerUrl: json['banner_url'] as String?,
      cardImageUrl: json['card_image_url'] as String?,
      status: json['status'] as String,
      format: json['format'] as String,
      competitionFormat: json['competition_format'] as String,
      entryUnit: json['entry_unit'] as String,
      prizePool: json['prize_pool'] as int,
      prizeSecond: json['prize_second'] as int?,
      prizeThird: json['prize_third'] as int?,
      registrationFee: json['registration_fee'] as int,
      maxPlayers: json['max_players'] as int?,
      registrationStart: _parseDate(json['registration_start']),
      registrationEnd: _parseDate(json['registration_end']),
      tournamentStart: _parseDate(json['tournament_start']),
      tournamentEnd: _parseDate(json['tournament_end']),
      rules: json['rules'] as String?,
      gameName: gameJson?['name'] as String? ?? 'Unknown game',
    );
  }

  static DateTime? _parseDate(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);
}
```

- [ ] **Step 4: Run the test and verify it passes**

```bash
flutter test test/models/tournament_test.dart
```

Expected: 2 tests, PASS.

- [ ] **Step 5: Write the repository interface**

`lib/data/tournaments_repository.dart`:

```dart
import '../models/tournament.dart';

abstract class TournamentsRepository {
  Future<List<Tournament>> fetchTournaments();
  Future<Tournament> fetchTournament(String id);
}
```

- [ ] **Step 6: Write the Supabase-backed implementation**

`lib/data/supabase_tournaments_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tournament.dart';
import 'tournaments_repository.dart';

class SupabaseTournamentsRepository implements TournamentsRepository {
  SupabaseTournamentsRepository(this._client);

  final SupabaseClient _client;

  static const _tournamentColumns = '''
    id, title, slug, description, banner_url, card_image_url, status, format,
    competition_format, entry_unit, prize_pool, prize_second, prize_third,
    registration_fee, max_players, registration_start, registration_end,
    tournament_start, tournament_end, rules, games(name)
  ''';

  @override
  Future<List<Tournament>> fetchTournaments() async {
    final rows = await _client
        .from('tournaments')
        .select(_tournamentColumns)
        .neq('status', 'draft')
        .order('created_at', ascending: false);
    return rows.map((row) => Tournament.fromJson(row)).toList();
  }

  @override
  Future<Tournament> fetchTournament(String id) async {
    final row = await _client
        .from('tournaments')
        .select(_tournamentColumns)
        .eq('id', id)
        .single();
    return Tournament.fromJson(row);
  }
}
```

Note: this class is extended in place in Task 5 (a `fetchBracket` method is added to the
same file) — it is not split or renamed.

- [ ] **Step 7: Run the full test suite and confirm nothing broke**

```bash
flutter test
```

Expected: all tests PASS (Task 1's smoke test + Task 2's model tests).

- [ ] **Step 8: Commit**

```bash
git add lib/models/tournament.dart lib/data/tournaments_repository.dart lib/data/supabase_tournaments_repository.dart test/models/tournament_test.dart
git commit -m "feat: add Tournament model and Supabase-backed repository"
```

---

### Task 3: Tournament List screen

**Files:**
- Create: `lib/features/tournaments/tournament_list_screen.dart`
- Create: `test/fakes/fake_tournaments_repository.dart`
- Test: `test/features/tournament_list_screen_test.dart`

**Interfaces:**
- Consumes: `Tournament` (Task 2), `TournamentsRepository` (Task 2).
- Produces: `TournamentListScreen({required TournamentsRepository repository})` — a
  `StatefulWidget`. Each list row is keyed `Key('tournament-tile-${tournament.id}')` and
  calling `onTap` invokes a `void Function(Tournament) onTournamentTap` callback passed in
  via the constructor — the router (Task 7) supplies the navigation callback, the screen
  itself does not import `go_router`, keeping it independently testable.
- Produces: `FakeTournamentsRepository` (in `test/fakes/`, not `lib/` — it's test-only)
  implementing `TournamentsRepository` with constructor-configurable canned responses.
  Reused by Task 4, Task 6, and Task 7's tests.

- [ ] **Step 1: Write the fake repository (test support, not a test itself)**

`test/fakes/fake_tournaments_repository.dart`:

```dart
import 'package:sentinelx_mobile/data/tournaments_repository.dart';
import 'package:sentinelx_mobile/models/bracket_match.dart';
import 'package:sentinelx_mobile/models/tournament.dart';

class FakeTournamentsRepository implements TournamentsRepository {
  FakeTournamentsRepository({
    this.tournaments = const [],
    this.tournamentById,
    this.matchesByTournament = const {},
    this.tournamentsError,
    this.tournamentError,
    this.bracketError,
  });

  final List<Tournament> tournaments;
  final Tournament? tournamentById;
  final Map<String, List<BracketMatch>> matchesByTournament;
  final Object? tournamentsError;
  final Object? tournamentError;
  final Object? bracketError;

  @override
  Future<List<Tournament>> fetchTournaments() async {
    if (tournamentsError != null) throw tournamentsError!;
    return tournaments;
  }

  @override
  Future<Tournament> fetchTournament(String id) async {
    if (tournamentError != null) throw tournamentError!;
    final tournament = tournamentById;
    if (tournament == null) {
      throw StateError('FakeTournamentsRepository: no tournament configured for id $id');
    }
    return tournament;
  }

  @override
  Future<List<BracketMatch>> fetchBracket(String tournamentId) async {
    if (bracketError != null) throw bracketError!;
    return matchesByTournament[tournamentId] ?? const [];
  }
}
```

This references `BracketMatch` and a `fetchBracket` method that don't exist until Task 5 —
that's expected and addressed in Step 2.

- [ ] **Step 2: Add a placeholder `BracketMatch` and extend the repository interface**

`fetchBracket` is declared on `TournamentsRepository` now (Task 3) even though it is fully
built out in Task 5, because `FakeTournamentsRepository` must implement the complete
interface to compile. Update `lib/data/tournaments_repository.dart`:

```dart
import '../models/bracket_match.dart';
import '../models/tournament.dart';

abstract class TournamentsRepository {
  Future<List<Tournament>> fetchTournaments();
  Future<Tournament> fetchTournament(String id);
  Future<List<BracketMatch>> fetchBracket(String tournamentId);
}
```

Create the minimal `lib/models/bracket_match.dart` needed to compile (Task 5 replaces this
file's contents with the full model — this is a real, if minimal, starting definition, not
a stub to be deleted):

```dart
class BracketMatch {
  const BracketMatch({
    required this.id,
    required this.tournamentId,
    required this.round,
  });

  final String id;
  final String tournamentId;
  final String round;
}
```

Add the matching method to `lib/data/supabase_tournaments_repository.dart` (appended to the
existing class from Task 2, not a new file):

```dart
  @override
  Future<List<BracketMatch>> fetchBracket(String tournamentId) async {
    final rows = await _client
        .from('matches')
        .select('id, tournament_id, round')
        .eq('tournament_id', tournamentId);
    return rows
        .map((row) => BracketMatch(
              id: row['id'] as String,
              tournamentId: row['tournament_id'] as String,
              round: row['round'] as String,
            ))
        .toList();
  }
```

(add the `import '../models/bracket_match.dart';` line alongside the existing imports).

- [ ] **Step 3: Run the full suite to confirm this compiles and nothing broke**

```bash
flutter test
```

Expected: all existing tests still PASS (no new tests yet — this step only proves the
interface change compiles cleanly).

- [ ] **Step 4: Write the failing list screen test**

`test/features/tournament_list_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/tournaments/tournament_list_screen.dart';
import 'package:sentinelx_mobile/models/tournament.dart';

import '../fakes/fake_tournaments_repository.dart';

Tournament _tournament({required String id, required String title, required String status}) {
  return Tournament(
    id: id,
    title: title,
    slug: title.toLowerCase().replaceAll(' ', '-'),
    description: null,
    bannerUrl: null,
    cardImageUrl: null,
    status: status,
    format: 'group_knockout',
    competitionFormat: 'head_to_head',
    entryUnit: 'solo',
    prizePool: 10000,
    prizeSecond: null,
    prizeThird: null,
    registrationFee: 500,
    maxPlayers: 16,
    registrationStart: null,
    registrationEnd: null,
    tournamentStart: null,
    tournamentEnd: null,
    rules: null,
    gameName: 'EA FC Mobile',
  );
}

void main() {
  testWidgets('shows a loading indicator, then the fetched tournaments', (tester) async {
    final repository = FakeTournamentsRepository(tournaments: [
      _tournament(id: 't1', title: 'FC Mobile Premier League', status: 'active'),
      _tournament(id: 't2', title: 'DLS Community Cup III', status: 'completed'),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: TournamentListScreen(
        repository: repository,
        onTournamentTap: (_) {},
      ),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('FC Mobile Premier League'), findsOneWidget);
    expect(find.text('DLS Community Cup III'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no tournaments', (tester) async {
    final repository = FakeTournamentsRepository(tournaments: const []);

    await tester.pumpWidget(MaterialApp(
      home: TournamentListScreen(repository: repository, onTournamentTap: (_) {}),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No tournaments yet.'), findsOneWidget);
  });

  testWidgets('shows an error message when the fetch fails', (tester) async {
    final repository = FakeTournamentsRepository(tournamentsError: Exception('network down'));

    await tester.pumpWidget(MaterialApp(
      home: TournamentListScreen(repository: repository, onTournamentTap: (_) {}),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load tournaments'), findsOneWidget);
  });

  testWidgets('tapping a tournament invokes onTournamentTap with that tournament', (tester) async {
    final tournament = _tournament(id: 't1', title: 'FC Mobile Premier League', status: 'active');
    final repository = FakeTournamentsRepository(tournaments: [tournament]);
    Tournament? tapped;

    await tester.pumpWidget(MaterialApp(
      home: TournamentListScreen(
        repository: repository,
        onTournamentTap: (t) => tapped = t,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tournament-tile-t1')));
    await tester.pump();

    expect(tapped, tournament);
  });
}
```

- [ ] **Step 5: Run the test and verify it fails**

```bash
flutter test test/features/tournament_list_screen_test.dart
```

Expected: FAIL — `tournament_list_screen.dart` doesn't exist yet.

- [ ] **Step 6: Write the list screen**

`lib/features/tournaments/tournament_list_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../data/tournaments_repository.dart';
import '../../models/tournament.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({
    super.key,
    required this.repository,
    required this.onTournamentTap,
  });

  final TournamentsRepository repository;
  final void Function(Tournament tournament) onTournamentTap;

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  late final Future<List<Tournament>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchTournaments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      body: FutureBuilder<List<Tournament>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load tournaments: ${snapshot.error}'));
          }
          final tournaments = snapshot.data!;
          if (tournaments.isEmpty) {
            return const Center(child: Text('No tournaments yet.'));
          }
          return ListView.builder(
            itemCount: tournaments.length,
            itemBuilder: (context, index) {
              final tournament = tournaments[index];
              return ListTile(
                key: Key('tournament-tile-${tournament.id}'),
                title: Text(tournament.title),
                subtitle: Text('${tournament.gameName} • ${tournament.status}'),
                onTap: () => widget.onTournamentTap(tournament),
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 7: Run the test and verify it passes**

```bash
flutter test test/features/tournament_list_screen_test.dart
```

Expected: 4 tests, PASS.

- [ ] **Step 8: Run the full suite and commit**

```bash
flutter test
git add lib/data/tournaments_repository.dart lib/data/supabase_tournaments_repository.dart lib/models/bracket_match.dart lib/features/tournaments/tournament_list_screen.dart test/fakes/fake_tournaments_repository.dart test/features/tournament_list_screen_test.dart
git commit -m "feat: add tournament list screen"
```

---

### Task 4: Tournament Detail screen

**Files:**
- Create: `lib/features/tournaments/tournament_detail_screen.dart`
- Test: `test/features/tournament_detail_screen_test.dart`

**Interfaces:**
- Consumes: `Tournament`, `TournamentsRepository` (Task 2), `FakeTournamentsRepository`
  (Task 3).
- Produces: `TournamentDetailScreen({required TournamentsRepository repository, required
  String tournamentId, required VoidCallback onViewBracket})`. The "View Bracket" button is
  keyed `Key('view-bracket-button')`.

- [ ] **Step 1: Write the failing detail screen test**

`test/features/tournament_detail_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/tournaments/tournament_detail_screen.dart';
import 'package:sentinelx_mobile/models/tournament.dart';

import '../fakes/fake_tournaments_repository.dart';

Tournament _detailTournament() {
  return Tournament(
    id: 't1',
    title: 'FC Mobile Premier League — Season 2',
    slug: 'fc-mobile-premier-league-season-2',
    description: 'The second season of the FC Mobile Premier League.',
    bannerUrl: null,
    cardImageUrl: null,
    status: 'active',
    format: 'group_knockout',
    competitionFormat: 'head_to_head',
    entryUnit: 'solo',
    prizePool: 50000,
    prizeSecond: 20000,
    prizeThird: 10000,
    registrationFee: 500,
    maxPlayers: 32,
    registrationStart: null,
    registrationEnd: null,
    tournamentStart: DateTime.parse('2026-09-11T00:00:00+00:00'),
    tournamentEnd: null,
    rules: 'Standard rules apply.',
    gameName: 'EA FC Mobile',
  );
}

void main() {
  testWidgets('shows tournament details once loaded', (tester) async {
    final repository = FakeTournamentsRepository(tournamentById: _detailTournament());

    await tester.pumpWidget(MaterialApp(
      home: TournamentDetailScreen(
        repository: repository,
        tournamentId: 't1',
        onViewBracket: () {},
      ),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('FC Mobile Premier League — Season 2'), findsOneWidget);
    expect(find.textContaining('EA FC Mobile'), findsOneWidget);
    expect(find.textContaining('50000'), findsOneWidget);
  });

  testWidgets('shows an error message when the fetch fails', (tester) async {
    final repository = FakeTournamentsRepository(tournamentError: Exception('not found'));

    await tester.pumpWidget(MaterialApp(
      home: TournamentDetailScreen(
        repository: repository,
        tournamentId: 'missing',
        onViewBracket: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load tournament'), findsOneWidget);
  });

  testWidgets('tapping View Bracket invokes onViewBracket', (tester) async {
    final repository = FakeTournamentsRepository(tournamentById: _detailTournament());
    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      home: TournamentDetailScreen(
        repository: repository,
        tournamentId: 't1',
        onViewBracket: () => tapped = true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('view-bracket-button')));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
flutter test test/features/tournament_detail_screen_test.dart
```

Expected: FAIL — `tournament_detail_screen.dart` doesn't exist yet.

- [ ] **Step 3: Write the detail screen**

`lib/features/tournaments/tournament_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../data/tournaments_repository.dart';
import '../../models/tournament.dart';

class TournamentDetailScreen extends StatefulWidget {
  const TournamentDetailScreen({
    super.key,
    required this.repository,
    required this.tournamentId,
    required this.onViewBracket,
  });

  final TournamentsRepository repository;
  final String tournamentId;
  final VoidCallback onViewBracket;

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  late final Future<Tournament> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchTournament(widget.tournamentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournament')),
      body: FutureBuilder<Tournament>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load tournament: ${snapshot.error}'));
          }
          final tournament = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tournament.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('${tournament.gameName} • ${tournament.status}'),
                const SizedBox(height: 16),
                Text('Prize pool: ${tournament.prizePool}'),
                if (tournament.prizeSecond != null)
                  Text('2nd place: ${tournament.prizeSecond}'),
                if (tournament.prizeThird != null)
                  Text('3rd place: ${tournament.prizeThird}'),
                const SizedBox(height: 8),
                Text('Registration fee: ${tournament.registrationFee}'),
                if (tournament.maxPlayers != null)
                  Text('Max players: ${tournament.maxPlayers}'),
                if (tournament.description != null) ...[
                  const SizedBox(height: 16),
                  Text(tournament.description!),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  key: const Key('view-bracket-button'),
                  onPressed: widget.onViewBracket,
                  child: const Text('View Bracket'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test and verify it passes**

```bash
flutter test test/features/tournament_detail_screen_test.dart
```

Expected: 3 tests, PASS.

- [ ] **Step 5: Run the full suite and commit**

```bash
flutter test
git add lib/features/tournaments/tournament_detail_screen.dart test/features/tournament_detail_screen_test.dart
git commit -m "feat: add tournament detail screen"
```

---

### Task 5: Full `BracketMatch` model + `fetchBracket` implementation

**Files:**
- Modify: `lib/models/bracket_match.dart` (replaces Task 3's minimal placeholder)
- Modify: `lib/data/supabase_tournaments_repository.dart` (replaces Task 3's minimal
  `fetchBracket` body)
- Test: `test/models/bracket_match_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `BracketMatch` with fields `id`, `tournamentId`, `round`, `status`, `scoreA`,
  `scoreB`, `scheduledAt`, `completedAt`, `participantALabel`, `participantBLabel` (both
  `String`, pre-resolved display names — the bracket screen never inspects raw
  player/team ids). Produces `const List<String> kBracketRoundOrder` and
  `int roundSortIndex(String round)` and `String roundDisplayName(String round)` — consumed
  by Task 6's `BracketScreen`.

- [ ] **Step 1: Write the failing model test**

`test/models/bracket_match_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/models/bracket_match.dart';

void main() {
  group('BracketMatch.fromJson', () {
    test('prefers display_name over username for a solo match', () {
      final json = {
        'id': 'm1',
        'tournament_id': 't1',
        'round': 'final',
        'status': 'completed',
        'score_a': 3,
        'score_b': 1,
        'scheduled_at': '2026-09-20T18:00:00+00:00',
        'completed_at': '2026-09-20T19:00:00+00:00',
        'player_a': {'username': 'shadow_striker', 'display_name': 'Shadow Striker'},
        'player_b': {'username': 'goal_machine', 'display_name': null},
        'team_a': null,
        'team_b': null,
      };

      final match = BracketMatch.fromJson(json);

      expect(match.participantALabel, 'Shadow Striker');
      expect(match.participantBLabel, 'goal_machine');
      expect(match.scoreA, 3);
      expect(match.scoreB, 1);
      expect(match.status, 'completed');
    });

    test('uses squad name for a team match, ignoring player fields', () {
      final json = {
        'id': 'm2',
        'tournament_id': 't1',
        'round': 'group',
        'status': 'scheduled',
        'score_a': null,
        'score_b': null,
        'scheduled_at': null,
        'completed_at': null,
        'player_a': null,
        'player_b': null,
        'team_a': {'name': 'Phoenix Squad'},
        'team_b': {'name': 'Night Owls'},
      };

      final match = BracketMatch.fromJson(json);

      expect(match.participantALabel, 'Phoenix Squad');
      expect(match.participantBLabel, 'Night Owls');
    });

    test('falls back to TBD when neither player nor team is assigned yet', () {
      final json = {
        'id': 'm3',
        'tournament_id': 't1',
        'round': 'quarter_final',
        'status': 'scheduled',
        'score_a': null,
        'score_b': null,
        'scheduled_at': null,
        'completed_at': null,
        'player_a': null,
        'player_b': null,
        'team_a': null,
        'team_b': null,
      };

      final match = BracketMatch.fromJson(json);

      expect(match.participantALabel, 'TBD');
      expect(match.participantBLabel, 'TBD');
    });
  });

  group('round ordering and display', () {
    test('sorts bracket rounds from group stage to final', () {
      final rounds = ['final', 'group', 'semi_final', 'quarter_final', 'round_of_16', 'third_place'];
      rounds.sort((a, b) => roundSortIndex(a).compareTo(roundSortIndex(b)));

      expect(rounds, [
        'group',
        'round_of_16',
        'quarter_final',
        'semi_final',
        'third_place',
        'final',
      ]);
    });

    test('unknown rounds sort after all known rounds', () {
      expect(roundSortIndex('mystery_round'), greaterThan(roundSortIndex('final')));
    });

    test('produces human-readable round names', () {
      expect(roundDisplayName('group'), 'Group Stage');
      expect(roundDisplayName('round_of_16'), 'Round of 16');
      expect(roundDisplayName('quarter_final'), 'Quarterfinal');
      expect(roundDisplayName('semi_final'), 'Semifinal');
      expect(roundDisplayName('third_place'), 'Third Place');
      expect(roundDisplayName('final'), 'Final');
      expect(roundDisplayName('mystery_round'), 'Mystery Round');
    });
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
flutter test test/models/bracket_match_test.dart
```

Expected: FAIL — `BracketMatch` doesn't have `status`, `scoreA`, `participantALabel`, etc.
yet (Task 3 only created a 3-field placeholder), and `roundSortIndex`/`roundDisplayName`
don't exist.

- [ ] **Step 3: Replace the placeholder `BracketMatch` with the full model**

`lib/models/bracket_match.dart` (full replacement of Task 3's placeholder):

```dart
const List<String> kBracketRoundOrder = [
  'group',
  'round_of_16',
  'quarter_final',
  'semi_final',
  'third_place',
  'final',
];

int roundSortIndex(String round) {
  final index = kBracketRoundOrder.indexOf(round);
  return index == -1 ? kBracketRoundOrder.length : index;
}

String roundDisplayName(String round) {
  const knownNames = {
    'group': 'Group Stage',
    'round_of_16': 'Round of 16',
    'quarter_final': 'Quarterfinal',
    'semi_final': 'Semifinal',
    'third_place': 'Third Place',
    'final': 'Final',
  };
  return knownNames[round] ?? _titleCase(round.replaceAll('_', ' '));
}

String _titleCase(String value) {
  return value
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

class BracketMatch {
  const BracketMatch({
    required this.id,
    required this.tournamentId,
    required this.round,
    required this.status,
    required this.scoreA,
    required this.scoreB,
    required this.scheduledAt,
    required this.completedAt,
    required this.participantALabel,
    required this.participantBLabel,
  });

  final String id;
  final String tournamentId;
  final String round;
  final String status;
  final int? scoreA;
  final int? scoreB;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final String participantALabel;
  final String participantBLabel;

  factory BracketMatch.fromJson(Map<String, dynamic> json) {
    final playerA = json['player_a'] as Map<String, dynamic>?;
    final playerB = json['player_b'] as Map<String, dynamic>?;
    final teamA = json['team_a'] as Map<String, dynamic>?;
    final teamB = json['team_b'] as Map<String, dynamic>?;

    return BracketMatch(
      id: json['id'] as String,
      tournamentId: json['tournament_id'] as String,
      round: json['round'] as String,
      status: json['status'] as String,
      scoreA: json['score_a'] as int?,
      scoreB: json['score_b'] as int?,
      scheduledAt: _parseDate(json['scheduled_at']),
      completedAt: _parseDate(json['completed_at']),
      participantALabel: _participantLabel(playerA, teamA),
      participantBLabel: _participantLabel(playerB, teamB),
    );
  }

  static String _participantLabel(
    Map<String, dynamic>? player,
    Map<String, dynamic>? team,
  ) {
    if (team != null) return team['name'] as String? ?? 'TBD';
    if (player != null) {
      return (player['display_name'] as String?) ??
          (player['username'] as String?) ??
          'TBD';
    }
    return 'TBD';
  }

  static DateTime? _parseDate(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);
}
```

- [ ] **Step 4: Run the model test and verify it passes**

```bash
flutter test test/models/bracket_match_test.dart
```

Expected: 6 tests, PASS.

- [ ] **Step 5: Replace the placeholder `fetchBracket` with the real query**

In `lib/data/supabase_tournaments_repository.dart`, replace the `fetchBracket` method body
written in Task 3 with:

```dart
  static const _matchColumns = '''
    id, tournament_id, round, status, score_a, score_b, scheduled_at, completed_at,
    player_a:profiles!matches_player_a_id_fkey(username, display_name),
    player_b:profiles!matches_player_b_id_fkey(username, display_name),
    team_a:squads!matches_team_a_id_fkey(name),
    team_b:squads!matches_team_b_id_fkey(name)
  ''';

  @override
  Future<List<BracketMatch>> fetchBracket(String tournamentId) async {
    final rows = await _client
        .from('matches')
        .select(_matchColumns)
        .eq('tournament_id', tournamentId);
    final matches = rows.map((row) => BracketMatch.fromJson(row)).toList();
    matches.sort((a, b) => roundSortIndex(a.round).compareTo(roundSortIndex(b.round)));
    return matches;
  }
```

Place `_matchColumns` as a second static field alongside `_tournamentColumns` (both defined
near the top of the class, next to each other).

- [ ] **Step 6: Run the full suite and confirm nothing broke**

```bash
flutter test
```

Expected: all tests PASS — this step touches no test files, only production code the
existing tests exercise indirectly via compilation.

- [ ] **Step 7: Commit**

```bash
git add lib/models/bracket_match.dart lib/data/supabase_tournaments_repository.dart test/models/bracket_match_test.dart
git commit -m "feat: implement full BracketMatch model and fetchBracket query"
```

---

### Task 6: Bracket screen

**Files:**
- Create: `lib/features/tournaments/bracket_screen.dart`
- Test: `test/features/bracket_screen_test.dart`

**Interfaces:**
- Consumes: `BracketMatch`, `roundDisplayName`, `TournamentsRepository` (Task 5),
  `FakeTournamentsRepository` (Task 3).
- Produces: `BracketScreen({required TournamentsRepository repository, required String
  tournamentId})`.

- [ ] **Step 1: Write the failing bracket screen test**

`test/features/bracket_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/tournaments/bracket_screen.dart';
import 'package:sentinelx_mobile/models/bracket_match.dart';

import '../fakes/fake_tournaments_repository.dart';

BracketMatch _match({
  required String id,
  required String round,
  String a = 'Player A',
  String b = 'Player B',
  int? scoreA,
  int? scoreB,
}) {
  return BracketMatch(
    id: id,
    tournamentId: 't1',
    round: round,
    status: scoreA == null ? 'scheduled' : 'completed',
    scoreA: scoreA,
    scoreB: scoreB,
    scheduledAt: null,
    completedAt: null,
    participantALabel: a,
    participantBLabel: b,
  );
}

void main() {
  testWidgets('groups matches under round headers, in bracket order', (tester) async {
    final repository = FakeTournamentsRepository(matchesByTournament: {
      't1': [
        _match(id: 'm1', round: 'final', a: 'Shadow Striker', b: 'Goal Machine', scoreA: 3, scoreB: 1),
        _match(id: 'm2', round: 'group', a: 'Team Alpha', b: 'Team Beta', scoreA: 2, scoreB: 2),
        _match(id: 'm3', round: 'semi_final', a: 'Shadow Striker', b: 'Iron Wall', scoreA: 4, scoreB: 0),
      ],
    });

    await tester.pumpWidget(MaterialApp(
      home: BracketScreen(repository: repository, tournamentId: 't1'),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Group Stage'), findsOneWidget);
    expect(find.text('Semifinal'), findsOneWidget);
    expect(find.text('Final'), findsOneWidget);
    expect(find.text('Shadow Striker'), findsNWidgets(2));
    expect(find.text('3 - 1'), findsOneWidget);

    final groupHeaderCenter = tester.getCenter(find.text('Group Stage'));
    final finalHeaderCenter = tester.getCenter(find.text('Final'));
    expect(groupHeaderCenter.dx, lessThan(finalHeaderCenter.dx));
  });

  testWidgets('shows TBD participants without a score for unscheduled matches', (tester) async {
    final repository = FakeTournamentsRepository(matchesByTournament: {
      't1': [
        BracketMatch(
          id: 'm1',
          tournamentId: 't1',
          round: 'quarter_final',
          status: 'scheduled',
          scoreA: null,
          scoreB: null,
          scheduledAt: null,
          completedAt: null,
          participantALabel: 'TBD',
          participantBLabel: 'TBD',
        ),
      ],
    });

    await tester.pumpWidget(MaterialApp(
      home: BracketScreen(repository: repository, tournamentId: 't1'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('TBD'), findsNWidgets(2));
    expect(find.textContaining(' - '), findsNothing);
  });

  testWidgets('shows an empty state when the tournament has no matches yet', (tester) async {
    final repository = FakeTournamentsRepository(matchesByTournament: const {});

    await tester.pumpWidget(MaterialApp(
      home: BracketScreen(repository: repository, tournamentId: 't1'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No matches yet.'), findsOneWidget);
  });

  testWidgets('shows an error message when the fetch fails', (tester) async {
    final repository = FakeTournamentsRepository(bracketError: Exception('network down'));

    await tester.pumpWidget(MaterialApp(
      home: BracketScreen(repository: repository, tournamentId: 't1'),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load bracket'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
flutter test test/features/bracket_screen_test.dart
```

Expected: FAIL — `bracket_screen.dart` doesn't exist yet.

- [ ] **Step 3: Write the bracket screen**

`lib/features/tournaments/bracket_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../data/tournaments_repository.dart';
import '../../models/bracket_match.dart';

class BracketScreen extends StatefulWidget {
  const BracketScreen({
    super.key,
    required this.repository,
    required this.tournamentId,
  });

  final TournamentsRepository repository;
  final String tournamentId;

  @override
  State<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends State<BracketScreen> {
  late final Future<List<BracketMatch>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchBracket(widget.tournamentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bracket')),
      body: FutureBuilder<List<BracketMatch>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load bracket: ${snapshot.error}'));
          }
          final matches = snapshot.data!;
          if (matches.isEmpty) {
            return const Center(child: Text('No matches yet.'));
          }

          final matchesByRound = <String, List<BracketMatch>>{};
          for (final match in matches) {
            matchesByRound.putIfAbsent(match.round, () => []).add(match);
          }
          final rounds = matchesByRound.keys.toList()
            ..sort((a, b) => roundSortIndex(a).compareTo(roundSortIndex(b)));

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final round in rounds)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _RoundColumn(
                      round: round,
                      matches: matchesByRound[round]!,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoundColumn extends StatelessWidget {
  const _RoundColumn({required this.round, required this.matches});

  final String round;
  final List<BracketMatch> matches;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            roundDisplayName(round),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final match in matches) _MatchCard(match: match),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final BracketMatch match;

  @override
  Widget build(BuildContext context) {
    final hasScore = match.scoreA != null && match.scoreB != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(match.participantALabel),
            Text(match.participantBLabel),
            if (hasScore) ...[
              const SizedBox(height: 4),
              Text('${match.scoreA} - ${match.scoreB}'),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test and verify it passes**

```bash
flutter test test/features/bracket_screen_test.dart
```

Expected: 4 tests, PASS.

- [ ] **Step 5: Run the full suite and commit**

```bash
flutter test
git add lib/features/tournaments/bracket_screen.dart test/features/bracket_screen_test.dart
git commit -m "feat: add bracket screen grouped by round"
```

---

### Task 7: Wire the three screens together with `go_router`

**Files:**
- Create: `lib/router/app_router.dart`
- Modify: `lib/main.dart`
- Test: `test/router/app_router_test.dart`

**Interfaces:**
- Consumes: `TournamentListScreen`, `TournamentDetailScreen`, `BracketScreen` (Tasks 3, 4,
  6), `SupabaseTournamentsRepository` (Task 2/5), `FakeTournamentsRepository` (Task 3).
- Produces: `GoRouter buildAppRouter({TournamentsRepository? repository})` — `main.dart`
  calls it with no argument (defaulting to the live Supabase repository); tests pass a
  `FakeTournamentsRepository`.

- [ ] **Step 1: Write the failing router test**

`test/router/app_router_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/models/tournament.dart';
import 'package:sentinelx_mobile/router/app_router.dart';

import '../fakes/fake_tournaments_repository.dart';

Tournament _tournament() {
  return const Tournament(
    id: 't1',
    title: 'FC Mobile Premier League',
    slug: 'fc-mobile-premier-league',
    description: null,
    bannerUrl: null,
    cardImageUrl: null,
    status: 'active',
    format: 'group_knockout',
    competitionFormat: 'head_to_head',
    entryUnit: 'solo',
    prizePool: 10000,
    prizeSecond: null,
    prizeThird: null,
    registrationFee: 500,
    maxPlayers: 16,
    registrationStart: null,
    registrationEnd: null,
    tournamentStart: null,
    tournamentEnd: null,
    rules: null,
    gameName: 'EA FC Mobile',
  );
}

void main() {
  testWidgets('navigates list -> detail -> bracket and back', (tester) async {
    final repository = FakeTournamentsRepository(
      tournaments: [_tournament()],
      tournamentById: _tournament(),
      matchesByTournament: const {},
    );

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: buildAppRouter(repository: repository),
    ));
    await tester.pumpAndSettle();

    expect(find.text('FC Mobile Premier League'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tournament-tile-t1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('view-bracket-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('view-bracket-button')));
    await tester.pumpAndSettle();

    expect(find.text('No matches yet.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('view-bracket-button')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
flutter test test/router/app_router_test.dart
```

Expected: FAIL — `lib/router/app_router.dart` doesn't exist yet.

- [ ] **Step 3: Write the router**

`lib/router/app_router.dart`:

```dart
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_tournaments_repository.dart';
import '../data/tournaments_repository.dart';
import '../features/tournaments/bracket_screen.dart';
import '../features/tournaments/tournament_detail_screen.dart';
import '../features/tournaments/tournament_list_screen.dart';

GoRouter buildAppRouter({TournamentsRepository? repository}) {
  final tournamentsRepository =
      repository ?? SupabaseTournamentsRepository(Supabase.instance.client);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => TournamentListScreen(
          repository: tournamentsRepository,
          onTournamentTap: (tournament) => context.push('/tournaments/${tournament.id}'),
        ),
      ),
      GoRoute(
        path: '/tournaments/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TournamentDetailScreen(
            repository: tournamentsRepository,
            tournamentId: id,
            onViewBracket: () => context.push('/tournaments/$id/bracket'),
          );
        },
      ),
      GoRoute(
        path: '/tournaments/:id/bracket',
        builder: (context, state) => BracketScreen(
          repository: tournamentsRepository,
          tournamentId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
}
```

- [ ] **Step 4: Run the test and verify it passes**

```bash
flutter test test/router/app_router_test.dart
```

Expected: 1 test, PASS.

- [ ] **Step 5: Wire the router into `main.dart`**

Replace `lib/main.dart`'s `SentinelXApp.build` (written in Task 1) to use the router:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseEnv.url,
    anonKey: SupabaseEnv.publishableKey,
  );
  runApp(const SentinelXApp());
}

class SentinelXApp extends StatelessWidget {
  const SentinelXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sentinel X',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      routerConfig: buildAppRouter(),
    );
  }
}
```

- [ ] **Step 6: Update Task 1's smoke test for the new home**

`SentinelXApp` now boots straight into `TournamentListScreen` via the router instead of the
placeholder `Scaffold`. Update `test/widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('SentinelXApp boots into the tournament list app bar', (tester) async {
    await Supabase.initialize(
      url: 'https://itxubrkbropttfdackmi.supabase.co',
      anonKey: 'sb_publishable_bsIF_bY19uFCno5BjS4sMQ_PiEbY6zs',
    );

    await tester.pumpWidget(const SentinelXApp());
    await tester.pump();

    expect(find.text('Tournaments'), findsOneWidget);
  });
}
```

This test now depends on `Supabase.initialize` succeeding (the default `buildAppRouter()`
constructs a live `SupabaseTournamentsRepository`), so it needs network access; the app bar
title renders immediately regardless of whether the subsequent fetch succeeds, since
`FutureBuilder` shows a loading state rather than blocking the widget tree.

- [ ] **Step 7: Run the full suite**

```bash
flutter test
```

Expected: all tests PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/router/app_router.dart lib/main.dart test/router/app_router_test.dart test/widget_test.dart
git commit -m "feat: wire tournament list, detail, and bracket screens with go_router"
```

---

### Task 8: Run the app end-to-end against live Supabase data

**Files:** none created or modified — this is a verification-only task.

**Interfaces:** none — exercises everything built in Tasks 1–7 as a whole.

- [ ] **Step 1: Static analysis**

```bash
flutter analyze
```

Expected: `No issues found!`. Fix anything it reports before proceeding — do not suppress
warnings with `// ignore:` comments without understanding what triggered them first.

- [ ] **Step 2: Full test suite**

```bash
flutter test
```

Expected: every test from Tasks 1–7 PASSes.

- [ ] **Step 3: Launch on Windows desktop and observe startup logs**

```bash
flutter run -d windows
```

Watch the console output. Expected: the app builds, a window opens, and no
`Supabase`/`PostgrestException`/network exceptions appear in the log. If a query fails, the
relevant screen shows its "Failed to load ..." text rather than crashing — confirm that
text does *not* appear, which would mean the live query didn't match what Task 2/5 assumed
about the schema.

- [ ] **Step 4: Manually verify the vertical slice on the running window**

1. The home screen shows the "Tournaments" app bar and a list of real tournament titles
   (e.g. "FC Mobile Premier League — Season 2", "SentinelX DLS Community Cup III") — not
   the empty state, not an error.
2. Tap a tournament with a non-zero match count (per §"Verified schema", `FC Mobile
   Premier League — Season 2` has 32 matches). The detail screen shows its title, game
   name, status, and prize pool matching what's in the database.
3. Tap "View Bracket". The bracket screen shows round-header columns
   ("Group Stage", "Quarterfinal", "Semifinal", "Third Place", "Final" for that specific
   tournament) scrollable left-to-right, with real player names (not raw UUIDs, not
   "TBD" across the board) and real scores on completed matches.
4. Use the back button to return to the detail screen, then back again to the list —
   confirm both transitions work without error.

- [ ] **Step 5: Stop the running app**

Press `q` in the terminal running `flutter run`, or close the window, to end the session
cleanly.

- [ ] **Step 6: Final commit if Step 3's manual pass required any fixes**

If Step 3/4 surfaced a schema mismatch (e.g. a round value or status this plan didn't
anticipate) and it was fixed, commit that fix separately with a message describing what the
live data actually contained versus what was assumed. If no fixes were needed, there is
nothing to commit here — Task 7's commit is the last one for this slice.

---

## Explicitly out of scope (do not build in this plan)

- Auth (sign-in/sign-up) — every screen here reads anonymously, per the spec's §7.3
  recommendation to ship the read-only vertical slice first.
- Home screen, Match Centre, Rankings, Player profile, Hall of Fame, TV, Community feed —
  all separate rows in the spec's §3 table, each its own follow-up slice.
- The `notifications` RLS gap (spec §2) — irrelevant here, no notification UI is built.
- Android/iOS packaging, app icons, splash screens, release signing — this plan only
  targets running the app on the dev machine's available devices (`windows`, `chrome`,
  `edge`) to prove the data path works; app store readiness is a separate concern.
