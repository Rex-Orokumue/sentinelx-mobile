import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../compete/compete_models.dart';

class GameInterestsField extends StatelessWidget {
  const GameInterestsField({
    super.key,
    required this.label,
    required this.games,
    required this.selectedIds,
    required this.onChanged,
    required this.loadingText,
    required this.retryText,
    required this.onRetry,
    this.enabled = true,
    this.errorText,
  });

  final String label;
  final AsyncValue<List<GameSummary>> games;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  final String loadingText;
  final String retryText;
  final VoidCallback onRetry;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      games.when(
        loading: () => Row(
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(loadingText),
          ],
        ),
        error: (_, _) => TextButton(
          key: const Key('game-interests-retry'),
          onPressed: enabled ? onRetry : null,
          child: Text(retryText),
        ),
        data: (items) => Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final game in items)
              FilterChip(
                key: Key('game-interest-${game.id}'),
                label: Text(game.name),
                selected: selectedIds.contains(game.id),
                onSelected: enabled
                    ? (selected) {
                        final next = {...selectedIds};
                        selected ? next.add(game.id) : next.remove(game.id);
                        onChanged(next);
                      }
                    : null,
              ),
          ],
        ),
      ),
      if (errorText != null) ...[
        const SizedBox(height: 4),
        Text(
          errorText!,
          key: const Key('game-interests-error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ],
  );
}
