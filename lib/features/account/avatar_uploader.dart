import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../core/utils/idempotency_key.dart';

abstract class AvatarUploader {
  /// Uploads a sanitized JPEG to `avatars/<uid>/<uuid>.jpg` and returns its public URL.
  Future<String> upload(Uint8List jpeg);
}

/// Same direct-to-storage-under-RLS pattern as community and evidence uploads (`avatars` insert policy:
/// first path segment must equal auth.uid()). The web API then validates the URL is in the caller's own folder.
class SupabaseAvatarUploader implements AvatarUploader {
  SupabaseAvatarUploader(this._client);
  final SupabaseClient _client;
  @override
  Future<String> upload(Uint8List jpeg) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('not signed in');
    final path = '$uid/${newIdempotencyKey()}.jpg';
    await _client.storage.from('avatars').uploadBinary(path, jpeg, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
    return _client.storage.from('avatars').getPublicUrl(path);
  }
}

final avatarUploaderProvider = Provider<AvatarUploader>((ref) => SupabaseAvatarUploader(ref.watch(supabaseClientProvider)));
