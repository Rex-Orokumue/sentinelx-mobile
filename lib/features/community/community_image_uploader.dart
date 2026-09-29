import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions, SupabaseClient;

import '../../core/providers.dart';
import '../match/evidence.dart' show PickedImage;

/// Same shape as `evidencePath` (one segment shorter — there's no per-match scope): the
/// `community-images` bucket's insert policy only requires the first path segment to be the
/// uploader's own uid (`(storage.foldername(name))[1] = auth.uid()::text`, `016_community.sql`).
String communityImagePath({required String userId, required String fileName, required DateTime now}) {
  final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  return '$userId/${now.millisecondsSinceEpoch}-$safe';
}

abstract class CommunityImageUploader {
  /// Uploads [image] and returns its PUBLIC URL (the `community-images` bucket is public-read,
  /// unlike the private `match-evidence` bucket `EvidenceUploader` writes to).
  Future<String> upload({required String userId, required PickedImage image});
}

abstract class MultiImagePickerPort {
  /// Empty when the user cancelled or picked nothing.
  Future<List<PickedImage>> pickImages({required int maxCount});
}

/// The one sanctioned non-API write for Community: a Storage upload to the public
/// `community-images` bucket (same shape as `SupabaseEvidenceUploader`).
class SupabaseCommunityImageUploader implements CommunityImageUploader {
  SupabaseCommunityImageUploader(this._client);
  final SupabaseClient _client;

  @override
  Future<String> upload({required String userId, required PickedImage image}) async {
    final path = communityImagePath(userId: userId, fileName: image.name, now: DateTime.now());
    await _client.storage.from('community-images').uploadBinary(
          path,
          image.bytes,
          fileOptions: FileOptions(upsert: false, contentType: image.mimeType),
        );
    return _client.storage.from('community-images').getPublicUrl(path);
  }
}

class PluginMultiImagePicker implements MultiImagePickerPort {
  @override
  Future<List<PickedImage>> pickImages({required int maxCount}) async {
    final files = await ImagePicker().pickMultiImage(limit: maxCount, maxWidth: 1600, imageQuality: 80);
    return Future.wait(files.map((f) async => PickedImage(name: f.name, bytes: await f.readAsBytes(), mimeType: f.mimeType)));
  }
}

final communityImageUploaderProvider =
    Provider<CommunityImageUploader>((ref) => SupabaseCommunityImageUploader(ref.watch(supabaseClientProvider)));

final communityMultiImagePickerProvider = Provider<MultiImagePickerPort>((ref) => PluginMultiImagePicker());
