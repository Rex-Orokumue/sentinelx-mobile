import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../realtime/realtime_hub.dart' show AppLifecycleSource, WidgetsLifecycleSource;

/// The same lifecycle abstraction the realtime hub uses, exposed as a provider so features other than realtime
/// (chat interruption, quest refresh on resume) can react to pause/resume. Tests override it with `FakeLifecycle`.
final appLifecycleSourceProvider = Provider<AppLifecycleSource>((ref) {
  final source = WidgetsLifecycleSource();
  ref.onDispose(source.dispose);
  return source;
});
