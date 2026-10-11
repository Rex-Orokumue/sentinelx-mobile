# Mobile Phase 6b Store — Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the coin Store (browse, buy, equip, unequip), render every equipped cosmetic everywhere a player appears (frames and bubble skins from bundled art, username colour and profile theme natively), and show the coin balance next to the wallet.

**Architecture:** A `StoreRepository` over `ApiClient` feeds providers and a `StoreScreen` with a detail sheet; purchases use `writeFlowProvider` (one `Idempotency-Key` per compose action). A `CosmeticArt` resolver maps any frame/bubble URL to a bundled WebP by **file name**, falling back to the network URL, so no API payload changes. `CosmeticStyle` maps username-colour and theme slugs to native styling.

**Tech Stack:** Flutter, Dart, Riverpod (manual providers), go_router, ARB l10n.

**Spec:** web `docs/superpowers/specs/2026-10-11-mobile-phase6b-store-coins-design.md`. **Starts only after** the web plan (`2026-10-11-mobile-phase6b-store-coins-web.md`) is merged and the production migration applied, because `api/openapi.json` is copied from the merged contract.

## Global Constraints

- Ownership, balance, price and the purchase outcome come only from the API; never read store tables through Supabase, never write via PostgREST, never compute a balance on the device.
- Copy comes from ARB (`app_en/fr/pcm.arb`); run `flutter gen-l10n` and commit the generated output. Errors map by CODE (`store_errors.dart`), never by the server's English message.
- Coins use one `formatCoins` helper; every `DateFormat` locale goes through `dateLocale()`.
- Screens are `ConsumerWidget`s over providers; none constructs a repository or `ApiClient`.
- The coin disclaimer ("SX Coins cannot be exchanged for cash. They are earned by competing and spent on the platform.") is visible on the Store header and next to the wallet coin balance. There is no coin-purchase surface and no copy implying one.
- Bundled art: the 20 WebP files are copied byte-for-byte from the web repo's `public/coin-items/` (`C:/Users/gorok/Videos/sentinelx/public/coin-items/*.webp`) into `assets/store/` under the **same file names**; `pubspec.yaml` lists `assets/store/`.
- No production writes. Layout verified at 320 and 375 px in `en`, `fr`, `pcm`. `flutter analyze --no-pub` and `flutter test --no-pub` clean before every commit; restore generated desktop plugin registrants (`git checkout -- linux windows macos`) before committing.
- Edit files with the Write/Edit tools (long shell heredocs truncated a file in 6a).

## Review Focus

- A double tap on Buy sends one request; a different item gets a different key. Task 6.
- A purchase never shows as owned until the server says so; failure leaves the item buyable. Task 6.
- An unknown frame/bubble file name, or a bundled name with a query string or different host, still renders (network fallback / no crash). Task 2.
- An unknown username-colour or theme slug renders the default style, never an error. Task 4.
- Signed-out visitors can browse but cannot buy (log-in prompt). Task 7.
- No screen text or log ever contains the server's raw error message. Tasks 5 and 6.

---

## File Structure

| Path | Responsibility |
|---|---|
| `api/openapi.json` | Copied byte-for-byte from the merged web contract |
| `assets/store/*.webp` (20), `pubspec.yaml` | Bundled store art |
| `lib/core/api/store_models.dart`, `api_client.dart` (modify) | Models and four store methods; `coinBalance`; `/me` cosmetics |
| `lib/shared/cosmetics/cosmetic_art.dart`, `cosmetic_style.dart` | Art resolver and native styles |
| `lib/shared/widgets/player_avatar.dart`, `lib/features/guide/guide_mascot.dart` (modify) | Use `CosmeticArt` |
| `lib/features/store/store_repository.dart`, `store_providers.dart`, `store_errors.dart`, `coin_format.dart` | Data and helpers |
| `lib/features/store/store_screen.dart`, `store_item_sheet.dart` | UI |
| `lib/router/app_router.dart`, `lib/core/routing/web_links.dart`, `account_screen.dart` | Route, hub tile, web link |

---

### Task 1: Contract, models, client

**Files:** `api/openapi.json`, `lib/core/api/store_models.dart`, `lib/core/api/api_client.dart`, `lib/core/api/wallet_models.dart`, `lib/core/api/models.dart` (`MeProfile`), tests `test/core/api/store_models_test.dart`, `test/core/api_client_store_test.dart`, `test/core/api/wallet_models_test.dart`.

