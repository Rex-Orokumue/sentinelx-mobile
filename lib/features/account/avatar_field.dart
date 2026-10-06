import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../shared/widgets/player_avatar.dart';
import '../messages/dm_image_pipeline.dart' show kMaxPickedBytes;
import 'avatar_pipeline.dart';
import 'avatar_uploader.dart';

enum _AvatarError { tooLarge, notImage, uploadFailed }

/// Current avatar plus a "Change photo" flow: pick -> sanitize on device (EXIF/GPS stripped) -> upload -> [onChanged]
/// with the public URL. Any failure leaves the previous avatar in place and reports nothing upward.
class AvatarField extends ConsumerStatefulWidget {
  const AvatarField({super.key, required this.url, required this.enabled, required this.onChanged});

  final String? url;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  ConsumerState<AvatarField> createState() => _AvatarFieldState();
}

class _AvatarFieldState extends ConsumerState<AvatarField> {
  bool _busy = false;
  _AvatarError? _error;

  Future<void> _change() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              key: const Key('avatar-source-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.avatarFromGallery),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              key: const Key('avatar-source-camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.avatarFromCamera),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ]),
        );
      },
    );
    if (source == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await ref.read(avatarPickerProvider).pick(source);
      if (picked == null || !mounted) return;
      if (picked.bytes.length > kMaxPickedBytes) {
        setState(() => _error = _AvatarError.tooLarge);
        return;
      }
      final Uint8List jpeg;
      try {
        jpeg = await ref.read(avatarSanitizerProvider)(picked.bytes);
      } on FormatException {
        if (mounted) setState(() => _error = _AvatarError.notImage);
        return;
      }
      final url = await ref.read(avatarUploaderProvider).upload(jpeg);
      if (!mounted) return;
      widget.onChanged(url);
    } catch (_) {
      if (mounted) setState(() => _error = _AvatarError.uploadFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final errorText = switch (_error) {
      _AvatarError.tooLarge => l10n.avatarTooLarge,
      _AvatarError.notImage => l10n.avatarNotImage,
      _AvatarError.uploadFailed => l10n.avatarUploadFailed,
      null => null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(children: [
        PlayerAvatar(avatarUrl: widget.url, size: 72),
        const SizedBox(height: 8),
        if (_busy)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Text(l10n.avatarUploading),
          ])
        else
          TextButton(
            key: const Key('avatar-change'),
            onPressed: widget.enabled ? _change : null,
            child: Text(l10n.avatarChangePhoto),
          ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(errorText, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
      ]),
    );
  }
}
