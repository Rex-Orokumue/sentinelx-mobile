import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/account/game_interests_field.dart';
import 'package:sentinelx_mobile/features/compete/compete_models.dart';

const games = [
  GameSummary(
    id: 'codm',
    name: 'COD Mobile',
    slug: 'cod-mobile',
    iconUrl: null,
  ),
  GameSummary(id: 'fc', name: 'EA Sports FC', slug: 'ea-fc', iconUrl: null),
];

Widget host(GameInterestsField field) =>
    MaterialApp(home: Scaffold(body: field));

void main() {
  testWidgets('shows preselection and supports multiple selection', (
    tester,
  ) async {
    Set<String>? selected;
    await tester.pumpWidget(
      host(
        GameInterestsField(
          label: 'Games',
          games: const AsyncData(games),
          selectedIds: const {'codm'},
          onChanged: (value) => selected = value,
          loadingText: 'Loading games',
          retryText: 'Try again',
          onRetry: () {},
        ),
      ),
    );

    final codm = tester.widget<FilterChip>(
      find.byKey(const Key('game-interest-codm')),
    );
    expect(codm.selected, isTrue);
    await tester.tap(find.byKey(const Key('game-interest-fc')));
    expect(selected, {'codm', 'fc'});
  });

  testWidgets('renders loading, error retry, and validation states', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      host(
        GameInterestsField(
          label: 'Games',
          games: const AsyncLoading(),
          selectedIds: const {},
          onChanged: (_) {},
          loadingText: 'Loading games',
          retryText: 'Try again',
          onRetry: () => retried = true,
          errorText: 'Choose at least one game',
        ),
      ),
    );
    expect(find.text('Loading games'), findsOneWidget);
    expect(find.text('Choose at least one game'), findsOneWidget);

    await tester.pumpWidget(
      host(
        GameInterestsField(
          label: 'Games',
          games: AsyncError(Exception('offline'), StackTrace.empty),
          selectedIds: const {},
          onChanged: (_) {},
          loadingText: 'Loading games',
          retryText: 'Try again',
          onRetry: () => retried = true,
        ),
      ),
    );
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });
}
