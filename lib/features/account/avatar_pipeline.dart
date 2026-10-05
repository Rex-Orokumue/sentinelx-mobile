import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../messages/dm_image_pipeline.dart' show DmImagePicker, PluginDmImagePicker;

/// Center-crops to a square, caps at [size] px (never upscales), re-encodes as JPEG with an EMPTY EXIF block.
/// Avatars are public and most players are minors, so GPS must never leave the device.
Uint8List sanitizeAvatar(Uint8List bytes, {int size = 400, int quality = 85}) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    throw const FormatException('not an image');
  }
  if (decoded == null) throw const FormatException('not an image');
  var im = img.bakeOrientation(decoded);
  final side = im.width < im.height ? im.width : im.height;
  im = img.copyCrop(im, x: (im.width - side) ~/ 2, y: (im.height - side) ~/ 2, width: side, height: side);
  if (side > size) im = img.copyResize(im, width: size, height: size);
  im.exif = img.ExifData(); // the privacy step
  return Uint8List.fromList(img.encodeJpg(im, quality: quality));
}

Future<Uint8List> sanitizeAvatarIsolated(Uint8List bytes) => compute(sanitizeAvatar, bytes);

final avatarSanitizerProvider = Provider<Future<Uint8List> Function(Uint8List)>((_) => sanitizeAvatarIsolated);
final avatarPickerProvider = Provider<DmImagePicker>((_) => PluginDmImagePicker());
