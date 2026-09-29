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

/// Mirrors the web's `MAX_POST_IMAGES` clamp.
const _maxImages = 5;

const _scope = 'compose';

/// Text + up to 5 images. Images are uploaded once each (memoized by identity in
/// [CommunityPostSubmitter]) to the public `community-images` Storage bucket, then the post is
/// created through the API with the resulting public URLs.
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _content = TextEditingController();
  final List<PickedImage> _images = [];
  CommunityPostSubmitter? _submitter;

  @override
  void initState() {
    super.initState();
    // Re-evaluate the submit button's enabled state as the player types.
    _content.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) return;
    final picked = await ref.read(communityMultiImagePickerProvider).pickImages(maxCount: remaining);
    if (!mounted || picked.isEmpty) return;
    setState(() {
      _images.addAll(picked);
      if (_images.length > _maxImages) {
        _images.removeRange(_maxImages, _images.length);
      }
    });
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  Future<void> _submit() async {
    final me = ref.read(meProvider).asData?.value;
    if (me == null) return;
    final navigator = Navigator.of(context);
    _submitter ??= CommunityPostSubmitter(uploader: ref.read(communityImageUploaderProvider), userId: me.id);
    final flow = ref.read(writeFlowProvider(_scope).notifier);
    final ok = await _submitter!.submit(
      flow: flow,
      content: _content.text.trim(),
      images: List<PickedImage>.of(_images),
      send: (content, urls, key) => ref.read(communityRepositoryProvider).createPost(
            content: content,
            imageUrls: urls,
            idempotencyKey: key,
          ),
    );
    if (!mounted) return;
    if (ok) {
      ref.invalidate(communityFeedProvider);
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Keeps `meProvider` (not autoDispose) resolved by the time the player can tap submit — the
    // real app always reaches this screen from a place that already watches it (the feed gates the
    // FAB), but an isolated push of this screen otherwise never triggers its first build.
    ref.watch(meProvider);
    final state = ref.watch(writeFlowProvider(_scope));
    final busy = state.busy;
    final errorCopy = state.phase == WritePhase.failed ? communityErrorCopy(l10n, state.errorCode ?? '') : null;
    final canSubmit = !busy && (_content.text.trim().isNotEmpty || _images.isNotEmpty);

    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.cmtComposeTitle),
          actions: [
            TextButton(
              key: const Key('compose-cancel'),
              onPressed: busy ? null : () => Navigator.of(context).maybePop(),
              child: Text(l10n.cmtComposeCancel),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              key: const Key('compose-content'),
              controller: _content,
              enabled: !busy,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(hintText: l10n.cmtComposeHint),
            ),
            const SizedBox(height: 12),
            if (_images.isNotEmpty) ...[
              Text(l10n.cmtComposeImagesCount(_images.length)),
              const SizedBox(height: 8),
              // A Wrap (not a lazy horizontal ListView) so all up-to-5 thumbnails are always built —
              // there's never enough of them to need virtualization, and every remove button must be
              // reachable without scrolling.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _images.length; i++)
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(clipBehavior: Clip.none, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _images[i].bytes,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            // Arbitrary picked bytes may not decode as an image in some environments;
                            // degrade to a placeholder rather than crash the compose form.
                            errorBuilder: (_, _, _) => Container(
                              width: 80,
                              height: 80,
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.image_outlined),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -8,
                          top: -8,
                          child: IconButton(
                            key: Key('compose-remove-image-$i'),
                            onPressed: busy ? null : () => _removeImage(i),
                            tooltip: l10n.cmtComposeRemoveImage,
                            icon: const Icon(Icons.cancel, size: 20),
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              key: const Key('compose-add-image'),
              onPressed: busy || _images.length >= _maxImages ? null : _pickImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(l10n.cmtComposeAddImage),
            ),
            if (errorCopy != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(errorCopy, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('compose-submit'),
              onPressed: canSubmit ? _submit : null,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (busy) ...[
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                ],
                Text(busy ? l10n.cmtComposePosting : l10n.cmtComposePost),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
