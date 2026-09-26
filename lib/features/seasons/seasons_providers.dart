import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/progress_models.dart';
import '../../core/providers.dart';
import 'seasons_repository.dart';

final seasonsRepositoryProvider = Provider<SeasonsRepository>(
  (r) => ApiSeasonsRepository(r.watch(apiClientProvider)),
);
final seasonsProvider = FutureProvider.autoDispose<List<SeasonSummary>>(
  (r) => r.watch(seasonsRepositoryProvider).list(),
);
final seasonDetailProvider = FutureProvider.autoDispose
    .family<SeasonDetail, String>(
      (r, s) => r.watch(seasonsRepositoryProvider).detail(s),
    );
