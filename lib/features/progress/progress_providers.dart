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

const _keep = Object();

class HistoryState<T> {
  const HistoryState({required this.items, required this.nextCursor, this.loadingMore = false, this.loadMoreFailed = false});
  final List<T> items;
  final String? nextCursor;
  final bool loadingMore;
  final bool loadMoreFailed;

  HistoryState<T> copyWith({List<T>? items, Object? nextCursor = _keep, bool? loadingMore, bool? loadMoreFailed}) => HistoryState(
        items: items ?? this.items,
        nextCursor: identical(nextCursor, _keep) ? this.nextCursor : nextCursor as String?,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

class HistoryNotifier<T> extends AsyncNotifier<HistoryState<T>> {
  HistoryNotifier(this._fetch, this._idOf);
  final Future<HistoryPage<T>> Function(Ref ref, String? cursor) _fetch;
  final String Function(T) _idOf;

  @override
  Future<HistoryState<T>> build() async {
    final me = await ref.watch(meProvider.future);
    if (me == null) return HistoryState<T>(items: const [], nextCursor: null);
    final page = await _fetch(ref, null);
    return HistoryState<T>(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> loadMore({bool retry = false}) async {
    final s = state.value;
    if (s == null || s.nextCursor == null || s.loadingMore) return;
    if (s.loadMoreFailed && !retry) return; // never auto-loop after a failure
    state = AsyncData(s.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final page = await _fetch(ref, s.nextCursor);
      final seen = s.items.map(_idOf).toSet();
      state = AsyncData(HistoryState<T>(
        items: [...s.items, ...page.items.where((e) => !seen.contains(_idOf(e)))],
        nextCursor: page.nextCursor,
      ));
    } catch (_) {
      state = AsyncData(s.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }
}

final xpHistoryProvider = AsyncNotifierProvider.autoDispose<HistoryNotifier<XpEvent>, HistoryState<XpEvent>>(
  () => HistoryNotifier<XpEvent>((ref, c) => ref.read(progressRepositoryProvider).xp(c), (e) => e.id),
);
final scoreHistoryProvider = AsyncNotifierProvider.autoDispose<HistoryNotifier<SxScoreEvent>, HistoryState<SxScoreEvent>>(
  () => HistoryNotifier<SxScoreEvent>((ref, c) => ref.read(progressRepositoryProvider).score(c), (e) => e.id),
);
final coinHistoryProvider = AsyncNotifierProvider.autoDispose<HistoryNotifier<CoinTransaction>, HistoryState<CoinTransaction>>(
  () => HistoryNotifier<CoinTransaction>((ref, c) => ref.read(progressRepositoryProvider).coins(c), (e) => e.id),
);
