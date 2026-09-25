import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/providers.dart';
import 'core/routing/incoming_links.dart';
import 'core/session/session_lifecycle.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const config = AppConfig.fromEnvironment();
  final info = await PackageInfo.fromPlatform();
  await Supabase.initialize(url: config.supabaseUrl, publishableKey: config.supabasePublishableKey);

  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [installedVersionProvider.overrideWithValue(info.version)],
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
}
