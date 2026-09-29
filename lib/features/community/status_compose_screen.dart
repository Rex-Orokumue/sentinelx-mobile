import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/utils/write_flow.dart';
import '../match/evidence.dart' show PickedImage;
import 'community_error_copy.dart';
import 'community_image_uploader.dart';
import 'community_providers.dart';
import 'compose_submitter.dart';

const _scope = 'status-compose';

/// A single image and/or an optional caption — the story compose screen. Mirrors
/// `ComposeScreen`'s shape at smaller scale (at most one image, not up to 5).
///
/// Reuses [CommunityPostSubmitter] (built for `ComposeScreen`'s content+multi-image shape) rather
/// than a dedicated single-image helper: the submitter's `send` callback already lets the caller
/// remap its `(content, imageUrls)` pair onto whatever wire shape it actually needs to send, so
/// mapping the trimmed caption text and the 0-or-1-length URL list onto `postStatus`'s nullable
/// `caption`/`imageUrl` is a two-line closure here — not enough divergence to justify duplicating
/// the submitter's upload-memoization-and-retry logic in a second, near-identical class.
class StatusComposeScreen extends ConsumerStatefulWidget {
  const StatusComposeScreen({super.key});

  @override
  ConsumerState<StatusComposeScreen> createState() => _StatusComposeScreenState();
}

class _StatusComposeScreenState extends ConsumerState<StatusComposeScreen> {
  final _caption = TextEditingController();
  PickedImage? _image;
  CommunityPostSubmitter? _submitter;

  @override
  void initState() {
    super.initState();
    // Re-evaluate the submit button's enabled state as the player types.
    _caption.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ref.read(communityMultiImagePickerProvider).pickImages(maxCount: 1);
    if (!mounted || picked.isEmpty) return;
    setState(() => _image = picked.first);
  }

  void _removeImage() => setState(() => _image = null);

  Future<void> _submit() async {
    final me = ref.read(meProvider).asData?.value;
    if (me == null) return;
    final navigator = Navigator.of(context);
    _submitter ??= CommunityPostSubmitter(uploader: ref.read(communityImageUploaderProvider), userId: me.id);
    final flow = ref.read(writeFlowProvider(_scope).notifier);
    final ok = await _submitter!.submit(
      flow: flow,
      content: _caption.text.trim(),
      images: _image == null ? const [] : [_image!],
      send: (content, urls, key) => ref.read(communityRepositoryProvider).postStatus(
            caption: content.isEmpty ? null : content,
            imageUrl: urls.isEmpty ? null : urls.first,
            idempotencyKey: key,
          ),
    );
    if (!mounted) return;
    if (ok) {
      ref.invalidate(communityStatusRingsProvider);
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Keeps `meProvider` (not autoDispose) resolved by the time the player can tap submit — same
    // reasoning as `ComposeScreen`.
    ref.watch(meProvider);
    final state = ref.watch(writeFlowProvider(_scope));
    final busy = state.busy;
    final errorCopy = state.phase == WritePhase.failed ? communityErrorCopy(l10n, state.errorCode ?? '') : null;
    final hasContent = _caption.text.trim().isNotEmpty || _image != null;
    final canSubmit = !busy && hasContent;

    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.cmtStatusPost),
          actions: [
            TextButton(
              key: const Key('status-compose-cancel'),
              onPressed: busy ? null : () => Navigator.of(context).maybePop(),
              child: Text(l10n.cmtComposeCancel),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_image != null)
              SizedBox(
                height: 220,
                child: Stack(clipBehavior: Clip.none, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _image!.bytes,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      // Arbitrary picked bytes may not decode as an image in some environments;
                      // degrade to a placeholder rather than crash the compose form.
                      errorBuilder: (_, _, _) => Container(
                        width: double.infinity,
                        height: 220,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_outlined),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -8,
                    top: -8,
                    child: IconButton(
                      key: const Key('status-compose-remove-image'),
                      onPressed: busy ? null : _removeImage,
                      tooltip: l10n.cmtComposeRemoveImage,
                      icon: const Icon(Icons.cancel, size: 20),
                    ),
                  ),
                ]),
              )
            else
              OutlinedButton.icon(
                key: const Key('status-compose-add-image'),
                onPressed: busy ? null : _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(l10n.cmtComposeAddImage),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('status-compose-caption'),
              controller: _caption,
              enabled: !busy,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(hintText: l10n.cmtStatusCaptionHint),
            ),
            if (!hasContent)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(l10n.cmtStatusValidation)),
            if (errorCopy != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(errorCopy, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('status-compose-submit'),
              onPressed: canSubmit ? _submit : null,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (busy) ...[
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                ],
                Text(busy ? l10n.cmtComposePosting : l10n.cmtStatusPost),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
