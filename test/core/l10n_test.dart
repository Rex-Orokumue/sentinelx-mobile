import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<String> _keys(String path) => (jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>)
    .keys
    .where((k) => !k.startsWith('@'))
    .toSet();

void main() {
  test('every locale defines exactly the keys of the English template', () {
    final en = _keys('lib/core/l10n/app_en.arb');
    expect(_keys('lib/core/l10n/app_fr.arb'), en);
  });

  test('Pidgin is a subset of the English template; missing keys fall back to English', () {
    final en = _keys('lib/core/l10n/app_en.arb');
    final pcm = _keys('lib/core/l10n/app_pcm.arb');
    expect(pcm.difference(en), isEmpty, reason: 'delete these from app_pcm.arb: web keys en never imported');
    expect(pcm, isNotEmpty);
  });
}
