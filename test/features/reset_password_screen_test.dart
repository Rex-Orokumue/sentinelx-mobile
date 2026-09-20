import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/auth/reset_password_screen.dart';

import 'auth_test_fakes.dart';

class _RecordingReset extends FakeAuthRepositoryForForgot {
  String? lastPassword;
  @override
  Future<void> resetPassword(String newPassword) async => lastPassword = newPassword;
}

void main() {
  testWidgets('submits the new password and calls onDone', (tester) async {
    final repo = _RecordingReset();
    var done = false;
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ResetPasswordScreen(onDone: () => done = true),
      ),
    ));

    await tester.enterText(find.byKey(const Key('reset-password')), 'newpassword123');
    await tester.tap(find.byKey(const Key('reset-submit')));
    await tester.pumpAndSettle();

    expect(repo.lastPassword, 'newpassword123');
    expect(done, isTrue);
  });
}
