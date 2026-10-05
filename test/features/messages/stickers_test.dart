import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/messages/stickers.dart';

void main() {
  const webOrder = ['gg', 'fire', 'trophy', 'rage', 'ez', 'clutch', 'lol', 'ggwp', 'sad', 'clap', 'rocket', 'skull', 'eyes', 'goat'];

  test('the pack has exactly 14 unique ids in the web order', () {
    expect(kStickerPack.map((s) => s.id).toList(), webOrder);
    expect(kStickerPack.map((s) => s.id).toSet().length, 14);
  });

  test('stickerById finds a known id and returns null for an unknown one', () {
    expect(stickerById('goat')?.emoji, '🐐');
    expect(stickerById('nope'), isNull);
  });

  test('kStickerPack equals the fixture written by tool/sync_stickers.dart (drift check)', () {
    final raw = File('test/fixtures/web_sticker_pack.json').readAsBytesSync();
    final fixture = (jsonDecode(utf8.decode(raw)) as List<dynamic>).cast<Map<String, dynamic>>();
    expect([for (final s in kStickerPack) {'id': s.id, 'emoji': s.emoji}], fixture);
  });

  test('every emoji is a real character, not mojibake', () {
    for (final s in kStickerPack) {
      expect(s.emoji.runes.first, greaterThan(0x2000), reason: s.id);
    }
  });
}
