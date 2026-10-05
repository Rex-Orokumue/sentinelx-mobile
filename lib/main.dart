import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/notifications/push/firebase_push_gateway.dart';
import 'core/notifications/push/push_bootstrap.dart';
import 'core/notifications/push/push_gateway.dart';
import 'core/notifications/push/push_registration.dart';
import 'core/providers.dart';
import 'core/routing/incoming_links.dart';
import 'core/session/session_lifecycle.dart';
import 'features/compete/paystack_checkout.dart';
import 'features/compete/registration_flow.dart';
import 'features/messages/delivery_watcher.dart';
import 'features/messages/presence_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const config = AppConfig.fromEnvironment();
  final info = await PackageInfo.fromPlatform();
  await Supabase.initialize(url: config.supabaseUrl, publishableKey: config.supabasePublishableKey);
  // Never throws: without a Firebase config the app starts normally with push off.
  final pushGateway = await FirebasePushGateway.tryInitialize();

  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      installedVersionProvider.overrideWithValue(info.version),
      pushGatewayProvider.overrideWithValue(pushGateway),
      paystackLauncherProvider.overrideWith(paystackLauncherFromRouter),
    ],
  );
  final reporter = container.read(errorReporterProvider);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reporter.report(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.report(error, stack);
    return true;
  };

  runApp(UncontrolledProviderScope(container: container, child: const SentinelXApp()));

  // listen, not read: Riverpod 3 pauses a provider's own ref.listen subscriptions
  // while nothing is listening to that provider, so a bare read would never fire.
  container.listen(sessionLifecycleProvider, (_, _) {});
  container.read(incomingLinkListenerProvider);
  container.listen(pushRegistrationProvider, (_, _) {});
  container.listen(pushBootstrapProvider, (_, _) {});
  // Online presence is app-wide while the app is resumed (the hub drops the channel on pause).
  container.listen(onlinePlayersProvider, (_, _) {});
  // Delivery receipts do not wait for an inbox or conversation to be open.
  container.listen(deliveryWatcherProvider, (_, _) {});
}
