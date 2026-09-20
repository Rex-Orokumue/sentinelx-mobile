import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/auth/forgot_password_screen.dart';

import 'auth_test_fakes.dart';

void main() {
  testWidgets('sends a reset request and shows the neutral notice', (tester) async {
    final repo = FakeAuthRepositoryForForgot();
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ForgotPasswordScreen(),
      ),
    ));

    await tester.enterText(find.byKey(const Key('forgot-email')), 'a@b.com');
    await tester.tap(find.byKey(const Key('forgot-submit')));
    await tester.pumpAndSettle();

    expect(repo.lastEmail, 'a@b.com');
    expect(find.text("If an account exists for that email, we've sent a reset link."), findsOneWidget);
  });
}
