import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api/api_client.dart';
import 'api/models.dart';
import 'config/app_config.dart';
import 'config/remote_config.dart';
import 'errors/error_reporter.dart';

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig.fromEnvironment());

/// Overridden in main() with PackageInfo.version, and in tests.
final installedVersionProvider =
    Provider<String>((ref) => throw UnimplementedError('Override installedVersionProvider'));

final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final sessionProvider = StreamProvider<Session?>((ref) async* {
  final auth = ref.watch(supabaseClientProvider).auth;
  yield auth.currentSession;
  yield* auth.onAuthStateChange.map((state) => state.session);
});

String get _platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final supabase = ref.watch(supabaseClientProvider);
  return ApiClient.create(
    baseUrl: config.apiBaseUrl,
    appVersion: ref.watch(installedVersionProvider),
    platform: _platform,
    accessToken: () async => supabase.auth.currentSession?.accessToken,
  );
});

/// Null on any failure: a config fetch problem must never lock users out (see evaluateGate).
final remoteConfigProvider = FutureProvider<RemoteConfig?>((ref) async {
  try {
    return await ref.watch(apiClientProvider).getConfig();
  } catch (_) {
    return null;
  }
});

/// The signed-in user with roles; null when signed out.
final meProvider = FutureProvider<MeResponse?>((ref) async {
  final session = ref.watch(sessionProvider).asData?.value;
  if (session == null) return null;
  return ref.watch(apiClientProvider).getMe();
});

enum AppRole { player, moderator, admin }

/// Drives the role-aware Admin entry point. Display only — every admin API call re-checks server-side.
final roleProvider = Provider<AppRole?>((ref) {
  final me = ref.watch(meProvider).asData?.value;
  if (me == null) return null;
  if (me.isAdmin) return AppRole.admin;
  if (me.isStaff) return AppRole.moderator;
  return AppRole.player;
});

final errorReporterProvider = Provider<ErrorReporter>((ref) {
  final version = ref.watch(installedVersionProvider);
  return ErrorReporter((message, stack, route) => ref.read(apiClientProvider).postClientError(
        message: message,
        stack: stack,
        route: route,
        platform: _platform,
        appVersion: version,
      ));
});
