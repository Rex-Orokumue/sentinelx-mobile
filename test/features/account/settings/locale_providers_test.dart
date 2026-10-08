import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/storage/local_kv.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/locale_providers.dart';

import '../../../fakes/fake_account_repository.dart';
import '../../../fakes/fake_local_kv.dart';

MeResponse _me(String? locale) => MeResponse(
      id: 'u1', email: 'a@b.com', roles: const [], isStaff: false, isAdmin: false,
      profile: MeProfile(
        username: 'ada', displayName: 'Ada', avatarUrl: null, whatsappNumber: null, country: null, locale: locale,
        membershipTier: null, kycVerified: false, deletionRequestedAt: null,
      ),
    );

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeAccountRepository repo;
  late MemoryLocalKv kv;
  late ProviderContainer c;
  late bool signedIn;
  late String? serverLocale;

  ProviderContainer make() => ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          accountRepositoryProvider.overrideWithValue(repo),
          localKvProvider.overrideWith((ref) async => kv),
          viewerIdProvider.overrideWith((ref) async => signedIn ? 'u1' : null),
          meProvider.overrideWith((ref) async => signedIn ? _me(serverLocale) : null),
        ],
      );

  setUp(() {
    repo = FakeAccountRepository();
    kv = MemoryLocalKv();
    signedIn = true;
    serverLocale = 'fr';
  });

  test('starts with the server locale and caches it for the next cold start', () async {
    c = make();
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    await c.read(meProvider.future);
    await _settle();
    expect(c.read(localeProvider), const Locale('fr'));
    expect(kv.values['app.locale'], 'fr');
  });

  test('uses the cached locale before /me answers (signed out or cold start)', () async {
    signedIn = false;
    kv.values['app.locale'] = 'pcm';
    c = make();
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    await _settle();
    await _settle();
    expect(c.read(localeProvider), const Locale('pcm'));
  });

  test('ignores a cached or server value it does not support', () async {
    kv.values['app.locale'] = 'de';
    serverLocale = 'es';
    c = make();
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    await c.read(meProvider.future);
    await _settle();
    expect(c.read(localeProvider), isNull);
  });

  test('select saves to the server, updates state and the cache', () async {
    c = make();
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    await c.read(meProvider.future);
    expect(await c.read(localeProvider.notifier).select('pcm'), isTrue);
    expect(c.read(localeProvider), const Locale('pcm'));
    expect(repo.lastLocale, 'pcm');
    expect(kv.values['app.locale'], 'pcm');
  });

  test('select saves while /me is refreshing', () async {
    final refresh = Completer<MeResponse?>();
    var calls = 0;
    c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        accountRepositoryProvider.overrideWithValue(repo),
        localKvProvider.overrideWith((ref) async => kv),
        viewerIdProvider.overrideWith((ref) async => 'u1'),
        meProvider.overrideWith((ref) {
          calls++;
          return calls == 1 ? Future.value(_me('fr')) : refresh.future;
        }),
      ],
    );
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    await c.read(meProvider.future);
    c.invalidate(meProvider);
    await _settle();
    expect(c.read(meProvider).isLoading, isTrue);

    expect(await c.read(localeProvider.notifier).select('pcm'), isTrue);
    expect(repo.lastLocale, 'pcm');
    refresh.complete(_me('fr'));
    await c.read(meProvider.future);
    expect(c.read(localeProvider), const Locale('pcm'));
  });

  test('select saves before the first /me response for a signed-in viewer', () async {
    final firstMe = Completer<MeResponse?>();
    c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        accountRepositoryProvider.overrideWithValue(repo),
        localKvProvider.overrideWith((ref) async => kv),
        viewerIdProvider.overrideWith((ref) async => 'u1'),
        meProvider.overrideWith((ref) => firstMe.future),
      ],
    );
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    expect(c.read(meProvider).asData, isNull);

    expect(await c.read(localeProvider.notifier).select('pcm'), isTrue);
    expect(repo.lastLocale, 'pcm');
    firstMe.complete(_me('fr'));
    await c.read(meProvider.future);
    expect(c.read(localeProvider), const Locale('pcm'));
  });

  test('a failed save reverts both the UI and the cache', () async {
    c = make();
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    await c.read(meProvider.future);
    await _settle();
    repo.localeError = const ApiException(status: 500, code: 'locale_save_failed', message: 'x');
    expect(await c.read(localeProvider.notifier).select('pcm'), isFalse);
    expect(c.read(localeProvider), const Locale('fr'));
    expect(kv.values['app.locale'], 'fr');
  });

  test('signed out: select is local only and makes no request', () async {
    signedIn = false;
    c = make();
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    await c.read(meProvider.future);
    expect(await c.read(localeProvider.notifier).select('fr'), isTrue);
    expect(repo.calls, isEmpty);
    expect(kv.values['app.locale'], 'fr');
  });

  test('a stale /me locale arriving after the user chose does not flip the app back', () async {
    c = make();
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    await c.read(localeProvider.notifier).select('pcm');
    await c.read(meProvider.future); // /me says 'fr' (stale)
    await _settle();
    expect(c.read(localeProvider), const Locale('pcm'));
  });

  test('rejects a locale the app does not ship', () async {
    c = make();
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    expect(await c.read(localeProvider.notifier).select('de'), isFalse);
    expect(repo.calls, isEmpty);
  });
}
