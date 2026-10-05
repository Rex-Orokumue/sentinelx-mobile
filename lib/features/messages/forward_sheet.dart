import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../shared/widgets/player_avatar.dart';
import 'inbox_providers.dart';

/// Lists the viewer's inbox threads (never the current one) and closes with the chosen thread id. Whether the
/// target can receive the message (a pending request, a block) is the server's call, shown after the attempt.
class ForwardSheet extends ConsumerStatefulWidget {
  const ForwardSheet({super.key, required this.currentThreadId});

  final String currentThreadId;

  @override
  ConsumerState<ForwardSheet> createState() => _ForwardSheetState();
}

class _ForwardSheetState extends ConsumerState<ForwardSheet> {
  bool _picked = false;

  void _pick(String id) {
    if (_picked) return;
    _picked = true;
    Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(inboxProvider);
    final threads = [for (final t in async.asData?.value.threads ?? const []) if (t.threadId != widget.currentThreadId) t];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Text(l10n.dmForwardTitle, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (async.isLoading && !async.hasValue)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (threads.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(l10n.dmForwardEmpty, key: const Key('dm-forward-empty')))
          else
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final t in threads)
                  ListTile(
                    key: Key('dm-forward-${t.threadId}'),
                    leading: PlayerAvatar(avatarUrl: t.other.avatarUrl, size: 36),
                    title: Text(t.other.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => _pick(t.threadId),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}