**Interfaces — Produces:**

```dart
class StoreItem { final String id, slug, name, category, previewUrl; final String? description;
  final int priceCoins; final bool owned, equipped; factory StoreItem.fromJson(Map<String, dynamic> j); StoreItem copyWith({bool? owned, bool? equipped}); }
class StoreCatalogue { final int? balance; final List<StoreItem> items; factory StoreCatalogue.fromJson(Map<String, dynamic> j); }
class PurchaseOutcome { final int balance; final String itemId; }
class EquipOutcome { final String itemId, category; }
// ApiClient
Future<StoreCatalogue> getStore();
Future<PurchaseOutcome> purchaseStoreItem(String itemId, {required String idempotencyKey});
Future<EquipOutcome> equipStoreItem(String itemId);
Future<EquipOutcome> unequipStoreItem(String itemId);
// WalletOverview.coinBalance: int ;  MeProfile.usernameColour / profileTheme: String?
```

- [ ] **Step 1:** Copy web `openapi/mobile-v1.json` to `api/openapi.json` untouched. Add to `ApiClient.usedOperations`: `'getStore': 'get /api/mobile/v1/store'`, `'purchaseStoreItem': 'post /api/mobile/v1/store/{itemId}/purchase'`, `'equipStoreItem': 'post /api/mobile/v1/store/{itemId}/equip'`, `'unequipStoreItem': 'post /api/mobile/v1/store/{itemId}/unequip'`.
- [ ] **Step 2: Failing tests.** `store_models_test`: parse a catalogue with a null `balance` (signed out), owned + equipped items, a null description; `copyWith`; an item missing `priceCoins` throws. `wallet_models_test`: `coinBalance` parsed (add to the existing fixtures). `api_client_store_test` (same `_FakeAdapter` pattern as `api_client_wallet_test.dart`): `purchaseStoreItem` POSTs to `/store/<encoded id>/purchase` with the `Idempotency-Key` header and an empty body, returns balance and id; `equipStoreItem` / `unequipStoreItem` POST to `/equip` and `/unequip` with **no** idempotency header; `getStore` GETs `/store` (a request with no bearer still parses); an `insufficient_coins` 422 surfaces as `ApiException(code: 'insufficient_coins')`. A mutation check: temporarily break the header name and see the purchase test go red, then restore.
- [ ] **Step 3:** Run red; implement models, methods and the two additive fields (`coinBalance: (j['coinBalance'] as num).toInt()`, `usernameColour: j['usernameColour'] as String?`, `profileTheme: j['profileTheme'] as String?`). Run `test/core` green and `flutter analyze --no-pub lib/core test/core`.
- [ ] **Step 4: Commit** `feat(store): API client and models for /store`.

---

### Task 2: Bundled art and `CosmeticArt`

**Files:** `assets/store/*.webp` (20), `pubspec.yaml`, `lib/shared/cosmetics/cosmetic_art.dart`, `test/shared/cosmetics/cosmetic_art_test.dart`.

**Interfaces — Produces:**

```dart
class CosmeticArt {
  /// The 20 bundled file names (identical to the web's public/coin-items names).
  static const Set<String> bundledNames = {...};
  /// 'assets/store/<name>' when the URL or path ends in a bundled file name (query/fragment ignored); else null.
  static String? assetFor(String? urlOrPath);
  /// Bundled asset if known, else Image.network(url), else [fallback] (default: SizedBox.shrink()).
  static Widget image(String? urlOrPath, {double? width, double? height, BoxFit fit = BoxFit.contain, Widget? fallback});
}
```

