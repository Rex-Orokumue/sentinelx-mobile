import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sentinelx_mobile/features/messages/dm_image_pipeline.dart';

/// A JPEG carrying a GPS tag and a camera make, like a phone photo.
Uint8List _jpegWithExif(int w, int h) {
  final src = img.Image(width: w, height: h);
  img.fill(src, color: img.ColorRgb8(200, 80, 40));
  src.exif.gpsIfd.gpsLatitudeRef = 'N';
  src.exif.imageIfd.make = 'TestCam';
  return Uint8List.fromList(img.encodeJpg(src));
}

void main() {
  test('the fixture really carries GPS and Make (so the strip test cannot pass vacuously)', () {
    final decoded = img.decodeJpg(_jpegWithExif(3000, 2000))!;
    expect(decoded.exif.gpsIfd.gpsLatitudeRef, 'N');
    expect(decoded.exif.imageIfd.hasMake, isTrue);
  });

  test('sanitizeJpeg strips EXIF/GPS and caps the long edge at 1600 (3000x2000 -> 1600x1067)', () {
    final fixture = _jpegWithExif(3000, 2000);
    final before = img.decodeJpg(fixture)!;
    expect(before.exif.imageIfd.hasMake, isTrue, reason: 'precondition: the input has EXIF');

    final out = sanitizeJpeg(fixture);
    final after = img.decodeJpg(out)!;
    // MUTATION GUARD: removing `exif = ExifData()` in sanitizeJpeg makes the next two lines fail
    // (a plain decode/encode keeps both tags: image_picker's resize copies EXIF back, GPS included).
    expect(after.exif.imageIfd.hasMake, isFalse);
    expect(after.exif.gpsIfd.gpsLatitudeRef, isNull);
    expect(after.width, 1600);
    expect(after.height, 1067);
    expect(out[0], 0xFF);
    expect(out[1], 0xD8);
  });

  test('a portrait is capped on its long (vertical) edge: 1200x4000 -> 480x1600', () {
    final after = img.decodeJpg(sanitizeJpeg(_jpegWithExif(1200, 4000)))!;
    expect(after.width, 480);
    expect(after.height, 1600);
  });

  test('an image already under the cap is not upscaled', () {
    final after = img.decodeJpg(sanitizeJpeg(_jpegWithExif(800, 600)))!;
    expect(after.width, 800);
    expect(after.height, 600);
  });

  test('PNG input comes out as a JPEG within the cap', () {
    final png = Uint8List.fromList(img.encodePng(img.Image(width: 2400, height: 1200)));
    final out = sanitizeJpeg(png);
    expect(out[0], 0xFF);
    expect(out[1], 0xD8);
    final after = img.decodeJpg(out)!;
    expect(after.width, 1600);
    expect(after.height, 800);
  });

  test('bytes that are not an image throw FormatException', () {
    expect(() => sanitizeJpeg(Uint8List.fromList([1, 2, 3, 4, 5])), throwsFormatException);
  });

  test('the isolated variant produces the same sanitized result', () async {
    final out = await sanitizeJpegIsolated(_jpegWithExif(2000, 1000));
    final after = img.decodeJpg(out)!;
    expect(after.width, 1600);
    expect(after.exif.imageIfd.hasMake, isFalse);
  });
}
