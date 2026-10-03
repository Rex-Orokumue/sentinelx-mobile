# Mobile Profile Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add compulsory Flutter profile onboarding and settings parity for canonical country, country-valid WhatsApp, explicit outreach consent, and at least one game interest, using the finalized web mobile API contract.

**Architecture:** Copy the generated web OpenAPI contract and extend the hand-written `ApiClient` with one new onboarding write. Keep server-owned gate state in `/me`, reuse the existing public `gamesProvider` for selectable active games, and isolate form state in feature widgets/providers. A shared country selector wraps `country_picker` so onboarding and account settings submit canonical English names without duplicating UI logic.

**Tech Stack:** Flutter, Dart, Riverpod (manual providers), Dio, go_router, `country_picker` 2.0.28, flutter_test.

**Upstream contract:** Web handoff `docs/agent-handoffs/2026-10-03-mobile-profile-api-contract.md`, web branch `worktree-game-designer-mode-catalogue-ui` at `1568e40`; contract implementation commits `5ae53a0`, `3350b43`, `5f911ba`.

---

## Constraints and rollout gates

- Never hand-edit `api/openapi.json`; copy the web branch's `openapi/mobile-v1.json` byte-for-byte.
- Every new `ApiClient` method must appear in `ApiClient.usedOperations`.
- No production writes or live production onboarding tests. Staging is the only write-test target.
- The web branch and two migrations are not yet on production. Mobile can compile and test against fakes now, but live calls wait for deployment.
- New API models go in `lib/core/api/profile_onboarding_models.dart`, not the shared `models.dart` file.
- Widget copy lives in `lib/core/l10n/app_en.arb`; regenerate with `flutter gen-l10n` and never edit generated localization files manually.
- The existing public `gamesProvider` is reused; this feature does not extend the temporary tournament slice.
- Gate priority is username → phone when enabled → profile → none.

## Task 1: Pin the finalized contract and add API models/client methods

**Files:**
- Replace: `api/openapi.json` (copy from web; never edit)
- Create: `lib/core/api/profile_onboarding_models.dart`
- Modify: `lib/core/api/models.dart`
- Modify: `lib/core/api/compete_models.dart`
- Modify: `lib/core/api/api_client.dart`
- Test: `test/core/profile_onboarding_models_test.dart`
- Modify: `test/core/api_client_test.dart`
- Modify: `test/core/api_client_compete_test.dart`
- Test: `test/core/api_contract_test.dart`

- [ ] **Step 1: Write failing model tests**

Cover `/me` parsing for `profileCompletedAt`, `consentWhatsappUpdates`, and UUID `gameInterests`; cover an incomplete profile (`null`, `false`, `[]`). Add `ProfileOnboardingInput.toJson()` and `ProfileOnboardingResult.fromJson()` expectations. Extend `ProfileEdit.toJson()` tests so new optional fields are omitted when null and preserve `false` when supplied.

- [ ] **Step 2: Run the focused tests and confirm failure**

Run:

```powershell
flutter test test/core/profile_onboarding_models_test.dart test/core/api_client_test.dart test/core/api_client_compete_test.dart
```

Expected: FAIL because the fields/types/client method do not exist.

- [ ] **Step 3: Copy OpenAPI and implement the contract**

Copy the web branch file exactly. Add:

```dart
class ProfileOnboardingInput {
  const ProfileOnboardingInput({
    required this.country,
    required this.whatsapp,
    required this.consentWhatsappUpdates,
    required this.gameInterests,
  });

  final String country;
  final String whatsapp;
  final bool consentWhatsappUpdates;
  final List<String> gameInterests;

  Map<String, Object?> toJson() => {
    'country': country,
    'whatsapp': whatsapp,
    'consentWhatsappUpdates': consentWhatsappUpdates,
    'gameInterests': gameInterests,
  };
}

class ProfileOnboardingResult {
  const ProfileOnboardingResult({required this.profileCompletedAt});
  factory ProfileOnboardingResult.fromJson(Map<String, dynamic> json) =>
      ProfileOnboardingResult(profileCompletedAt: json['profileCompletedAt'] as String);
  final String profileCompletedAt;
}
```

