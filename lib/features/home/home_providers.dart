import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) => ApiHomeRepository(ref.watch(apiClientProvider)));

final homeProvider = FutureProvider.autoDispose((ref) => ref.watch(homeRepositoryProvider).fetchHome());

// Fires POST /session/start once per signed-in session (spec §2: "once per
// app process after a session exists", never on every screen visit).
// keepAlive so re-entering Home doesn't re-fire it for the same session.
final sessionStartedProvider = FutureProvider<void>((ref) async {
  final session = ref.watch(sessionProvider).asData?.value;
  if (session == null) return;
  await ref.watch(apiClientProvider).postSessionStart();
});
