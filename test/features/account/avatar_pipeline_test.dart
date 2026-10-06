import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sentinelx_mobile/features/account/avatar_pipeline.dart';

Uint8List _jpegWithExif(int w, int h) {
  final src = img.Image(width: w, height: h);
  img.fill(src, color: img.ColorRgb8(200, 80, 40));
  src.exif.gpsIfd.gpsLatitudeRef = 'N';
  src.exif.imageIfd.make = 'TestCam';
  return Uint8List.fromList(img.encodeJpg(src));
}

void main() {
  test('the fixture really carries GPS and Make (the strip test cannot pass vacuously)', () {
    final d = img.decodeJpg(_jpegWithExif(3000, 2000))!;
    expect(d.exif.gpsIfd.gpsLatitudeRef, 'N');
    expect(d.exif.imageIfd.hasMake, isTrue);
  });
  test('strips EXIF/GPS and returns a 400x400 square JPEG', () {
    final out = sanitizeAvatar(_jpegWithExif(3000, 2000));
    final after = img.decodeJpg(out)!;
    expect(after.exif.imageIfd.hasMake, isFalse);      // MUTATION GUARD: removing `im.exif = ExifData()` fails these two
    expect(after.exif.gpsIfd.gpsLatitudeRef, isNull);
    expect([after.width, after.height], [400, 400]);
    expect(out[0], 0xFF); expect(out[1], 0xD8);
  });
  test('a portrait is center-cropped square (1000x3000 -> 400x400)', () {
    final after = img.decodeJpg(sanitizeAvatar(_jpegWithExif(1000, 3000)))!;
    expect([after.width, after.height], [400, 400]);
  });
  test('never upscales: 100x80 -> 80x80', () {
    final after = img.decodeJpg(sanitizeAvatar(_jpegWithExif(100, 80)))!;
    expect([after.width, after.height], [80, 80]);
  });
  test('non-image bytes throw FormatException', () {
    expect(() => sanitizeAvatar(Uint8List.fromList([1, 2, 3])), throwsFormatException);
  });
}
