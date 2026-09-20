import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/providers.dart';

MeResponse _me({bool staff = false, bool admin = false}) =>
    MeResponse(id: 'u', email: null, roles: const [], isStaff: staff, isAdmin: admin, profile: null);

Future<AppRole?> _roleFor(MeResponse? me) async {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [meProvider.overrideWith((ref) async => me)],
  );
  addTearDown(container.dispose);
  await container.read(meProvider.future);
  return container.read(roleProvider);
}

void main() {
  test('signed out has no role', () async => expect(await _roleFor(null), isNull));
  test('a plain user is a player', () async => expect(await _roleFor(_me()), AppRole.player));
  test('staff who is not admin is a moderator', () async => expect(await _roleFor(_me(staff: true)), AppRole.moderator));
  test('an admin is an admin', () async => expect(await _roleFor(_me(staff: true, admin: true)), AppRole.admin));
}
