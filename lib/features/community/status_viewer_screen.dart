import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/community_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/utils/write_flow.dart';
import 'community_error_copy.dart';
import 'community_providers.dart';

/// Full-screen, one ring's statuses in order, tap-to-advance (right half next, left half back),
/// closing on advancing past the last status.
///
/// View tracking is best-effort per spec §4's `POST /community/statuses/{id}/view`: called once
/// per status actually shown this screen session (tracked in [_viewedIds], not per navigation, so
/// going back then forward again never re-fires it), and any failure is swallowed silently — the
/// contract is "never surfaces as an error", not "must succeed".
///
/// An expired status (`expiresAt` in the past — can still arrive if the ring was cached slightly
/// stale) is auto-advanced past without ever being shown or counted as viewed; the client never
/// invents new copy for this rare edge.
class StatusViewerScreen extends ConsumerStatefulWidget {
  const StatusViewerScreen({super.key, required this.ring, required this.onOpenViewers});
  final StatusRing ring;
  final void Function(String statusId) onOpenViewers;

  @override
  ConsumerState<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends ConsumerState<StatusViewerScreen> {
  int _index = 0;
  final _viewedIds = <String>{};
  final _deletedIds = <String>{};

  /// The ring's statuses minus any the author has deleted from inside this viewer.
  List<StatusRow> get _statuses => [for (final s in widget.ring.statuses) if (!_deletedIds.contains(s.id)) s];

  bool _isExpired(StatusRow status) => DateTime.parse(status.expiresAt).isBefore(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
  }

  /// Runs after every index change: pops once we've walked off either end, silently skips forward
  /// past an expired status (never calling `viewStatus` for it), or records the current status as
  /// viewed exactly once.
  void _settle() {
    if (!mounted) return;
    final statuses = _statuses;
    if (_index < 0 || _index >= statuses.length) {
      Navigator.of(context).maybePop();
      return;
    }
    final status = statuses[_index];
    if (_isExpired(status)) {
      setState(() => _index += 1);
      WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
      return;
    }
    if (_viewedIds.add(status.id)) {
      unawaited(_recordView(status.id));
    }
  }

  Future<void> _recordView(String id) async {
    // Captured up front: the viewer can be closed before the request lands, and the tray should
    // still learn that this ring has now been seen.
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await container.read(communityRepositoryProvider).viewStatus(id);
    } catch (_) {
      // Best-effort per spec — never surfaces as an error, and nothing changed server-side.
      return;
    }
    container.invalidate(communityStatusRingsProvider);
  }

  Future<void> _deleteCurrent(StatusRow status) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.cmtStatusDeleteConfirm),
        actions: [
          TextButton(key: const Key('status-delete-cancel'), onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cmtDeleteConfirmCancel)),
          TextButton(key: const Key('status-delete-confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.cmtDeleteConfirmYes)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final scope = 'delete-status:${status.id}';
    final ok = await ref.read(writeFlowProvider(scope).notifier).run((_) => ref.read(communityRepositoryProvider).deleteStatus(status.id));
    if (!mounted) return;
    if (!ok) {
      final code = ref.read(writeFlowProvider(scope)).errorCode ?? 'network';
      messenger.showSnackBar(SnackBar(content: Text(communityErrorCopy(l10n, code))));
      return;
    }
    container.invalidate(communityStatusRingsProvider);
    setState(() {
      _deletedIds.add(status.id);
      final remaining = _statuses.length;
      if (remaining > 0 && _index >= remaining) _index = remaining - 1;
    });
    // Closes the viewer when that was the last story; otherwise settles on the one now showing.
    WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
  }

  void _goNext() {
    setState(() => _index += 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
  }

  void _goBack() {
    if (_index == 0) return;
    setState(() => _index -= 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _statuses;
    if (_index < 0 || _index >= statuses.length) {
      // Out of range mid-pop (post-frame callback already scheduled by `_settle`) — render nothing
      // rather than index out of bounds.
      return const SizedBox.shrink();
    }
    final status = statuses[_index];
    final expired = _isExpired(status);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: expired
              ? const ColoredBox(key: Key('status-expired-placeholder'), color: Colors.black)
              : _StatusContent(status: status),
        ),
        Positioned.fill(
          child: Row(children: [
            Expanded(
              child: GestureDetector(
                key: const Key('status-viewer-back'),
                behavior: HitTestBehavior.translucent,
                onTap: _goBack,
              ),
            ),
            Expanded(
              child: GestureDetector(
                key: const Key('status-viewer-next'),
                behavior: HitTestBehavior.translucent,
                onTap: _goNext,
              ),
            ),
          ]),
        ),
        Positioned(
          top: 40,
          left: 16,
          right: 16,
          child: Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: widget.ring.authorAvatarUrl != null ? NetworkImage(widget.ring.authorAvatarUrl!) : null,
              child: widget.ring.authorAvatarUrl == null ? const Icon(Icons.person, size: 16) : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(widget.ring.authorName, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
            ),
            if (widget.ring.isSelf)
              IconButton(
                key: const Key('status-delete'),
                tooltip: AppLocalizations.of(context).cmtStatusDelete,
                onPressed: () => _deleteCurrent(status),
                icon: const Icon(Icons.delete_outline, color: Colors.white),
              ),
            if (widget.ring.isSelf)
              IconButton(
                key: const Key('status-open-viewers'),
                onPressed: () => widget.onOpenViewers(status.id),
                icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.white),
              ),
            IconButton(
              key: const Key('status-close'),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _StatusContent extends StatelessWidget {
  const _StatusContent({required this.status});
  final StatusRow status;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      if (status.imageUrl != null)
        Image.network(
          status.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
        )
      else
        const ColoredBox(color: Colors.black),
      if (status.caption != null)
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(status.caption!, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
          ),
        ),
    ]);
  }
}
