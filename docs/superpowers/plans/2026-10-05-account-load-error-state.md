# Account Load Error State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent an authenticated account-fetch failure from being presented as a signed-out session, and give the player an explicit retry action.

**Architecture:** Keep `meProvider` as the single source of account state and render its complete `AsyncValue` in `AccountScreen`. Add no session cache or retry policy; the error action simply invalidates `meProvider`, allowing Riverpod to perform one fresh fetch.

**Tech Stack:** Flutter, Riverpod `FutureProvider`, Flutter localization ARBs, `flutter_test` widget tests

---

### Task 1: Localize the account-load failure UI

**Files:**
- Modify: `lib/core/l10n/app_en.arb:35`
- Modify: `lib/core/l10n/app_fr.arb:35`
- Regenerate: `lib/core/l10n/gen/app_localizations.dart`
- Regenerate: `lib/core/l10n/gen/app_localizations_en.dart`
- Regenerate: `lib/core/l10n/gen/app_localizations_fr.dart`

- [ ] **Step 1: Add the English strings**

Add these entries beside the existing account strings in `app_en.arb`:

```json
"accountLoadFailed": "Couldn't load your account.",
"accountRetry": "Retry",
```

- [ ] **Step 2: Add the French strings**

Add matching entries beside the existing account strings in `app_fr.arb`:

```json
"accountLoadFailed": "Impossible de charger votre compte.",
"accountRetry": "Réessayer",
```

- [ ] **Step 3: Regenerate localization classes**

Run: `flutter gen-l10n`

Expected: exit code 0; generated localization getters exist for both keys in English and French.

### Task 2: Reproduce the misleading account states with widget tests

**Files:**
- Modify: `test/features/account_screen_test.dart`

- [ ] **Step 1: Write a failing loading-state test**

Add `dart:async`, use a pending completer for the provider override, and assert that the progress indicator is shown without either authentication action:

```dart
testWidgets('loading: shows progress without authentication actions', (tester) async {
  final pending = Completer<MeResponse?>();
  addTearDown(() {
    if (!pending.isCompleted) pending.complete(null);
  });
  await tester.pumpWidget(_app(
    [meProvider.overrideWith((ref) => pending.future)],
    AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}),
  ));
  await tester.pump();
  expect(find.byKey(const Key('account-loading')), findsOneWidget);
  expect(find.byKey(const Key('account-login')), findsNothing);
  expect(find.byKey(const Key('account-signup')), findsNothing);
});
```

- [ ] **Step 2: Write a failing error-state test**

Override `meProvider` with a failed future and prove the screen shows the localized failure and retry action, never the login/create-account controls:

```dart
testWidgets('load failure: shows retry without authentication actions', (tester) async {
  await tester.pumpWidget(_app(
    [meProvider.overrideWith((ref) async => throw Exception('boom'))],
    AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}),
  ));
  await tester.pumpAndSettle();
  expect(find.text("Couldn't load your account."), findsOneWidget);
  expect(find.byKey(const Key('account-retry')), findsOneWidget);
  expect(find.byKey(const Key('account-login')), findsNothing);
  expect(find.byKey(const Key('account-signup')), findsNothing);
});
```

- [ ] **Step 3: Write a failing retry-state test**

Use a provider override whose first attempt throws and second attempt returns `_me()`. Tap Retry and prove that invalidation fetches again and renders the signed-in profile:

```dart
testWidgets('load failure: retry refetches and shows the account', (tester) async {
  var attempts = 0;
  await tester.pumpWidget(_app(
    [
      meProvider.overrideWith((ref) async {
        attempts++;
        if (attempts == 1) throw Exception('boom');
        return _me();
      }),
    ],
    AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('account-retry')));
  await tester.pumpAndSettle();
  expect(attempts, 2);
  expect(find.text('Ada'), findsOneWidget);
  expect(find.byKey(const Key('account-sign-out')), findsOneWidget);
});
```

- [ ] **Step 4: Run the focused test and verify RED**

Run: `flutter test test/features/account_screen_test.dart`

Expected: FAIL because `account-loading`, `account-retry`, and the account-load error rendering do not exist yet. Existing signed-out and signed-in tests remain valid regression coverage.

### Task 3: Render every `meProvider` state explicitly

**Files:**
- Modify: `lib/features/account/account_screen.dart:60-113`
- Test: `test/features/account_screen_test.dart`

- [ ] **Step 1: Preserve the complete asynchronous value**

Replace the lossy `asData?.value` read with:

```dart
final me = ref.watch(meProvider);
```

- [ ] **Step 2: Render loading and error branches**

Make the centered body child use `me.when(...)`. The loading branch must render:

```dart
const CircularProgressIndicator(key: Key('account-loading'))
```

The error branch must render localized copy and invalidate only `meProvider`:

```dart
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(l10n.accountLoadFailed, textAlign: TextAlign.center),
    const SizedBox(height: 12),
    ElevatedButton(
      key: const Key('account-retry'),
      onPressed: () => ref.invalidate(meProvider),
      child: Text(l10n.accountRetry),
    ),
  ],
)
```

Use the existing signed-out and signed-in columns unchanged inside the `data: (me) => ...` branch. Do not add automatic retry or infer session state from another provider.

- [ ] **Step 3: Run the focused test and verify GREEN**

Run: `flutter test test/features/account_screen_test.dart`

Expected: PASS for all account screen tests with no exceptions or warnings.

- [ ] **Step 4: Commit the behavior**

```bash
git add lib/core/l10n/app_en.arb lib/core/l10n/app_fr.arb lib/core/l10n/gen/app_localizations.dart lib/core/l10n/gen/app_localizations_en.dart lib/core/l10n/gen/app_localizations_fr.dart lib/features/account/account_screen.dart test/features/account_screen_test.dart
git commit -m "fix(account): distinguish load failure from sign-out"
```

### Task 4: Verify the mobile change

**Files:**
- Verify: all files changed in Tasks 1-3

- [ ] **Step 1: Check formatting**

Run: `dart format --output=none --set-exit-if-changed lib/features/account/account_screen.dart test/features/account_screen_test.dart`

Expected: exit code 0. If formatting is required, run `dart format` on exactly those two files, then rerun the check.

- [ ] **Step 2: Regenerate localization output once more**

Run: `flutter gen-l10n`

Expected: exit code 0 and no unexpected diff.

- [ ] **Step 3: Run static analysis**

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 4: Run the complete test suite**

Run: `flutter test`

Expected: all tests pass.

- [ ] **Step 5: Inspect the final diff**

Run: `git status --short` and `git diff --check HEAD~1..HEAD`

Expected: only intended account UI, localization, test, documentation, and separately tracked QA-note changes; no generated platform-plugin noise or whitespace errors.
