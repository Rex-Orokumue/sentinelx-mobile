import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/progress_models.dart';
import '../../core/providers.dart';
import 'hall_of_fame_repository.dart';

final hallOfFameRepositoryProvider = Provider<HallOfFameRepository>(
  (r) => ApiHallOfFameRepository(r.watch(apiClientProvider)),
);

class HallOfFameGameNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setGame(String? g) => state = g;
}

final hallOfFameGameProvider =
    NotifierProvider.autoDispose<HallOfFameGameNotifier, String?>(
      HallOfFameGameNotifier.new,
    );
final hallOfFameProvider = FutureProvider.autoDispose<HallOfFame>(
  (r) => r
      .watch(hallOfFameRepositoryProvider)
      .fetch(game: r.watch(hallOfFameGameProvider)),
);
