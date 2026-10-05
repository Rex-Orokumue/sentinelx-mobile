import 'package:flutter/material.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';

/// A confirmed photo. [url] is a signed URL that lasts about an hour: when it fails (expired, offline),
/// [onError] asks the thread for ONE rate-limited refetch and the tile shows a placeholder meanwhile.
class ImageBubble extends StatelessWidget {
  const ImageBubble({super.key, required this.url, required this.onError});

  final String url;
  final VoidCallback onError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget tile() => Container(
          key: const Key('dm-image-placeholder'),
          width: 200,
          height: 150,
          decoration: BoxDecoration(color: SxColors.surface, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.image_not_supported_outlined, color: SxColors.textSecondary),
            const SizedBox(height: 4),
            Text(l10n.dmImageUnavailable, style: const TextStyle(fontSize: 12, color: SxColors.textSecondary)),
          ]),
        );
    // '' marks "just sent, signed URL not fetched yet".
    if (url.isEmpty) return tile();
    return GestureDetector(
      key: const Key('dm-image'),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ImageViewerScreen(url: url))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) {
            WidgetsBinding.instance.addPostFrameCallback((_) => onError());
            return tile();
          },
        ),
      ),
    );
  }
}

class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: Center(
          child: InteractiveViewer(
            key: const Key('dm-image-viewer'),
            child: Image.network(url, errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.white54, size: 48)),
          ),
        ),
      );
}
