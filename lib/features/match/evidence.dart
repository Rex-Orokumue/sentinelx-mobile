import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions, SupabaseClient;

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/utils/write_flow.dart';

class PickedImage {
  const PickedImage({required this.name, required this.bytes, this.mimeType});
  final String name;
  final Uint8List bytes;
  final String? mimeType;
}

/// Same shape as the website: `{userId}/{matchId or lobbyId}/{epochMs}-{safeName}`. The private
/// `match-evidence` bucket only allows a user's own `{uid}/…` folder.
String evidencePath({required String userId, required String scopeId, required String fileName, required DateTime now}) {
  final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  return '$userId/$scopeId/${now.millisecondsSinceEpoch}-$safe';
}

abstract class EvidenceUploader {
  /// Uploads [image] and returns the storage path.
  Future<String> upload({required String userId, required String scopeId, required PickedImage image});
}

abstract class ImagePickerPort {
  /// Null when the user cancelled.
  Future<PickedImage?> pickScreenshot();
}

/// The one sanctioned non-API write: a Storage upload to the private `match-evidence` bucket (mirrors the website).
class SupabaseEvidenceUploader implements EvidenceUploader {
  SupabaseEvidenceUploader(this._client);
  final SupabaseClient _client;

  @override
  Future<String> upload({required String userId, required String scopeId, required PickedImage image}) async {
    final path = evidencePath(userId: userId, scopeId: scopeId, fileName: image.name, now: DateTime.now());
    await _client.storage.from('match-evidence').uploadBinary(
          path,
          image.bytes,
          fileOptions: FileOptions(upsert: false, contentType: image.mimeType),
        );
    return path;
  }
}

class PluginImagePicker implements ImagePickerPort {
  @override
  Future<PickedImage?> pickScreenshot() async {
    // maxWidth/imageQuality are the spec's "compress before upload".
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    if (file == null) return null;
    return PickedImage(name: file.name, bytes: await file.readAsBytes(), mimeType: file.mimeType);
  }
}

final evidenceUploaderProvider = Provider<EvidenceUploader>((ref) => SupabaseEvidenceUploader(ref.watch(supabaseClientProvider)));
final imagePickerProvider = Provider<ImagePickerPort>((ref) => PluginImagePicker());

/// Uploads at most once per picked image, then runs [send] through the given [WriteFlow].
class ResultSubmitter {
  ResultSubmitter({required this.uploader, required this.userId, required this.scopeId});
  final EvidenceUploader uploader;
  final String userId;
  final String scopeId;

  PickedImage? _uploadedImage;
  String? _uploadedPath;

  /// [fingerprint] identifies the non-image fields of this attempt's payload (e.g. `'2:1:'` for
  /// scoreA:scoreB:recordingUrl). Combined with the picked image's identity, it lets [flow] tell a
  /// retry of the same submission from an edited one, so an edited retry after a kept key never
  /// replays the server's response to the old values.
  Future<bool> submit({
    required WriteFlow flow,
    required PickedImage image,
    required Future<void> Function(String screenshotPath, String idempotencyKey) send,
    Object? fingerprint,
  }) =>
      flow.run(
        (key) async {
          var path = identical(image, _uploadedImage) ? _uploadedPath : null;
          if (path == null) {
            try {
              path = await uploader.upload(userId: userId, scopeId: scopeId, image: image);
            } catch (_) {
              // Nothing was sent, so WriteFlow mints a new key for this; the screen shows upload-failed copy.
              throw const ApiException(status: 0, code: 'upload_failed', message: 'Screenshot upload failed.');
            }
            _uploadedImage = image;
            _uploadedPath = path;
          }
          await send(path, key);
        },
        fingerprint: fingerprint == null ? null : '$fingerprint:${identityHashCode(image)}',
      );
}
