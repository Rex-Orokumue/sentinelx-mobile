import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import 'compete_providers.dart';

/// Display-only catalogue of active games (spec 6.6): there is nothing to act on yet.
class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(gamesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cmpGamesTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(l10n.cmpLoadError, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => ref.invalidate(gamesProvider), child: Text(l10n.cmpRetry)),
            ]),
          ),
        ),
        data: (games) => games.isEmpty
            ? Center(child: Text(l10n.cmpGamesEmpty))
            : ListView.builder(
                itemCount: games.length,
                itemBuilder: (_, i) {
                  final g = games[i];
                  return ListTile(
                    leading: SizedBox(
                      width: 40,
                      height: 40,
                      child: g.iconUrl == null
                          ? const Icon(Icons.sports_esports)
                          : Image.network(g.iconUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.sports_esports)),
                    ),
                    title: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  );
                },
              ),
      ),
    );
  }
}
