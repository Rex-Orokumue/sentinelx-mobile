import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import 'community_error_copy.dart';
import 'community_providers.dart';

/// The author-only "who viewed my story" list. Only ever reachable from
/// `StatusViewerScreen`'s viewers entry point, which itself only renders for `ring.isSelf` — this
/// screen doesn't re-check that (spec §3: authorization is server-enforced, the `statusId` family
/// key is opaque to a client that reached it any other way).
class StatusViewersScreen extends ConsumerWidget {
  const StatusViewersScreen({super.key, required this.statusId});
  final String statusId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final viewersAsync = ref.watch(communityStatusViewersProvider(statusId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cmtStatusViewersTitle)),
      body: viewersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(communityErrorCopy(l10n, ''))),
        data: (viewers) {
          if (viewers.isEmpty) {
            return Center(child: Text(l10n.cmtStatusViewersEmpty));
          }
          return ListView.builder(
            itemCount: viewers.length,
            itemBuilder: (context, index) {
              final viewer = viewers[index];
              return ListTile(
                key: Key('status-viewer-${viewer.viewerId}'),
                leading: CircleAvatar(
                  backgroundImage: viewer.avatarUrl != null ? NetworkImage(viewer.avatarUrl!) : null,
                  child: viewer.avatarUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(viewer.name),
                subtitle: viewer.username != null ? Text('@${viewer.username}') : null,
              );
            },
          );
        },
      ),
    );
  }
}
