import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  test('the installed google_sign_in exposes the v7+ singleton API this plan targets', () {
    // v7+: GoogleSignIn.instance is a singleton with .initialize()/.authenticate().
    // If this fails to compile, the installed version is 6.x instead — switch
    // Step 3's implementation to `GoogleSignIn(serverClientId: ...).signIn()`
    // (the v6 instance-based API) and note the version pin in pubspec.yaml.
    expect(GoogleSignIn.instance, isNotNull);
  });
}
