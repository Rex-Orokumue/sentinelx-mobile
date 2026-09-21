import 'package:flutter/widgets.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/static/rich_content.dart';
import '../../shared/widgets/static_page_screen.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 15 sections in the web source — verified directly against the
    // generated lib/core/l10n/app_en.arb (not guessed): several sections
    // have more paragraphs than a naive read of the web page would suggest
    // (S2/S6/S12 each have a P2; S4/S8 have a P1+P2 before their tagged
    // paragraph; S9/S10/S15's only paragraph carries a rich tag too).
    final sections = [
      StaticSection(heading: l10n.termsS1Heading, paragraphs: [l10n.termsS1P1, l10n.termsS1P2]),
      StaticSection(heading: l10n.termsS2Heading, paragraphs: [l10n.termsS2P1, l10n.termsS2P2]),
      StaticSection(heading: l10n.termsS3Heading, paragraphs: [l10n.termsS3P1, stripRichTags(l10n.termsS3P2)]),
      StaticSection(heading: l10n.termsS4Heading, paragraphs: [l10n.termsS4P1, l10n.termsS4P2, stripRichTags(l10n.termsS4P3)]),
      StaticSection(
        heading: l10n.termsS5Heading,
        paragraphs: [l10n.termsS5Intro, stripRichTags(l10n.termsS5P2), l10n.termsS5P3],
        bulletItems: parseListFragment(l10n.termsS5List),
      ),
      StaticSection(heading: l10n.termsS6Heading, paragraphs: [l10n.termsS6P1, l10n.termsS6P2]),
      StaticSection(heading: l10n.termsS7Heading, paragraphs: [l10n.termsS7P1]),
      StaticSection(
        heading: l10n.termsS8Heading,
        paragraphs: [l10n.termsS8P1, l10n.termsS8P2],
        bulletItems: parseListFragment(l10n.termsS8List),
      ),
      StaticSection(heading: l10n.termsS9Heading, paragraphs: [stripRichTags(l10n.termsS9P1)]),
      StaticSection(heading: l10n.termsS10Heading, paragraphs: [stripRichTags(l10n.termsS10P1)]),
      StaticSection(heading: l10n.termsS11Heading, paragraphs: [l10n.termsS11P1]),
      StaticSection(heading: l10n.termsS12Heading, paragraphs: [l10n.termsS12P1, l10n.termsS12P2]),
      StaticSection(heading: l10n.termsS13Heading, paragraphs: [l10n.termsS13P1]),
      StaticSection(heading: l10n.termsS14Heading, paragraphs: [l10n.termsS14P1]),
      StaticSection(heading: l10n.termsS15Heading, paragraphs: [stripRichTags(l10n.termsS15P1)]),
    ];
    return StaticPageScreen(title: l10n.termsTitle, summary: l10n.termsSummary, sections: sections);
  }
}
