import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/messages/dm_media_uploader.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;

class _Storage implements DmStoragePort {
  final puts = <({String bucket, String path, int length, String contentType, bool upsert})>[];
  Object? error;

  @override
  Future<void> put({required String bucket, required String path, required Uint8List bytes, required String contentType, required bool upsert}) async {
    puts.add((bucket: bucket, path: path, length: bytes.length, contentType: contentType, upsert: upsert));
    if (error != null) throw error!;
  }
}

void main() {
  test('dmMediaPath is <user>/<id>.<ext>', () {
    expect(dmMediaPath(userId: 'u1', id: 'abc', ext: 'jpg'), 'u1/abc.jpg');
  });

  test('uploadImage goes to dm-images at <user>/<id>.jpg as image/jpeg, never upserting, and returns the path', () async {
    final s = _Storage();
    final path = await SupabaseDmMediaUploader(s).uploadImage(userId: 'u1', jpeg: Uint8List(10), pathId: 'p-1');
    expect(path, 'u1/p-1.jpg');
    expect(s.puts.single.bucket, 'dm-images');
    expect(s.puts.single.path, 'u1/p-1.jpg');
    expect(s.puts.single.contentType, 'image/jpeg');
    expect(s.puts.single.upsert, isFalse);
    expect(path.startsWith('u1/'), isTrue, reason: 'storage RLS: the first segment must be the uploader');
  });

  test('uploadAudio goes to dm-audio at <user>/<id>.m4a as audio/mp4', () async {
    final s = _Storage();
    final f = File('${Directory.systemTemp.path}/dm-uploader-test.m4a')..writeAsBytesSync([1, 2, 3]);
    addTearDown(() => f.deleteSync());
    final path = await SupabaseDmMediaUploader(s).uploadAudio(userId: 'u1', file: f, pathId: 'a-1');
    expect(path, 'u1/a-1.m4a');
    expect(s.puts.single.bucket, 'dm-audio');
    expect(s.puts.single.contentType, 'audio/mp4');
    expect(s.puts.single.length, 3);
  });

  test('a duplicate-object error (409) resolves to the same path: the first attempt landed and its response was lost', () async {
    final s = _Storage()..error = const StorageException('The resource already exists', statusCode: '409', error: 'Duplicate');
    final path = await SupabaseDmMediaUploader(s).uploadImage(userId: 'u1', jpeg: Uint8List(1), pathId: 'p-1');
    expect(path, 'u1/p-1.jpg');
  });

  test('"Duplicate" in the error text is also treated as success', () async {
    final s = _Storage()..error = const StorageException('Duplicate');
    expect(await SupabaseDmMediaUploader(s).uploadImage(userId: 'u1', jpeg: Uint8List(1), pathId: 'p-1'), 'u1/p-1.jpg');
  });

  test('any other error is rethrown', () async {
    final s = _Storage()..error = const StorageException('Payload too large', statusCode: '413');
    await expectLater(SupabaseDmMediaUploader(s).uploadImage(userId: 'u1', jpeg: Uint8List(1), pathId: 'p-1'), throwsA(isA<StorageException>()));
    s.error = StateError('socket closed');
    await expectLater(SupabaseDmMediaUploader(s).uploadImage(userId: 'u1', jpeg: Uint8List(1), pathId: 'p-1'), throwsStateError);
  });
}
