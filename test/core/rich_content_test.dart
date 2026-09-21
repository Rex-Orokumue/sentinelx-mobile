import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/static/rich_content.dart';

void main() {
  group('stripRichTags', () {
    test('removes a single wrapping tag, keeping the inner text', () {
      expect(stripRichTags('contact us at <email>sentinelxesports@gmail.com</email>.'),
          'contact us at sentinelxesports@gmail.com.');
    });
    test('removes multiple different tags in one string', () {
      expect(stripRichTags('See the <link>Refund Policy</link> for <email>details</email>.'), 'See the Refund Policy for details.');
    });
    test('leaves plain text untouched', () {
      expect(stripRichTags('Nigerian law applies.'), 'Nigerian law applies.');
    });
  });

  group('parseListFragment', () {
    test('extracts each <li> item as plain text', () {
      expect(
        parseListFragment('<li>Submitting false results</li><li>Using exploits</li>'),
        ['Submitting false results', 'Using exploits'],
      );
    });
    test('returns an empty list for a fragment with no <li> items', () {
      expect(parseListFragment(''), <String>[]);
    });
  });
}
