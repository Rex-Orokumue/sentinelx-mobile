import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/storage/local_kv.dart';
import 'coach_registry.dart';
import 'coach_tours.dart';

class CoachState {
  const CoachState({this.tour, this.index = 0});
  final CoachTour? tour;
  final int index;
  bool get running => tour != null;
}

class CoachController extends Notifier<CoachState> {
  @override
  CoachState build() => const CoachState();

  Future<String> _scope() async {
    final viewer = await ref.read(viewerIdProvider.future);
    return viewer ?? 'guest';
  }
  String _key(String scope, CoachTour t) => 'coach.$scope.${t.id}';

  int? _firstPresent(CoachTour t, int from) {
    final reg = ref.read(coachRegistryProvider);
    for (var i = from; i < t.steps.length; i++) {
      if (reg.rectFor(t.steps[i].targetId) != null) return i;
    }
    return null;
  }

  Future<void> maybeStart(CoachTour tour) async {
    if (state.running) return;
    try {
      final scope = await _scope();
      final kv = await ref.read(localKvProvider.future);
      if (!ref.mounted || state.running) return;
      if (await kv.read(_key(scope, tour)) != null) return;
      final first = _firstPresent(tour, 0);
      if (first == null) return; // same-page only: nothing to point at, and it stays unseen
      state = CoachState(tour: tour, index: first);
    } catch (_) {
      // storage trouble must never block the app
    }
  }

  void next() {
    final t = state.tour;
    if (t == null) return;
    final n = _firstPresent(t, state.index + 1);
    if (n == null) {
      _finish(t);
    } else {
      state = CoachState(tour: t, index: n);
    }
  }

  void skip() {
    final t = state.tour;
    if (t != null) _finish(t);
  }

  void _finish(CoachTour t) {
    state = const CoachState();
    _markSeen(t);
  }

  Future<void> _markSeen(CoachTour t) async {
    try {
      final scope = await _scope();
      final kv = await ref.read(localKvProvider.future);
      await kv.write(_key(scope, t), '1');
    } catch (_) {}
  }

  Future<void> resetAll() async {
    try {
      final scope = await _scope();
      final kv = await ref.read(localKvProvider.future);
      for (final t in [homeTour, shellTour]) {
        await kv.remove(_key(scope, t));
      }
    } catch (_) {}
  }
}

final coachControllerProvider = NotifierProvider<CoachController, CoachState>(CoachController.new);
