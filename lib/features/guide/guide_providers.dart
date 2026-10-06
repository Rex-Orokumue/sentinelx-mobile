import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/guide_models.dart';
import '../../core/providers.dart';
import '../progress/progress_providers.dart' show progressProvider; // adjust the import to where `progressProvider` is defined
import 'guide_repository.dart';

final questsProvider = FutureProvider.autoDispose<List<Quest>>((ref) async {
  final viewer = await ref.watch(viewerIdProvider.future);
  if (viewer == null) return const [];
  return ref.watch(guideRepositoryProvider).quests();
});

Quest? battleReady(List<Quest> quests) {
  for (final q in quests) {
    if (q.id == 'battle_ready') return q;
  }
  return null;
}

enum ClaimPhase { idle, claiming, claimed, failed }

class ClaimState {
  const ClaimState({this.phase = ClaimPhase.idle, this.errorCode, this.result});
  final ClaimPhase phase;
  final String? errorCode;
  final BadgeClaim? result;
}

class ClaimBadgeNotifier extends Notifier<ClaimState> {
  @override
  ClaimState build() => const ClaimState();

  Future<void> claim() async {
    if (state.phase == ClaimPhase.claiming) return;
    state = const ClaimState(phase: ClaimPhase.claiming);
    try {
      final result = await ref.read(guideRepositoryProvider).claim();
      if (!ref.mounted) return;
      state = ClaimState(phase: ClaimPhase.claimed, result: result);
      ref.invalidate(questsProvider);
      ref.invalidate(progressProvider); // XP and coins changed
    } catch (e) {
      if (!ref.mounted) return;
      state = ClaimState(phase: ClaimPhase.failed, errorCode: e is ApiException ? (e.isUnauthorized ? 'unauthorized' : e.code) : 'network');
    }
  }
}

final claimBadgeProvider = NotifierProvider.autoDispose<ClaimBadgeNotifier, ClaimState>(ClaimBadgeNotifier.new);