- [ ] **Step 1:** Copy the 20 files: `for f in C:/Users/gorok/Videos/sentinelx/public/coin-items/*.webp; do cp "$f" assets/store/; done` (do **not** copy the `.jpeg` originals). Add `- assets/store/` under `flutter: assets:` in `pubspec.yaml`. The names are: `bronze-frame, purple-glow, gold-crown, champion-frame, cyber-core, diamond-edge, legendary-SX, mythic-sentinel, neon-pulse, shadow-flame` (frames, `.webp`), `bubble-mascot-classic, bubble-mascot-neon, bubble-mascot-gold`, `theme-dark-void, theme-lagos-skyline, theme-neon-grid`, `username-gold, username-purple, username-red, username-teal`.
- [ ] **Step 2: Failing tests.** `assetFor`: `'/coin-items/gold-crown.webp'` and `'https://sentinelxesports.com.ng/coin-items/gold-crown.webp?v=2'` both → `'assets/store/gold-crown.webp'`; `'/coin-items/new-frame.webp'`, `''`, `null`, `'not a url'` → `null`; `legendary-SX.webp` keeps its capital letters. A directory test: every name in `bundledNames` has a file under `assets/store/` (`File('assets/store/$n').existsSync()`), every `.webp` in `assets/store/` is in `bundledNames`, and `pubspec.yaml` contains `assets/store/`. Widget tests: `image('/coin-items/gold-crown.webp')` builds an `Image` with an `AssetImage`; an unknown name builds an `Image.network` whose `errorBuilder` yields the fallback; `null` yields the fallback.
- [ ] **Step 3:** Run red; implement; run green; `flutter analyze --no-pub lib/shared test/shared`.
- [ ] **Step 4: Commit** `feat(store): bundled store art and CosmeticArt resolver`.

---

### Task 3: Frames and bubble skins use bundled art

**Files:** `lib/shared/widgets/player_avatar.dart`, `lib/features/guide/guide_mascot.dart`; update their tests.

**Interfaces — Consumes:** `CosmeticArt.image` (Task 2). `PlayerAvatar` and `GuideMascot` signatures are unchanged.

- [ ] **Step 1: Failing tests.** `PlayerAvatar(frameUrl: 'https://x.test/coin-items/gold-crown.webp')` renders the **asset** frame (find an `Image` whose provider is `AssetImage('assets/store/gold-crown.webp')`) and no `NetworkImage` for the frame; an unknown frame name still renders `Image.network`; `frameUrl: null` and `isDeleted: true` render no frame (unchanged). `GuideMascot` with `bubbleSkinUrl` of a known bubble name renders the asset; unknown name → network with the bundled default as error fallback; no skin → the default mascot. Run red.
- [ ] **Step 2:** Replace the frame `Image.network(...)` in `PlayerAvatar` with `CosmeticArt.image(frameUrl, fallback: const SizedBox.shrink())` (keep the `Positioned`/`IgnorePointer` wrapper and sizes), and the network branch in `GuideMascot` with `CosmeticArt.image(url, width: size, height: size, fallback: fallback)`.
- [ ] **Step 3:** Run `test/shared test/features/guide` and the full suite (existing tests that expected `Image.network` for a frame must be re-pointed to the asset provider; do not loosen them). `flutter analyze --no-pub`. 
- [ ] **Step 4: Commit** `feat(store): render frames and bubble skins from bundled art`.

---

### Task 4: Username colour and profile theme

**Files:** `lib/shared/cosmetics/cosmetic_style.dart`, `lib/features/players/profile_sections.dart`, `lib/features/account/account_screen.dart`, tests `test/shared/cosmetics/cosmetic_style_test.dart`, `test/features/players/profile_header_cosmetics_test.dart`, `test/features/account_screen_test.dart`.

**Interfaces — Produces:**

```dart
class CosmeticStyle {
  /// Web colours: purple #A78BFA (accentText), gold #FBBF24 (amber-400), red #F87171 (red-400), teal #2DD4BF (teal-400).
  static Color? usernameColour(String? slug);          // null for null/unknown
  /// null for null/unknown; dark_void = flat black; neon_grid = violet grid on slate; lagos_skyline = orange-to-slate gradient.
  static BoxDecoration? profileTheme(String? slug);
}
```

