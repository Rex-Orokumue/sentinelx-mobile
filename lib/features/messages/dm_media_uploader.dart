import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions, StorageException, SupabaseClient;

import '../../core/providers.dart';

/// `<userId>/<id>.<ext>`: the storage RLS for `dm-images` / `dm-audio` requires the first segment to be the
/// uploader's own uid, and the server rejects any other prefix with 400 `validation`.
String dmMediaPath({required String userId, required String id, required String ext}) => '$userId/$id.$ext';

/// The one place bytes reach Storage, so tests need no socket.
abstract class DmStoragePort {
  Future<void> put({required String bucket, required String path, required Uint8List bytes, required String contentType, required bool upsert});
}

class SupabaseDmStorage implements DmStoragePort {
  SupabaseDmStorage(this._client);
  final SupabaseClient _client;

  @override
  Future<void> put({required String bucket, required String path, required Uint8List bytes, required String contentType, required bool upsert}) async {
    await _client.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(upsert: upsert, contentType: contentType));
  }
}

abstract class DmMediaUploader {
  /// Uploads to `dm-images` and returns the STORAGE PATH (the server signs URLs itself).
  Future<String> uploadImage({required String userId, required Uint8List jpeg, required String pathId});

  /// Uploads an AAC-LC `.m4a` to `dm-audio` and returns the storage path.
  Future<String> uploadAudio({required String userId, required File file, required String pathId});
}

/// The path id is generated once per pending item and reused on every retry, and a duplicate-object error
/// is treated as success (the first attempt landed and only its response was lost), so a retry never orphans
/// or duplicates a file.
class SupabaseDmMediaUploader implements DmMediaUploader {
  SupabaseDmMediaUploader(this._storage);
  final DmStoragePort _storage;

  bool _isDuplicate(Object e) {
    if (e is! StorageException) return false;
    final text = '${e.message} ${e.error ?? ''}'.toLowerCase();
    return e.statusCode == '409' || text.contains('duplicate') || text.contains('already exists');
  }

  Future<String> _put(String bucket, String path, Uint8List bytes, String contentType) async {
    try {
      await _storage.put(bucket: bucket, path: path, bytes: bytes, contentType: contentType, upsert: false);
    } catch (e) {
      if (!_isDuplicate(e)) rethrow;
    }
    return path;
  }

  @override
  Future<String> uploadImage({required String userId, required Uint8List jpeg, required String pathId}) =>
      _put('dm-images', dmMediaPath(userId: userId, id: pathId, ext: 'jpg'), jpeg, 'image/jpeg');

  @override
  Future<String> uploadAudio({required String userId, required File file, required String pathId}) async =>
      _put('dm-audio', dmMediaPath(userId: userId, id: pathId, ext: 'm4a'), await file.readAsBytes(), 'audio/mp4');
}

final dmMediaUploaderProvider = Provider<DmMediaUploader>((ref) => SupabaseDmMediaUploader(SupabaseDmStorage(ref.watch(supabaseClientProvider))));
