import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/players_models.dart';
import '../../core/providers.dart';
import 'progress_repository.dart';

final progressRepositoryProvider =
    Provider<ProgressRepository>((ref) => ApiProgressRepository(ref.watch(apiClientProvider)));

/// Signed out -> null WITHOUT calling the API.
final progressProvider = FutureProvider.autoDispose<MyProgress?>((ref) async {
  final me = await ref.watch(meProvider.future);
  if (me == null) return null;
  return ref.watch(progressRepositoryProvider).progress();
});
