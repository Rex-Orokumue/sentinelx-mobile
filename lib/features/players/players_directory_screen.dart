import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../shared/widgets/player_avatar.dart';
import '../progress/history_labels.dart';
import 'players_providers.dart';

class PlayersDirectoryScreen extends ConsumerStatefulWidget {
  const PlayersDirectoryScreen({super.key, required this.onPlayerTap, this.debounce = const Duration(milliseconds: 300)});

  final void Function(String username) onPlayerTap;
  final Duration debounce;

  @override
  ConsumerState<PlayersDirectoryScreen> createState() => _PlayersDirectoryScreenState();
}

class _PlayersDirectoryScreenState extends ConsumerState<PlayersDirectoryScreen> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onChanged(String text) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => ref.read(playerSearchQueryProvider.notifier).set(text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final results = ref.watch(playerSearchProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.playersTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('players-search'),
              decoration: InputDecoration(hintText: l10n.playersSearchHint, prefixIcon: const Icon(Icons.search)),
              onChanged: _onChanged,
            ),
          ),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(onPressed: () => ref.invalidate(playerSearchProvider), child: Text(l10n.commonLoadError)),
              ),
              data: (players) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(playerSearchProvider),
                child: players.isEmpty
                    ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(l10n.playersEmpty)))])
                    : ListView.builder(
                        itemCount: players.length,
                        itemBuilder: (context, i) {
                          final p = players[i];
                          return ListTile(
                            key: Key('player-row-${p.username}'),
                            // The directory only carries an equipped-frame slug, not art, so no frame here.
                            leading: PlayerAvatar(avatarUrl: p.avatarUrl, size: 40),
                            title: Text(p.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('@${p.username} · ${l10n.profileSxScore(p.sxScore)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Text(tierLabel(l10n, p.membershipTier)),
                            onTap: () => widget.onPlayerTap(p.username),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
