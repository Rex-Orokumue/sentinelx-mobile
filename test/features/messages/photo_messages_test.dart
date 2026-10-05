import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:sentinelx_mobile/features/match/evidence.dart' show PickedImage;
import 'package:sentinelx_mobile/features/messages/dm_image_pipeline.dart';
import 'package:sentinelx_mobile/features/messages/dm_media_uploader.dart';

import '../../fakes/fake_dm_media.dart';
import '../../fakes/fake_messages_repository.dart';
import '../../support/pump_conversation.dart';

Uint8List _smallJpeg() => Uint8List.fromList(img.encodeJpg(img.Image(width: 40, height: 30)));

FakeMessagesRepository _repo() => FakeMessagesRepository()..messagesByThread['t1'] = [dmMsg('a', body: 'hi', at: kNow.subtract(const Duration(minutes: 5)))];

class _Media {
  _Media({Uint8List? bytes}) : picker = FakeDmImagePicker(PickedImage(name: 'p.jpg', bytes: bytes ?? _smallJpeg()));
  final FakeDmMediaUploader uploader = FakeDmMediaUploader();
  final FakeDmImagePicker picker;

  List<dynamic> get overrides => [
        dmMediaUploaderProvider.overrideWithValue(uploader),
        dmImagePickerProvider.overrideWithValue(picker),
        dmImageSanitizerProvider.overrideWithValue((b) async => b),
      ];
}

Future<void> _attach(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('dm-photo-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('dm-photo-library')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('picking shows a pending image bubble built from the local bytes while the upload runs', (tester) async {
    final media = _Media();
    media.uploader.hold = Completer<void>();
    await pumpConversation(tester, _repo(), overrides: [...media.overrides.cast()]);
    await _attach(tester);
    await tester.pump();
    final bubble = find.byKey(const Key('dm-pending-image-local-0'));
    expect(bubble, findsOneWidget);
    expect(tester.widget<Image>(bubble).image, isA<MemoryImage>(), reason: 'never the remote URL');
    expect(media.picker.sources, [ImageSource.gallery]);
  });

  testWidgets('the send waits for the upload and carries exactly the uploaded path', (tester) async {
    final media = _Media();
    final gate = Completer<void>();
    media.uploader.hold = gate;
    final repo = _repo();
    await pumpConversation(tester, repo, overrides: [...media.overrides.cast()]);
    await _attach(tester);
    await tester.pump();
    expect(repo.sendCalls, isEmpty, reason: 'nothing is sent before the upload resolves');
    gate.complete();
    await tester.pumpAndSettle();
    final up = media.uploader.imageUploads.single;
    expect(up.userId, 'me');
    expect(repo.sendCalls.single.draft.imagePath, 'me/${up.pathId}.jpg');
    expect(repo.sendCalls.single.draft.imagePath!.startsWith('me/'), isTrue);
  });

  testWidgets('a retry after a failed send reuses the same path id and key and does not upload twice', (tester) async {
    final media = _Media();
    final repo = _repo()..failures['send'] = networkError;
    await pumpConversation(tester, repo, overrides: [...media.overrides.cast()]);
    await _attach(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dm-retry-local-0')), findsOneWidget);
    repo.failures.clear();
    await tester.tap(find.byKey(const Key('dm-retry-local-0')));
    await tester.pumpAndSettle();
    expect(media.uploader.imageUploads, hasLength(1), reason: 'the upload had already succeeded');
    expect(repo.sendCalls, hasLength(2));
    expect(repo.sendCalls[0].key, repo.sendCalls[1].key);
    expect(repo.sendCalls[0].draft.imagePath, repo.sendCalls[1].draft.imagePath);
    expect(repo.createdMessageCount, 1);
  });

  testWidgets('an upload failure shows a failed bubble; retry uploads again under the same path id', (tester) async {
    final media = _Media();
    media.uploader.failure = networkError;
    final repo = _repo();
    await pumpConversation(tester, repo, overrides: [...media.overrides.cast()]);
    await _attach(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dm-retry-local-0')), findsOneWidget);
    expect(repo.sendCalls, isEmpty);
    media.uploader.failure = null;
    await tester.tap(find.byKey(const Key('dm-retry-local-0')));
    await tester.pumpAndSettle();
    expect(media.uploader.imageUploads, hasLength(2));
    expect(media.uploader.imageUploads[0].pathId, media.uploader.imageUploads[1].pathId);
    expect(repo.sendCalls, hasLength(1));
  });

  testWidgets('a picked file over 25 MB is rejected before upload, with copy', (tester) async {
    final media = _Media(bytes: Uint8List(kMaxPickedBytes + 1));
    final repo = _repo();
    await pumpConversation(tester, repo, overrides: [...media.overrides.cast()]);
    await _attach(tester);
    await tester.pumpAndSettle();
    expect(find.text('That photo is too large to send.'), findsOneWidget);
    expect(media.uploader.imageUploads, isEmpty);
    expect(repo.sendCalls, isEmpty);
    expect(find.byKey(const Key('dm-pending-local-0')), findsNothing);
  });

  testWidgets('a sanitized result over 3 MB is rejected before upload', (tester) async {
    final media = _Media();
    final repo = _repo();
    await pumpConversation(tester, repo, overrides: [
      dmMediaUploaderProvider.overrideWithValue(media.uploader),
      dmImagePickerProvider.overrideWithValue(media.picker),
      dmImageSanitizerProvider.overrideWithValue((b) async => Uint8List(kMaxSanitizedBytes + 1)),
    ]);
    await _attach(tester);
    await tester.pumpAndSettle();
    expect(find.text('That photo is too large to send.'), findsOneWidget);
    expect(media.uploader.imageUploads, isEmpty);
  });

  testWidgets('bytes that are not an image are rejected with the generic copy', (tester) async {
    final media = _Media();
    await pumpConversation(tester, _repo(), overrides: [
      dmMediaUploaderProvider.overrideWithValue(media.uploader),
      dmImagePickerProvider.overrideWithValue(media.picker),
      dmImageSanitizerProvider.overrideWithValue((b) async => throw const FormatException('not an image')),
    ]);
    await _attach(tester);
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(media.uploader.imageUploads, isEmpty);
  });

  testWidgets('cancelling the picker sends nothing', (tester) async {
    final media = _Media();
    media.picker.result = null;
    final repo = _repo();
    await pumpConversation(tester, repo, overrides: [...media.overrides.cast()]);
    await _attach(tester);
    await tester.pumpAndSettle();
    expect(media.uploader.imageUploads, isEmpty);
    expect(repo.sendCalls, isEmpty);
  });

  testWidgets('an image whose signed URL fails triggers exactly one rate-limited window refetch', (tester) async {
    final repo = FakeMessagesRepository()
      ..messagesByThread['t1'] = [
        dmMsg('i1', imageUrl: 'https://expired.test/a.jpg', at: kNow.subtract(const Duration(minutes: 2))),
        dmMsg('i2', imageUrl: 'https://expired.test/b.jpg', at: kNow.subtract(const Duration(minutes: 3))),
      ];
    await tester.runAsync(() async {});
    await pumpConversation(tester, repo);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dm-image-placeholder')), findsWidgets);
    expect(repo.messagesCalls, hasLength(2), reason: 'first load plus ONE refetch for both failing images (same 30 s window)');
  });
}
