import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/progress_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import 'seasons_providers.dart';

class SeasonsListScreen extends ConsumerWidget {
  const SeasonsListScreen({super.key, required this.onSeasonTap});
  final void Function(SeasonSummary) onSeasonTap;
  @override
  Widget build(BuildContext c, WidgetRef r) {
    final l = AppLocalizations.of(c);
    return Scaffold(
      appBar: AppBar(title: Text(l.seasonsTitle)),
      body: r
          .watch(seasonsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: Text(l.rankingsErrorRetry)),
            data: (xs) => xs.isEmpty
                ? Center(child: Text(l.seasonsEmpty))
                : ListView(
                    children: [
                      for (final s in xs)
                        ListTile(
                          title: Text(s.name),
                          subtitle: Text('${s.startDate} – ${s.endDate}'),
                          onTap: () => onSeasonTap(s),
                        ),
                    ],
                  ),
          ),
    );
  }
}
