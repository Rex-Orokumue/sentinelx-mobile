import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/account/avatar_field.dart';
import 'package:sentinelx_mobile/features/account/avatar_pipeline.dart';
import 'package:sentinelx_mobile/features/account/avatar_uploader.dart';

import '../../fakes/fake_avatar.dart';

Future<void> _pump(WidgetTester tester, {required FakeAvatarPicker picker, required FakeAvatarUploader uploader, required ValueChanged<String> onChanged}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      avatarPickerProvider.overrideWithValue(picker),
      avatarSanitizerProvider.overrideWithValue((b) async => sanitizeAvatar(b)),
      avatarUploaderProvider.overrideWithValue(uploader),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AvatarField(url: null, enabled: true, onChanged: onChanged)),
    ),
  ));
}

Future<void> _choose(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('avatar-change')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('avatar-source-gallery')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('uploads the SANITIZED bytes (no GPS) and reports the public URL', (tester) async {
    final uploader = FakeAvatarUploader();
    String? changed;
    await _pump(tester, picker: FakeAvatarPicker(jpegWithExif(3000, 2000)), uploader: uploader, onChanged: (u) => changed = u);
    await _choose(tester);
    final sent = img.decodeJpg(uploader.uploaded.single)!;
    expect(sent.exif.gpsIfd.gpsLatitudeRef, isNull);
    expect(sent.exif.imageIfd.hasMake, isFalse);
    expect(sent.width, 400);
    expect(changed, contains('/avatars/u1/'));
  });

  testWidgets('a non-image shows the not-an-image message and uploads nothing', (tester) async {
    final uploader = FakeAvatarUploader();
    String? changed;
    await _pump(tester, picker: FakeAvatarPicker(Uint8List.fromList([1, 2, 3])), uploader: uploader, onChanged: (u) => changed = u);
    await _choose(tester);
    expect(find.text("That file isn't a photo we can use."), findsOneWidget);
    expect(uploader.uploaded, isEmpty);
    expect(changed, isNull);
  });

  testWidgets('a picked file over the size cap shows the too-large message and uploads nothing', (tester) async {
    final uploader = FakeAvatarUploader();
    await _pump(tester, picker: FakeAvatarPicker(Uint8List(26 * 1024 * 1024)), uploader: uploader, onChanged: (_) {});
    await _choose(tester);
    expect(find.text('That photo is too large. Pick a smaller one.'), findsOneWidget);
    expect(uploader.uploaded, isEmpty);
  });

  testWidgets('an upload failure shows the failure message and reports no change', (tester) async {
    String? changed;
    await _pump(tester, picker: FakeAvatarPicker(jpegWithExif(800, 800)), uploader: FakeAvatarUploader(fail: true), onChanged: (u) => changed = u);
    await _choose(tester);
    expect(find.text("Couldn't upload your photo. Try again."), findsOneWidget);
    expect(changed, isNull);
  });

  testWidgets('cancelling the picker does nothing', (tester) async {
    final uploader = FakeAvatarUploader();
    await _pump(tester, picker: FakeAvatarPicker(null), uploader: uploader, onChanged: (_) => fail('no change'));
    await _choose(tester);
    expect(uploader.uploaded, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });
}
