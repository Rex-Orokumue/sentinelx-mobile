import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/progress/history_labels.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async => l10n = await AppLocalizations.delegate.load(const Locale('en')));

  test('humanizeCode turns snake_case into a sentence and survives odd input', () {
    expect(humanizeCode('brand_new_thing'), 'Brand new thing');
    expect(humanizeCode('single'), 'Single');
    expect(humanizeCode('__double__underscore_'), 'Double underscore');
    expect(humanizeCode(''), '—');
    expect(humanizeCode('___'), '—');
  });

  test('known codes map to their localized labels', () {
    expect(xpSourceLabel(l10n, 'match_won'), 'Match won');
    expect(scoreEventLabel(l10n, 'no_show'), 'No-show');
    expect(coinSourceLabel(l10n, 'friendly_stake_payout'), 'Friendly payout');
    expect(tierLabel(l10n, 'guardian'), 'Guardian');
  });

  test('unknown codes fall back to a humanized label — never blank, never a crash', () {
    expect(xpSourceLabel(l10n, 'referral_bonus_v2'), 'Referral bonus v2');
    expect(scoreEventLabel(l10n, 'something_new'), 'Something new');
    expect(coinSourceLabel(l10n, 'brand_new_source'), 'Brand new source');
    expect(tierLabel(l10n, 'mythic'), 'Mythic');
  });

  test('codes whose dedicated label differs from the naive humanization are actually mapped (guards a dropped switch arm)', () {
    // Only codes where the English label != humanizeCode(code); the others (e.g. match_won -> "Match won") are
    // indistinguishable from the fallback and are covered by the known-code test above.
    expect(scoreEventLabel(l10n, 'no_show'), isNot(humanizeCode('no_show')));
    expect(scoreEventLabel(l10n, 'rage_quit'), 'Left a match early');
    expect(scoreEventLabel(l10n, 'admin_flag_conduct'), 'Conduct flag');
    expect(scoreEventLabel(l10n, 'admin_flag_cheat'), 'Cheat flag');
    expect(coinSourceLabel(l10n, 'admin_deduct'), 'Admin deduction');
    expect(coinSourceLabel(l10n, 'best_play_runner_up'), 'Best Play runner-up');
    expect(coinSourceLabel(l10n, 'friendly_stake_payout'), 'Friendly payout');
  });
}
