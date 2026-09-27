import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/utils/write_flow.dart';
import 'package:sentinelx_mobile/features/match/evidence.dart';

ApiException _err(int status, String code) => ApiException(status: status, code: code, message: 'x');

class _FakeUploader implements EvidenceUploader {
  final calls = <PickedImage>[];
  Object? failWith;

  @override
  Future<String> upload({required String userId, required String scopeId, required PickedImage image}) async {
    calls.add(image);
    final f = failWith;
    if (f != null) throw f;
    return '$userId/$scopeId/${calls.length}-${image.name}';
  }
}

PickedImage _img(String name) => PickedImage(name: name, bytes: Uint8List.fromList([1, 2, 3]));

class _Rig {
  _Rig() {
    container = ProviderContainer(retry: (_, _) => null);
    container.listen(writeFlowProvider('result:m1'), (_, _) {});
    submitter = ResultSubmitter(uploader: uploader, userId: 'u1', scopeId: 'm1');
  }
  late final ProviderContainer container;
  final uploader = _FakeUploader();
  late final ResultSubmitter submitter;
  final paths = <String>[];
  final keys = <String>[];
  WriteFlow get flow => container.read(writeFlowProvider('result:m1').notifier);
  WriteState get state => container.read(writeFlowProvider('result:m1'));

  Future<bool> submit(PickedImage image, {Object? sendError, Object? fingerprint}) => submitter.submit(
        flow: flow,
        image: image,
        fingerprint: fingerprint,
        send: (path, key) async {
          paths.add(path);
          keys.add(key);
          if (sendError != null) throw sendError;
        },
      );
}

void main() {
  test('evidencePath sanitizes the file name like the website', () {
    expect(
      evidencePath(userId: 'u1', scopeId: 'm1', fileName: 'my shot (1).png', now: DateTime.fromMillisecondsSinceEpoch(1700000000000)),
      'u1/m1/1700000000000-my_shot__1_.png',
    );
  });

  test('success uploads once and sends the uploaded path with a key', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    expect(await r.submit(_img('a.png')), isTrue);
    expect(r.uploader.calls, hasLength(1));
    expect(r.paths.single, 'u1/m1/1-a.png');
    expect(r.keys.single, isNotEmpty);
    expect(r.state.phase, WritePhase.done);
  });

  test('POST fails with a server error: retry with the same image does not re-upload and mints a new key', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    final image = _img('a.png');
    expect(await r.submit(image, sendError: _err(409, 'submission_locked')), isFalse);
    expect(r.state.errorCode, 'submission_locked');
    expect(await r.submit(image), isTrue);
    expect(r.uploader.calls, hasLength(1));
    expect(r.paths, ['u1/m1/1-a.png', 'u1/m1/1-a.png']);
    expect(r.keys[1], isNot(r.keys[0]));
  });

  test('POST fails with network: retry reuses the key and the path, one upload', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    final image = _img('a.png');
    await r.submit(image, sendError: _err(0, 'network'));
    await r.submit(image);
    expect(r.uploader.calls, hasLength(1));
    expect(r.paths[1], r.paths[0]);
    expect(r.keys[1], r.keys[0]);
  });

  test('a different PickedImage instance uploads again', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.submit(_img('a.png'), sendError: _err(409, 'submission_locked'));
    await r.submit(_img('a.png'));
    expect(r.uploader.calls, hasLength(2));
    expect(r.paths[1], isNot(r.paths[0]));
  });

  test('network failure then an edited retry (changed fingerprint) mints a new key, same upload', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    final image = _img('a.png');
    await r.submit(image, sendError: _err(0, 'network'), fingerprint: '2:1:');
    await r.submit(image, fingerprint: '3:1:');
    expect(r.uploader.calls, hasLength(1)); // same image, uploaded once
    expect(r.keys[1], isNot(r.keys[0])); // different scores must not replay the old key's stored response
  });

  test('network failure then an unchanged retry (same fingerprint) reuses the key', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    final image = _img('a.png');
    await r.submit(image, sendError: _err(0, 'network'), fingerprint: '2:1:');
    await r.submit(image, fingerprint: '2:1:');
    expect(r.keys[1], r.keys[0]);
  });

  test('upload failure reports upload_failed, sends nothing, and the next attempt uses a new key', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    final image = _img('a.png');
    final k0 = r.flow.currentKey;
    r.uploader.failWith = Exception('storage down');
    expect(await r.submit(image), isFalse);
    expect(r.state.errorCode, 'upload_failed');
    expect(r.keys, isEmpty);
    r.uploader.failWith = null;
    expect(await r.submit(image), isTrue);
    expect(r.uploader.calls, hasLength(2));
    expect(r.keys.single, isNot(k0));
  });
}