Add `postOnboardingProfile` to `usedOperations` and:

```dart
Future<ProfileOnboardingResult> postOnboardingProfile(ProfileOnboardingInput input) =>
    _send('POST', '/onboarding/profile',
      (d) => ProfileOnboardingResult.fromJson(d! as Map<String, dynamic>),
      body: input.toJson());
```

Extend `MeProfile` with the three always-present server fields. Extend `ProfileEdit` with nullable `gameInterests` and `consentWhatsappUpdates`, using conditional map entries so omission means unchanged.

- [ ] **Step 4: Run contract/model/client tests**

```powershell
flutter test test/core/profile_onboarding_models_test.dart test/core/api_client_test.dart test/core/api_client_compete_test.dart test/core/api_contract_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add api/openapi.json lib/core/api test/core
git commit -m "feat(profile): adopt profile-onboarding API contract"
```

## Task 2: Add the profile gate and redirect policy

**Files:**
- Modify: `lib/core/auth/onboarding_gate.dart`
- Modify: `lib/router/auth_redirect.dart`
- Test: `test/core/onboarding_gate_test.dart`
- Modify: `test/router/auth_redirect_test.dart`

- [ ] **Step 1: Write failing gate and redirect tests**

Test username priority, disabled/enabled phone priority, `profileCompletedAt == null` → `OnboardingGate.profile`, completed → none, redirect to `/onboarding/profile`, no loop while already there, and redirect away from both onboarding routes after completion.

- [ ] **Step 2: Run and confirm failure**

```powershell
flutter test test/core/onboarding_gate_test.dart test/router/auth_redirect_test.dart
```

- [ ] **Step 3: Implement the minimal gate/router change**

Change the enum to `username, phone, profile, none`; check `me.profile?.profileCompletedAt == null` after the phone branch. Treat both onboarding routes as exempt destinations. The concrete route is added with its screen after localization exists in Task 5, so this task remains independently compilable.

- [ ] **Step 4: Run tests and commit**

```powershell
flutter test test/core/onboarding_gate_test.dart test/router/auth_redirect_test.dart
git add lib/core/auth lib/router/auth_redirect.dart test/core/onboarding_gate_test.dart test/router/auth_redirect_test.dart
git commit -m "feat(profile): add compulsory profile onboarding gate"
```

