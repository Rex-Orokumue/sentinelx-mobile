import 'package:flutter/material.dart';

import '../../core/l10n/gen/app_localizations.dart';
import 'stickers.dart';

/// The bundled pack as a grid. Tapping a sticker closes the sheet with its id (the caller sends it at once as
/// its own message). A second tap in the same frame is ignored.
class StickerPicker extends StatefulWidget {
  const StickerPicker({super.key});

  @override
  State<StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends State<StickerPicker> {
  bool _picked = false;

  void _pick(String id) {
    if (_picked) return;
    _picked = true;
    Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(l10n.dmStickers, style: const TextStyle(fontWeight: FontWeight.w700))),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 5,
            children: [
              for (final s in kStickerPack)
                InkWell(
                  key: Key('dm-sticker-${s.id}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _pick(s.id),
                  child: Semantics(label: s.label, button: true, child: Center(child: ExcludeSemantics(child: Text(s.emoji, style: const TextStyle(fontSize: 32))))),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}