- [ ] **Step 1: Failing tests.** `cosmetic_style_test`: the four colours and three themes resolve; `null`, `''`, `'username_pink'`, `'theme_unknown'` → `null`; themes return a `BoxDecoration` (`neon_grid` uses a `gradient`/image-free pattern painted via `CustomPaint` is **not** required: use a layered `LinearGradient` pair, a documented approximation of the web's CSS grid). `profile_header_cosmetics_test`: `ProfileHeaderSection` with `usernameColour: 'username_gold'` paints the display name in gold; with `profileTheme: 'theme_lagos_skyline'` the header sits in a `DecoratedBox` with that gradient; with unknown slugs it matches the current look exactly (golden-free: assert the style colour is the default text colour and no `DecoratedBox` is added). `account_screen_test`: the signed-in name uses the colour from `me.profile.usernameColour`; null leaves it unchanged; the theme wraps the identity block.
- [ ] **Step 2:** Run red; implement `CosmeticStyle`; in `ProfileHeaderSection` apply `usernameColour` to the `player.label` style and wrap the header `Padding` in a `DecoratedBox(decoration: profileTheme)` only when non-null (keep the inner padding); in `AccountScreen` apply the same to the identity `Text` from `me.profile`.
- [ ] **Step 3:** Run `test/shared test/features/players test/features/account_screen_test.dart` green; analyze.
- [ ] **Step 4: Commit** `feat(store): render username colour and profile theme`.

---

### Task 5: Store data layer, copy and helpers

**Files:** `lib/features/store/{store_repository,store_providers,store_errors,coin_format}.dart`, ARB (`app_en/fr/pcm.arb`), tests `test/features/store/{store_providers_test,store_errors_test,coin_format_test}.dart`, fake `test/fakes/fake_store_repository.dart`.

**Interfaces — Produces:**

```dart
abstract class StoreRepository { Future<StoreCatalogue> catalogue(); Future<PurchaseOutcome> purchase(String itemId, {required String idempotencyKey});
  Future<EquipOutcome> equip(String itemId); Future<EquipOutcome> unequip(String itemId); }
final storeRepositoryProvider = Provider<StoreRepository>(...);
final storeCatalogueProvider = FutureProvider.autoDispose<StoreCatalogue>(...);   // refetches when the viewer changes
String formatCoins(int amount);                    // '1,200', '−150' with a true minus
String storeErrorCopy(AppLocalizations l10n, Object error);   // by code
```

- [ ] **Step 1: ARB keys** (en first, then fr and pcm in the existing register; placeholders typed `String`): `storeTitle`, `storeBalance`, `storeDisclaimer` ("SX Coins cannot be exchanged for cash. They are earned by competing and spent on the platform."), `storeCatBorders`, `storeCatBubbles`, `storeCatThemes`, `storeCatColours`, `storeOwned`, `storeEquipped`, `storeBuy`, `storeEquip`, `storeUnequip`, `storeBuyConfirmTitle`, `storeBuyConfirmBody` (`{price}`, `{balance}`), `storeCancel`, `storeBought`, `storeEquippedNow`, `storeUnequippedNow`, `storeNeedMore` (`{more}`), `storeLoadFailed`, `storeRetry`, `storeEmpty`, `storeLogInToBuy`, `storeErrNotFound`, `storeErrUnavailable`, `storeErrOwned`, `storeErrInsufficient`, `storeErrStore`, `storeErrPendingDeletion`, `storeErrNetwork`, `storeErrSession`, `storeErrInProgress`, `storeErrGeneric`, `walletCoinBalance`. Run `flutter gen-l10n`.
- [ ] **Step 2: Failing tests.** `coin_format_test`: `0`→`0`, `1200`→`1,200`, `-150`→`−150`. `store_errors_test`: codes `not_found`, `item_unavailable`, `already_owned`, `insufficient_coins`, `store_unavailable`, `account_pending_deletion`, `not_owned`, `network`, `unauthorized`, `idempotency_in_progress` map to their own copy; unknown codes and non-`ApiException`s → generic; the raw message never appears. `store_providers_test` (fake repository, `viewerIdProvider` override): the catalogue loads for a signed-in and a signed-out viewer; a viewer change re-runs it.
- [ ] **Step 3:** Run red; implement; green; analyze (`lib/features/store test/features/store test/fakes lib/core/l10n`).
- [ ] **Step 4: Commit** `feat(store): store data layer, copy and helpers`.

---

### Task 6: Store screen and item sheet

**Files:** `lib/features/store/store_screen.dart`, `lib/features/store/store_item_sheet.dart`, `test/features/store/store_screen_test.dart`, `test/features/store/store_item_sheet_test.dart` (use a `pumpStore` harness modelled on `test/features/wallet/wallet_test_harness.dart`, with `retry: (_, _) => null`).

**Interfaces — Consumes:** `storeCatalogueProvider`, `storeRepositoryProvider`, `writeFlowProvider`, `CosmeticArt`, `formatCoins`, `storeErrorCopy`.

- [ ] **Step 1: Failing tests (screen).** Loading spinner (`Key('store-loading')`); failed load shows retry that refetches; header shows `formatCoins(balance)` and the disclaimer; signed out shows no balance and a log-in prompt on Buy; category chips (`Key('store-cat-<category>')`) filter the grid; each card shows the bundled preview, name, price, and an Owned or Equipped badge; empty category shows `storeEmpty`; pull-to-refresh refetches; layout has no overflow at 320 px in `en`/`fr`/`pcm` with long French names.
- [ ] **Step 2: Failing tests (sheet).** Tapping a card opens a sheet with a large preview, description, price. Not owned + enough coins → **Buy** enabled; not enough → disabled with `storeNeedMore(<price - balance>)`. Buy asks for confirmation (price and resulting balance) and only on confirm calls `purchase` with an idempotency key: success refetches the catalogue, shows `storeBought`, and the sheet now offers **Equip**; two `onPressed()` calls in the same frame send **one** request and show no error (assert via the fake's call count and `Key('store-error')` absent); a network failure then a retry reuses the key, switching to a **different item** uses a different key (scope `store-purchase:<itemId>`); each error code (`insufficient_coins`, `already_owned`, `item_unavailable`, `store_unavailable`, `account_pending_deletion`) shows its localized copy and never `RAW SERVER MESSAGE`; `already_owned` also refetches so the item shows Owned. Equip calls `equip`, success shows Equipped on this card and clears the previous one in the category after the refetch; Unequip calls `unequip`. A mutation check: remove the busy guard and see the double-tap test go red, restore.
- [ ] **Step 3:** Run red; implement (the sheet via `showModalBottomSheet`; the flow via `ref.read(writeFlowProvider('store-purchase:$itemId').notifier).run(...)` with `fingerprint: itemId`, the screen **watching** the flow so it stays alive; no optimistic ownership: refetch `storeCatalogueProvider` and invalidate `walletOverviewProvider` after a purchase); run green; analyze.
- [ ] **Step 4: Commit** `feat(store): store screen, item sheet, purchase and equip`.

---

### Task 7: Route, hub tile, web link, wallet coin balance


- [ ] **Step 1: Failing tests.** `web_links`: `https://sentinelxesports.com.ng/store` and `/fr/store` → `/account/store`; an in-app `/account/store` passes through untouched; another host → null. Router: `/account/store` opens `StoreScreen` for a player and for a moderator; signed out it still opens (browse) and Buy shows the log-in prompt (no `store-*` request for ownership). Hub: the **Store** tile (`Key('account-store')`) opens it for players and moderators. Wallet: the overview shows the coin balance (`formatCoins(coinBalance)`) with the disclaimer line, hidden when loading/failed.
- [ ] **Step 2:** Run red; implement: nested `GoRoute(path: 'store')` under `/account`, `onOpenStore` on `AccountScreen` (same pattern as `onOpenWallet`), the `case 'store': return '/account/store'` mapping, the coin row in `WalletScreen`.
- [ ] **Step 3:** Run the four test files green plus the full suite (`flutter test --no-pub`, redirect output to the workspace and read its tail); fix any existing test that used `/store` as an unmapped link by switching it to another unmapped path (as in 6a); analyze.
- [ ] **Step 4: Commit** `feat(store): route, hub tile, web link and wallet coin balance`.

---

### Task 8: Final gate and handoff

- [ ] **Step 1: Cold read** the diff: no Supabase/table access in `lib/features/store`, no raw server message shown, no hard-coded `Text` copy, no balance arithmetic beyond `price - balance` for the "need N more" hint, no `print`, no coin-purchase wording (`grep -rniE "buy coins|top up coins|purchase coins" lib`).
- [ ] **Step 2:** `git fetch origin master`, rebase; `flutter gen-l10n`; serially `flutter analyze --no-pub` and `flutter test --no-pub`. Expected: no issues, all pass. Restore generated plugin registrants.
- [ ] **Step 3:** Merge `--no-ff`, verify the merged tree equals the tested tree, push `master` (only after the web side is merged and the production migration applied).
- [ ] **Step 4:** Append a Phase 6b device-pass table to `TESTING-NOTES.md` (all rows **pending**; staging only; run once all of Phase 6 is built): store loads and matches the web catalogue; buy a 150-coin item and see exactly one debit in the coin history; two quick taps buy once; equip a frame and see it on lists, profile and the assistant bubble after relaunch; equip a username colour and theme and see them on the profile and Account identity; unequip clears them; buying with too few coins is refused; airplane-mode retry creates one purchase; frames render offline; layouts at 320–375 px in en/fr/pcm. Add the `/account/store` row and a "Store (Phase 6b)" note to `CLAUDE.md`, and log the slice in `docs/agent-handoffs/codex-progress.md`.
