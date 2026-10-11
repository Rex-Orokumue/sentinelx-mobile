import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/account_screen.dart';
import 'package:sentinelx_mobile/features/store/store_providers.dart';
import 'package:sentinelx_mobile/features/store/store_screen.dart';

import '../fakes/fake_store_repository.dart';
import '../support/pump_app.dart';

MeResponse _staff() => const MeResponse(id: 'u1', email: 'm@test.dev', roles: ['moderator'], isStaff: true, isAdmin: false, profile: null);

Future<FakeStoreRepository> _open(WidgetTester tester, String location, {bool signedOut = false, MeResponse? me}) async {
  final repo = FakeStoreRepository();
  await pumpRouterWithRepo(tester, initialLocation: location, me: me, signedOut: signedOut, overrides: [
    viewerIdProvider.overrideWith((ref) async => signedOut ? null : 'u1'),
    storeRepositoryProvider.overrideWithValue(repo),
  ]);
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('/account/store opens the store for a player', (tester) async {
    await _open(tester, '/account/store');
    expect(find.byType(StoreScreen), findsOneWidget);
  });

  testWidgets('a moderator keeps the store (it is gameplay, not money)', (tester) async {
    await _open(tester, '/account/store', me: _staff());
    expect(find.byType(StoreScreen), findsOneWidget);
  });

  testWidgets('a signed-out visitor can browse the public catalogue', (tester) async {
    final repo = await _open(tester, '/account/store', signedOut: true);
    expect(find.byType(StoreScreen), findsOneWidget);
    expect(repo.calls, contains('catalogue'));
  });

  testWidgets('the Account hub opens the store for players and for moderators', (tester) async {
    await _open(tester, '/account');
    await tester.tap(find.byKey(const Key('account-store')));
    await tester.pumpAndSettle();
    expect(find.byType(StoreScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _open(tester, '/account', me: _staff());
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.byKey(const Key('account-store')), findsOneWidget);
  });

  testWidgets('a web store link resolves to the in-app store', (tester) async {
    await _open(tester, 'https://sentinelxesports.com.ng/store');
    expect(find.byType(StoreScreen), findsOneWidget);
  });
}
