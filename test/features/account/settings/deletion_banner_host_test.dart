import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/account_models.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/deletion_banner_host.dart';

import '../../../fakes/fake_account_repository.dart';

MeResponse _me(String? requested) => MeResponse(
      id: 'u1', email: 'a@b.com', roles: const [], isStaff: false, isAdmin: false,
      profile: MeProfile(
        username: 'ada', displayName: 'Ada', avatarUrl: null, whatsappNumber: null, country: null, locale: 'en',
        membershipTier: null, kycVerified: false, deletionRequestedAt: requested,
      ),
    );

class _Probe extends StatefulWidget {
  const _Probe();
  static int initCount = 0;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.initCount++;
  }

  @override
  Widget build(BuildContext context) => const Text('APP');
}

class _PendingNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
}

final _pending = NotifierProvider<_PendingNotifier, String?>(_PendingNotifier.new);

Future<ProviderContainer> _pump(WidgetTester tester, FakeAccountRepository repo, String? requested) async {
  _Probe.initCount = 0;
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      accountRepositoryProvider.overrideWithValue(repo),
      viewerIdProvider.overrideWith((ref) async => 'u1'),
      meProvider.overrideWith((ref) async => _me(ref.watch(_pending) ?? requested)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => DeletionBannerHost(child: child!),
      home: const _Probe(),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('no banner when no deletion is pending', (tester) async {
    await _pump(tester, FakeAccountRepository(), null);
    expect(find.byKey(const Key('deletion-banner')), findsNothing);
    expect(find.text('APP'), findsOneWidget);
  });

  testWidgets('a pending deletion shows the countdown and Cancel deletion refreshes both providers', (tester) async {
    final repo = FakeAccountRepository()
      ..accountResult = testAccount(
        deletion: DeletionState(requestedAt: DateTime.utc(2026, 10, 5), dueAt: DateTime.utc(2026, 10, 20), daysRemaining: 13),
      );
    await _pump(tester, repo, '2026-10-05T00:00:00.000Z');
    expect(find.byKey(const Key('deletion-banner')), findsOneWidget);
    repo.accountResult = testAccount();
    await tester.tap(find.byKey(const Key('deletion-banner-cancel')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('cancelDeletion'));
  });

  testWidgets('the app content is never rebuilt as the banner appears or disappears (navigation state survives)', (tester) async {
    final repo = FakeAccountRepository();
    final container = await _pump(tester, repo, null);
    expect(_Probe.initCount, 1);
    container.read(_pending.notifier).set('2026-10-05T00:00:00.000Z');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deletion-banner')), findsOneWidget);
    expect(_Probe.initCount, 1, reason: 'the child must keep its State');
    container.read(_pending.notifier).set(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deletion-banner')), findsNothing);
    expect(_Probe.initCount, 1, reason: 'and still after the banner goes away');
  });
}
