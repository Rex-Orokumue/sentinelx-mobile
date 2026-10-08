import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';

import '../../../fakes/fake_account_repository.dart';

void main() {
  ProviderContainer container(FakeAccountRepository repo, {String? viewer = 'u1'}) => ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          accountRepositoryProvider.overrideWithValue(repo),
          viewerIdProvider.overrideWith((ref) async => viewer),
        ],
      );

  test('myAccountProvider loads the account for a signed-in viewer', () async {
    final repo = FakeAccountRepository();
    final c = container(repo);
    addTearDown(c.dispose);
    final a = await c.read(myAccountProvider.future);
    expect(a!.signIn.email, 'ada@example.com');
    expect(repo.calls, ['account']);
  });

  test('myAccountProvider is null and makes no request when signed out', () async {
    final repo = FakeAccountRepository();
    final c = container(repo, viewer: null);
    addTearDown(c.dispose);
    expect(await c.read(myAccountProvider.future), isNull);
    expect(repo.calls, isEmpty);
  });
}
