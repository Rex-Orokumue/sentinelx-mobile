import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations_en.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations_fr.dart';

void main() {
  // Zero and one are the commonest values on a young community, and "1 comments" reads as a bug.
  test('English count strings pluralise', () {
    final l = AppLocalizationsEn();
    expect(l.cmtCommentCount(0), '0 comments');
    expect(l.cmtCommentCount(1), '1 comment');
    expect(l.cmtCommentCount(2), '2 comments');
    expect(l.cmtStatsMembers(1), '1 member');
    expect(l.cmtStatsMembers(1000), '1000 members');
    expect(l.cmtStatsCountries(1), '1 country');
    expect(l.cmtStatsCountries(20), '20 countries');
    expect(l.cmtStatsTournaments(1), '1 tournament');
    expect(l.cmtStatsTournaments(50), '50 tournaments');
  });

  test('French count strings pluralise (0 and 1 are both singular in French)', () {
    final l = AppLocalizationsFr();
    expect(l.cmtCommentCount(0), '0 commentaire');
    expect(l.cmtCommentCount(1), '1 commentaire');
    expect(l.cmtCommentCount(2), '2 commentaires');
    expect(l.cmtStatsMembers(1), '1 membre');
    expect(l.cmtStatsMembers(5), '5 membres');
    expect(l.cmtStatsCountries(1), '1 pays');
    expect(l.cmtStatsCountries(20), '20 pays');
    expect(l.cmtStatsTournaments(1), '1 tournoi');
    expect(l.cmtStatsTournaments(50), '50 tournois');
  });
}
