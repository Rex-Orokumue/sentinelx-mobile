import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/config/app_config.dart';

void main() {
  test('defaults to the prod flavor pointing at production with debug tools off', () {
    const config = AppConfig.fromEnvironment();
    expect(config.flavor, 'prod');
    expect(config.isDev, isFalse);
    expect(config.supabaseUrl, 'https://itxubrkbropttfdackmi.supabase.co');
    expect(config.apiBaseUrl, 'https://sentinelxesports.com.ng');
    expect(config.debugTools, isFalse);
  });

  test('isDev reflects the flavor', () {
    const dev = AppConfig(
      flavor: 'dev',
      supabaseUrl: 'u',
      supabasePublishableKey: 'k',
      apiBaseUrl: 'http://10.0.2.2:3000',
      debugTools: true,
    );
    expect(dev.isDev, isTrue);
    expect(dev.debugTools, isTrue);
  });
}
