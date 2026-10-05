/// The bundled sticker pack. Mirrors the web repo's `lib/messages/stickers.ts` (14 emoji stickers, same order);
/// the server validates ids against its own whitelist. Drift is caught by `test/fixtures/web_sticker_pack.json`,
/// which `tool/sync_stickers.dart` rewrites from the web checkout.
class Sticker {
  const Sticker(this.id, this.emoji, this.label);

  final String id;
  final String emoji;

  /// Short name for accessibility (the web's own label; not localized, these are gamer slang).
  final String label;
}

const kStickerPack = <Sticker>[
  Sticker('gg', '🎮', 'GG'),
  Sticker('fire', '🔥', 'Fire'),
  Sticker('trophy', '🏆', 'Trophy'),
  Sticker('rage', '😤', 'Rage'),
  Sticker('ez', '😎', 'EZ'),
  Sticker('clutch', '💪', 'Clutch'),
  Sticker('lol', '😂', 'LOL'),
  Sticker('ggwp', '🤝', 'GGWP'),
  Sticker('sad', '😭', 'Sad'),
  Sticker('clap', '👏', 'Clap'),
  Sticker('rocket', '🚀', 'Rocket'),
  Sticker('skull', '💀', 'Skull'),
  Sticker('eyes', '👀', 'Eyes'),
  Sticker('goat', '🐐', 'GOAT'),
];

Sticker? stickerById(String id) {
  for (final s in kStickerPack) {
    if (s.id == id) return s;
  }
  return null;
}
