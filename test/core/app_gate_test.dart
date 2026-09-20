import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/config/remote_config.dart';
import 'package:sentinelx_mobile/core/gate/app_gate.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';

RemoteConfig _config({String min = '0.0.0', String? maintenance}) => RemoteConfig.fromJson({
      'minSupportedAppVersion': min,
      'latestAppVersion': '9.9.9',
      'maintenance': maintenance == null ? null : {'message': maintenance},
      'siteUrl': 'https://sentinelxesports.com.ng',
      'coins': {'coinsPerNaira': 2, 'nairaPerCoin': 0.5, 'coinsPerEntry': 1000, 'coinsHalfEntry': 500},
      'enforcePhoneVerification': false,
      'whatsappCommunityUrl': null,
      'features': <String, bool>{},
    });

Future<void> _pump(WidgetTester tester, {required RemoteConfig? config, String installed = '1.0.0'}) {
  return tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      installedVersionProvider.overrideWithValue(installed),
      remoteConfigProvider.overrideWith((ref) async => config),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AppGate(child: Text('APP')),
    ),
  ));
}

void main() {
  testWidgets('shows the app while the config is still loading', (tester) async {
    await _pump(tester, config: _config());
    expect(find.text('APP'), findsOneWidget);
  });

  testWidgets('shows the app when the version is supported', (tester) async {
    await _pump(tester, config: _config(min: '1.0.0'));
    await tester.pumpAndSettle();
    expect(find.text('APP'), findsOneWidget);
  });

  testWidgets('blocks with the update screen below the minimum version', (tester) async {
    await _pump(tester, config: _config(min: '2.0.0'), installed: '1.9.9');
    await tester.pumpAndSettle();
    expect(find.text('APP'), findsNothing);
    expect(find.text('Update required'), findsOneWidget);
    expect(find.textContaining('2.0.0'), findsOneWidget);
  });

  testWidgets('blocks with the maintenance screen and shows the server message', (tester) async {
    await _pump(tester, config: _config(maintenance: 'Back at 3pm'));
    await tester.pumpAndSettle();
    expect(find.text('APP'), findsNothing);
    expect(find.text("We'll be right back"), findsOneWidget);
    expect(find.text('Back at 3pm'), findsOneWidget);
  });

  testWidgets('a failed config fetch never locks the user out', (tester) async {
    await _pump(tester, config: null);
    await tester.pumpAndSettle();
    expect(find.text('APP'), findsOneWidget);
  });
}
