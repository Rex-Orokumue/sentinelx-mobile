import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:sentinelx_mobile/features/match/evidence.dart' show PickedImage;
import 'package:sentinelx_mobile/features/messages/dm_image_pipeline.dart';
import 'package:sentinelx_mobile/features/messages/dm_media_uploader.dart';

class FakeDmMediaUploader implements DmMediaUploader {
  final imageUploads = <({String userId, String pathId, int length})>[];
  final audioUploads = <({String userId, String pathId})>[];

  /// The next upload waits on this (then clears it).
  Completer<void>? hold;

  /// Thrown by every upload until cleared.
  Object? failure;

  Future<void> _enter() async {
    final h = hold;
    hold = null;
    if (h != null) await h.future;
    final f = failure;
    if (f != null) throw f;
  }

  @override
  Future<String> uploadImage({required String userId, required Uint8List jpeg, required String pathId}) async {
    imageUploads.add((userId: userId, pathId: pathId, length: jpeg.length));
    await _enter();
    return dmMediaPath(userId: userId, id: pathId, ext: 'jpg');
  }

  @override
  Future<String> uploadAudio({required String userId, required File file, required String pathId}) async {
    audioUploads.add((userId: userId, pathId: pathId));
    await _enter();
    return dmMediaPath(userId: userId, id: pathId, ext: 'm4a');
  }
}

class FakeDmImagePicker implements DmImagePicker {
  FakeDmImagePicker([this.result]);

  PickedImage? result;
  final sources = <ImageSource>[];

  @override
  Future<PickedImage?> pick(ImageSource source) async {
    sources.add(source);
    return result;
  }
}
