import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/sx_colors.dart';
import '../guide_mascot.dart';
import 'coach_controller.dart';
import 'coach_registry.dart';
import 'coach_tours.dart';

/// Starts [tour] once after the first frame and paints its overlay while it runs. Other hosts' tours are ignored,
/// so Home and the shell can each mount one.
class CoachHost extends ConsumerStatefulWidget {
  const CoachHost({super.key, required this.tour, required this.child});

  final CoachTour tour;
  final Widget child;

  @override
  ConsumerState<CoachHost> createState() => _CoachHostState();
}

class _CoachHostState extends ConsumerState<CoachHost> with WidgetsBindingObserver {
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(coachControllerProvider.notifier).maybeStart(widget.tour);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeEntry();
    super.dispose();
  }

  /// The system back button closes the tour (and marks it seen) instead of leaving the screen.
  @override
  Future<bool> didPopRoute() async {
    if (_entry == null) return false;
    ref.read(coachControllerProvider.notifier).skip();
    return true;
  }

  bool _mine(CoachState s) => s.tour?.id == widget.tour.id;

  void _removeEntry() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  void _sync(CoachState state) {
    // Overlay changes must not happen during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_mine(state)) {
        _removeEntry();
        return;
      }
      if (_entry == null) {
        final overlay = Overlay.maybeOf(context, rootOverlay: true);
        if (overlay == null) return;
        _entry = OverlayEntry(builder: (_) => _CoachOverlay(tourId: widget.tour.id));
        overlay.insert(_entry!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(coachControllerProvider, (_, next) => _sync(next));
    return widget.child;
  }
}

class _CoachOverlay extends ConsumerWidget {
  const _CoachOverlay({required this.tourId});

  final String tourId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(coachControllerProvider);
    final tour = state.tour;
    if (tour == null || tour.id != tourId) return const SizedBox.shrink();
    final step = tour.steps[state.index];
    final rect = ref.read(coachRegistryProvider).rectFor(step.targetId);
    if (rect == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(coachControllerProvider.notifier);
    final size = MediaQuery.sizeOf(context);
    final hole = RRect.fromRectAndRadius(rect.inflate(6), const Radius.circular(12));
    final below = rect.center.dy < size.height / 2;
    final isLast = state.index == _lastIndex(ref, tour);
    final shown = _shownIndexes(ref, tour);
    final position = shown.indexOf(state.index) + 1;
    final callout = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const GuideMascot(size: 36),
            const SizedBox(width: 12),
            Expanded(child: Text(step.title(l10n), style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 8),
          Text(step.body(l10n)),
          const SizedBox(height: 12),
          Row(children: [
            Text(l10n.coachStepOf(position, shown.length), style: const TextStyle(color: SxColors.textSecondary)),
            const Spacer(),
            TextButton(key: const Key('coach-skip'), onPressed: controller.skip, child: Text(l10n.coachSkip)),
            const SizedBox(width: 8),
            FilledButton(key: const Key('coach-next'), onPressed: controller.next, child: Text(isLast ? l10n.coachDone : l10n.coachNext)),
          ]),
        ]),
      ),
    );
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: step.title(l10n),
      child: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // the scrim swallows taps; only the buttons move the tour
            child: CustomPaint(painter: _ScrimPainter(hole)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: below ? hole.bottom + 12 : null,
          bottom: below ? null : size.height - hole.top + 12,
          child: callout,
        ),
      ]),
    );
  }

  List<int> _shownIndexes(WidgetRef ref, CoachTour tour) {
    final reg = ref.read(coachRegistryProvider);
    return [for (var i = 0; i < tour.steps.length; i++) if (reg.rectFor(tour.steps[i].targetId) != null) i];
  }

  int _lastIndex(WidgetRef ref, CoachTour tour) {
    final shown = _shownIndexes(ref, tour);
    return shown.isEmpty ? -1 : shown.last;
  }
}

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter(this.hole);

  final RRect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(hole),
    );
    canvas.drawPath(path, Paint()..color = SxColors.background.withValues(alpha: 0.82));
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}
