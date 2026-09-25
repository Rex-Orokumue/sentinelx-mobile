import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/routing/incoming_links.dart';
import 'package:sentinelx_mobile/router/app_router.dart';

class _FakeAuth implements GoTrueClient {
  @override
  Future<AuthResponse> verifyOTP({
    String? email,
    String? phone,
    String? token,
    required OtpType type,
    String? redirectTo,
    String? captchaToken,
    String? tokenHash,
  }) async => AuthResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('isAuthConfirmPath', () {
    test('matches the bare path', () {
      expect(isAuthConfirmPath(Uri.parse('https://sentinelxesports.com.ng/auth/confirm?token_hash=x&type=signup')), isTrue);
    });
    test('matches a locale-prefixed path', () {
      expect(isAuthConfirmPath(Uri.parse('https://sentinelxesports.com.ng/fr/auth/confirm?token_hash=x&type=signup')), isTrue);
    });
    test('does not match other paths', () {
      expect(isAuthConfirmPath(Uri.parse('https://sentinelxesports.com.ng/tournaments')), isFalse);
    });
  });

  group('handleIncomingLink routes by outcome', () {
    // The router only parses a location once a widget tree is attached to it.
    Future<String> landing(WidgetTester tester, String type) async {
      final router = buildAppRouter();
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();
      await handleIncomingLink(
        Uri.parse('https://sentinelxesports.com.ng/auth/confirm?token_hash=a&type=$type'),
        router: router,
        auth: _FakeAuth(),
      );
      await tester.pumpAndSettle();
      return router.routerDelegate.currentConfiguration.uri.toString();
    }

    testWidgets('signup confirmation goes straight to onboarding/username', (tester) async {
      expect(await landing(tester, 'signup'), '/onboarding/username');
    });

    testWidgets('an email-change confirmation goes Home, not onboarding', (tester) async {
      expect(await landing(tester, 'email_change'), '/');
    });

    testWidgets('a recovery link goes to reset-password', (tester) async {
      expect(await landing(tester, 'recovery'), '/reset-password');
    });
  });
}
