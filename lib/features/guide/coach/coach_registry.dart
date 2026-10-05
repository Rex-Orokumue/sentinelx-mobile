import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachTargetRegistry {
  final _keys = <String, GlobalKey>{};
  GlobalKey keyFor(String id) => _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'coach:$id'));
  Rect? rectFor(String id) {
    final ctx = _keys[id]?.currentContext;
    final box = ctx?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

final coachRegistryProvider = Provider<CoachTargetRegistry>((_) => CoachTargetRegistry());

class CoachTarget extends ConsumerWidget {
  const CoachTarget({super.key, required this.id, required this.child});
  final String id;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => KeyedSubtree(key: ref.read(coachRegistryProvider).keyFor(id), child: child);
}