## Task 3: Add shared country and game-interest field components

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock`
- Create: `lib/features/account/country_field.dart`
- Create: `lib/features/account/game_interests_field.dart`
- Test: `test/features/account/country_field_test.dart`
- Test: `test/features/account/game_interests_field_test.dart`

- [ ] **Step 1: Add `country_picker` and write failing widget tests**

Run `flutter pub add country_picker:^2.0.28`. Test that the country field displays the current canonical name, opens a searchable picker, and returns the selected English name. Test game interests loading/error/retry, preselection, multiple selection, and the at-least-one validation message.

- [ ] **Step 2: Implement focused reusable widgets**

`CountryField` owns no API state: it accepts `value`, `onChanged`, `enabled`, and `errorText`. `GameInterestsField` accepts `AsyncValue<List<GameSummary>>`, selected IDs, selection callback, retry callback, enabled state, and error text. Use existing theme colors only.

- [ ] **Step 3: Run and commit**

```powershell
flutter test test/features/account/country_field_test.dart test/features/account/game_interests_field_test.dart
git add pubspec.yaml pubspec.lock lib/features/account test/features/account
git commit -m "feat(profile): add country and game-interest fields"
```

## Task 4: Add localized copy and regenerate output

**Files:**
- Modify: `lib/core/l10n/app_en.arb`
- Generated: `lib/core/l10n/gen/*`
- Test: `test/core/l10n_test.dart`

- [ ] **Step 1: Add all profile-onboarding copy to the ARB template**

Include title, explanation, country/WhatsApp/game labels, consent yes/no wording, required-field messages, loading/retry text, submission/success/failure text, and canonical server-field-error mappings. No widget hard-coded strings.

- [ ] **Step 2: Generate and verify**

```powershell
flutter gen-l10n
flutter test test/core/l10n_test.dart
```

- [ ] **Step 3: Commit**

```powershell
git add lib/core/l10n
git commit -m "feat(l10n): add profile onboarding copy"
```

## Task 5: Build the compulsory onboarding screen

**Files:**
- Create: `lib/features/account/profile_onboarding_providers.dart`
- Create: `lib/features/account/profile_onboarding_screen.dart`
- Test: `test/features/account/profile_onboarding_screen_test.dart`
- Modify: `lib/router/app_router.dart`

- [ ] **Step 1: Write failing screen tests**

At 375×800 test: current profile values prefill; country and WhatsApp are required; at least one game is required; consent requires an explicit yes/no selection but `false` remains valid; submit sends the exact API body; server field errors render beside the matching fields; double-submit is blocked; success invalidates `/me` and leaves the gate; 401 routes to login; game loading/error states cannot submit.

- [ ] **Step 2: Implement provider and screen**

Expose `profileOnboardingSubmitterProvider` as a manual provider wrapping `ApiClient.postOnboardingProfile`. The screen is a `ConsumerStatefulWidget` because it owns WhatsApp, selected country, consent choice, selected game IDs, busy state, and server field errors. Reuse `gamesProvider`, `CountryField`, and `GameInterestsField`.

- [ ] **Step 3: Wire the real route, run, and commit**

```powershell
flutter test test/features/account/profile_onboarding_screen_test.dart test/router/app_router_test.dart
git add lib/features/account lib/router/app_router.dart test/features/account test/router/app_router_test.dart
git commit -m "feat(profile): build compulsory profile onboarding screen"
```

## Task 6: Bring account profile editing to contract parity

**Files:**
- Modify: `lib/features/account/edit_profile_screen.dart`
- Modify: `lib/features/account/profile_providers.dart`
- Modify: `test/features/account/edit_profile_screen_test.dart`

- [ ] **Step 1: Add failing regression and parity tests**

Test canonical country selection, preselected interests, explicit consent `false`, submission of all current values, at-least-one game validation, server `country`/`whatsapp`/`gameInterests` errors beside fields, and generic fallback when validation errors do not map to a visible field. Preserve existing username and bio behavior.

- [ ] **Step 2: Implement settings parity**

Reuse the two shared fields. Populate values from `MeProfile`; send `gameInterests` and `consentWhatsappUpdates` on every settings save so the screen acts as a full editor. Do not alter `profileCompletedAt`. Map server field errors without exposing raw server copy.

- [ ] **Step 3: Run and commit**

```powershell
flutter test test/features/account/edit_profile_screen_test.dart test/core/api_client_compete_test.dart
git add lib/features/account test/features/account/edit_profile_screen_test.dart
git commit -m "feat(profile): add interests and consent to profile settings"
```

## Task 7: Final integration and rollout verification

**Files:**
- Create: `docs/agent-handoffs/2026-10-03-mobile-profile-onboarding-handoff.md`

- [ ] **Step 1: Verify the copied contract is exact**

```powershell
git diff --no-index --ignore-space-at-eol -- api/openapi.json C:\Users\gorok\Videos\sentinelx\.claude\worktrees\game-designer-mode-catalogue-ui\openapi\mobile-v1.json
```

Expected: no semantic/text diff apart from allowed line-ending normalization.

- [ ] **Step 2: Run full verification**

```powershell
flutter gen-l10n
flutter analyze
flutter test
git status --short
```

Expected: generated localization current, analyzer clean, all tests passing, only intentional files changed.

- [ ] **Step 3: Record rollout limitations**

The handoff must state that unit/widget verification is complete, live write-path testing must use staging, and production activation waits for the web branch merge plus both production migrations.

- [ ] **Step 4: Commit the handoff**

```powershell
git add docs/agent-handoffs/2026-10-03-mobile-profile-onboarding-handoff.md
git commit -m "docs: hand off mobile profile onboarding"
```

## Deferred, intentionally

- Phase 5a notifications/push work is a separate spec and implementation stream.
- Web Settings form controls and admin game-interest export pages do not block the mobile onboarding contract.
- No production deployment, migration application, or production write testing is performed by this plan.
