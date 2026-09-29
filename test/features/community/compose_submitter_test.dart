import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/utils/write_flow.dart';
import 'package:sentinelx_mobile/features/community/community_image_uploader.dart';
import 'package:sentinelx_mobile/features/community/compose_submitter.dart';
import 'package:sentinelx_mobile/features/match/evidence.dart';

import '../../fakes/fake_community_uploader.dart';

ApiException _err(int status, String code) => ApiException(status: status, code: code, message: 'x');

PickedImage _img(String name) => PickedImage(name: name, bytes: Uint8List.fromList([1, 2, 3]));

class _Rig {
  _Rig({CommunityImageUploader? uploader}) : uploader = uploader ?? FakeCommunityUploader() {
    container = ProviderContainer(retry: (_, _) => null);
    container.listen(writeFlowProvider('compose'), (_, _) {});
    submitter = CommunityPostSubmitter(uploader: this.uploader, userId: 'u1');
  }
  late final ProviderContainer container;
  final CommunityImageUploader uploader;
  late final CommunityPostSubmitter submitter;
  final contents = <String>[];
  final imageUrlLists = <List<String>>[];
  final keys = <String>[];

  WriteFlow get flow => container.read(writeFlowProvider('compose').notifier);
  WriteState get state => container.read(writeFlowProvider('compose'));

  Future<bool> submit({
    String content = 'hello',
    required List<PickedImage> images,
    Object? sendError,
  }) =>
      submitter.submit(
        flow: flow,
        content: content,
        images: images,
        send: (c, urls, key) async {
          contents.add(c);
          imageUrlLists.add(urls);
          keys.add(key);
          if (sendError != null) throw sendError;
        },
      );
}

void main() {
  test('two never-uploaded images both get uploaded, send receives both URLs in order', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    final images = [_img('a.png'), _img('b.png')];
    expect(await r.submit(images: images), isTrue);
    expect((r.uploader as FakeCommunityUploader).calls, hasLength(2));
    expect(r.imageUrlLists.single, ['https://fake.test/a.png', 'https://fake.test/b.png']);
    expect(r.state.phase, WritePhase.done);
  });

  test('retry after a retryable network error does not re-upload and reuses the key', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    final images = [_img('a.png'), _img('b.png')];
    expect(await r.submit(images: images, sendError: _err(0, 'network')), isFalse);
    expect(await r.submit(images: images), isTrue);
    expect((r.uploader as FakeCommunityUploader).calls, hasLength(2));
    expect(r.keys[1], r.keys[0]);
  });

  test('one image fails to upload: state becomes failed/upload_failed, send never called, next attempt mints a fresh key', () async {
    final failing = FailingCommunityUploader();
    final r = _Rig(uploader: failing);
    addTearDown(r.container.dispose);
    final images = [_img('a.png')];
    final k0 = r.flow.currentKey;
    expect(await r.submit(images: images), isFalse);
    expect(r.state.phase, WritePhase.failed);
    expect(r.state.errorCode, 'upload_failed');
    expect(r.contents, isEmpty);

    // Next attempt (even with the same images) mints a fresh key: nothing was sent to the server.
    final k1 = r.flow.currentKey;
    expect(k1, isNot(k0));
  });

  test('swapping in a third never-seen-before image on retry uploads only that one', () async {
    final fake = FakeCommunityUploader();
    final r = _Rig(uploader: fake);
    addTearDown(r.container.dispose);
    final a = _img('a.png');
    final b = _img('b.png');
    final c = _img('c.png');
    expect(await r.submit(images: [a, b], sendError: _err(0, 'network')), isFalse);
    expect(fake.calls, hasLength(2));
    expect(await r.submit(images: [a, c]), isTrue);
    expect(fake.calls, hasLength(3));
    expect(r.imageUrlLists.last, ['https://fake.test/a.png', 'https://fake.test/c.png']);
  });

  test('empty images list with non-empty content: send called with imageUrls empty, no uploader calls', () async {
    final fake = FakeCommunityUploader();
    final r = _Rig(uploader: fake);
    addTearDown(r.container.dispose);
    expect(await r.submit(images: const []), isTrue);
    expect(fake.calls, isEmpty);
    expect(r.imageUrlLists.single, isEmpty);
  });
}
