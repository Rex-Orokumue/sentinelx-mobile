import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../match/evidence.dart' show PickedImage;

/// Photo limits the client enforces (the buckets set none): a picked file over [kMaxPickedBytes] is rejected
/// before any work, a sanitized result over [kMaxSanitizedBytes] before upload.
const kMaxPickedBytes = 25 * 1024 * 1024;
const kMaxSanitizedBytes = 3 * 1024 * 1024;

/// Decodes, applies the EXIF orientation, downsizes so the LONG edge is at most [maxEdge], and re-encodes as a
/// JPEG with an EMPTY EXIF block. Stripping is the point: `image_picker`'s native resize copies the original
/// EXIF back into its output, GPS tags included, and many players are minors. Never upscales.
/// Throws [FormatException] when [bytes] are not an image.
Uint8List sanitizeJpeg(Uint8List bytes, {int maxEdge = 1600, int quality = 82}) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    // the decoders throw (RangeError and friends) on truncated or non-image bytes
    throw const FormatException('not an image');
  }
  if (decoded == null) throw const FormatException('not an image');
  var im = img.bakeOrientation(decoded);
  final longEdge = im.width >= im.height ? im.width : im.height;
  if (longEdge > maxEdge) {
    im = im.width >= im.height ? img.copyResize(im, width: maxEdge) : img.copyResize(im, height: maxEdge);
  }
  im.exif = img.ExifData(); // the privacy step: a plain decode/encode would keep GPS and Make
  return Uint8List.fromList(img.encodeJpg(im, quality: quality));
}

/// [sanitizeJpeg] off the UI isolate (about 0.3-1 s of CPU for a phone photo).
Future<Uint8List> sanitizeJpegIsolated(Uint8List bytes) => compute(sanitizeJpeg, bytes);

abstract class DmImagePicker {
  /// Null when the player cancelled.
  Future<PickedImage?> pick(ImageSource source);
}

/// `image_picker` already downsizes natively; [sanitizeJpeg] runs on its output afterwards.
class PluginDmImagePicker implements DmImagePicker {
  @override
  Future<PickedImage?> pick(ImageSource source) async {
    final f = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    if (f == null) return null;
    return PickedImage(name: f.name, bytes: await f.readAsBytes(), mimeType: f.mimeType);
  }
}

final dmImagePickerProvider = Provider<DmImagePicker>((_) => PluginDmImagePicker());

/// Overridable so tests need no isolate.
final dmImageSanitizerProvider = Provider<Future<Uint8List> Function(Uint8List)>((_) => sanitizeJpegIsolated);
