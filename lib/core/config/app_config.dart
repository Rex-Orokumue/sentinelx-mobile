class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.apiBaseUrl,
    required this.debugTools,
  });

  /// Build-time config. Override with `--dart-define` or `--dart-define-from-file=config/dev.json`.
  /// Defaults are the production public values so a bare `flutter run` works; the publishable
  /// key is public by design (same value ships in the web bundle).
  const factory AppConfig.fromEnvironment() = _EnvAppConfig;

  final String flavor;
  final String supabaseUrl;
  final String supabasePublishableKey;
  final String apiBaseUrl;
  final bool debugTools;

  bool get isDev => flavor == 'dev';
}

class _EnvAppConfig extends AppConfig {
  const _EnvAppConfig()
      : super(
          flavor: const String.fromEnvironment('FLAVOR', defaultValue: 'prod'),
          supabaseUrl: const String.fromEnvironment(
            'SUPABASE_URL',
            defaultValue: 'https://itxubrkbropttfdackmi.supabase.co',
          ),
          supabasePublishableKey: const String.fromEnvironment(
            'SUPABASE_PUBLISHABLE_KEY',
            defaultValue: 'sb_publishable_bsIF_bY19uFCno5BjS4sMQ_PiEbY6zs',
          ),
          apiBaseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://sentinelxesports.com.ng'),
          debugTools: const bool.fromEnvironment('DEBUG_TOOLS'),
        );
}
