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
            error: (error, stackTrace) => Center(
              child: InkWell(
                onTap: () => r.invalidate(seasonsProvider),
                child: Text(l.rankingsErrorRetry),
              ),
            ),
            data: (xs) => RefreshIndicator(
              onRefresh: () => r.refresh(seasonsProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (xs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text(l.seasonsEmpty)),
                    ),
                  for (final s in xs)
                    ListTile(
                      title: Text(s.name),
                      subtitle: Text('${s.startDate} – ${s.endDate}'),
                      onTap: () => onSeasonTap(s),
                    ),
                ],
              ),
            ),
          ),
    );
  }
}
