import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:sentinelx_mobile/features/account/avatar_uploader.dart';
import 'package:sentinelx_mobile/features/match/evidence.dart' show PickedImage;
import 'package:sentinelx_mobile/features/messages/dm_image_pipeline.dart' show DmImagePicker;

/// A JPEG carrying a GPS tag and a camera make, like a phone photo.
Uint8List jpegWithExif(int w, int h) {
  final src = img.Image(width: w, height: h);
  img.fill(src, color: img.ColorRgb8(200, 80, 40));
  src.exif.gpsIfd.gpsLatitudeRef = 'N';
  src.exif.imageIfd.make = 'TestCam';
  return Uint8List.fromList(img.encodeJpg(src));
}

class FakeAvatarPicker implements DmImagePicker {
  FakeAvatarPicker(this.bytes);
  final Uint8List? bytes;
  final sources = <ImageSource>[];
  @override
  Future<PickedImage?> pick(ImageSource source) async {
    sources.add(source);
    final b = bytes;
    return b == null ? null : PickedImage(name: 'a.jpg', bytes: b, mimeType: 'image/jpeg');
  }
}

class FakeAvatarUploader implements AvatarUploader {
  FakeAvatarUploader({this.fail = false});
  final bool fail;
  final uploaded = <Uint8List>[];
  @override
  Future<String> upload(Uint8List jpeg) async {
    if (fail) throw StateError('offline');
    uploaded.add(jpeg);
    return 'https://x/storage/v1/object/public/avatars/u1/a.jpg';
  }
}
