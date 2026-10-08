import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/account/settings/google_linker.dart';

void main() {
  test('a browser launcher that cannot open returns a link failure', () async {
    final linker = SupabaseGoogleLinker(() async => false);
    await expectLater(linker.link(), throwsStateError);
  });

  test('a browser launcher that opens completes the link attempt', () async {
    final linker = SupabaseGoogleLinker(() async => true);
    await linker.link();
  });
}
