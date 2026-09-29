import '../../core/api/api_client.dart';
import '../../core/utils/write_flow.dart';
import '../match/evidence.dart' show PickedImage;
import 'community_image_uploader.dart';

/// Uploads at most once per picked image, then posts through the given [WriteFlow].
///
/// Mirrors `ResultSubmitter`'s shape (single-image evidence upload) generalized to a list: each
/// picked image's uploaded URL is memoized **by identity** (`PickedImage` declares no `==`/
/// `hashCode`, so two distinct instances — even with identical bytes — are never equal), so a
/// retry after a failed POST reuses every already-uploaded image's URL and only uploads images not
/// yet uploaded. Picking a different image set changes the fingerprint passed to `WriteFlow.run`,
/// forcing a fresh Idempotency-Key so an edited retry never replays the old response.
class CommunityPostSubmitter {
  CommunityPostSubmitter({required this.uploader, required this.userId});
  final CommunityImageUploader uploader;
  final String userId;

  final Map<PickedImage, String> _uploadedUrls = {};

  Future<bool> submit({
    required WriteFlow flow,
    required String content,
    required List<PickedImage> images,
    required Future<void> Function(String content, List<String> imageUrls, String idempotencyKey) send,
  }) {
    final fingerprint = '$content:${images.map(identityHashCode).join(',')}';
    return flow.run(
      (key) async {
        final urls = <String>[];
        for (final image in images) {
          var url = _uploadedUrls[image];
          if (url == null) {
            try {
              url = await uploader.upload(userId: userId, image: image);
            } catch (_) {
              // Nothing was sent, so WriteFlow mints a new key for this; the screen shows upload-failed copy.
              throw const ApiException(status: 0, code: 'upload_failed', message: 'Image upload failed.');
            }
            _uploadedUrls[image] = url;
          }
          urls.add(url);
        }
        await send(content, urls, key);
      },
      fingerprint: fingerprint,
    );
  }
}
