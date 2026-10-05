import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart' show AudioEncoder;
import 'package:sentinelx_mobile/core/realtime/realtime_hub.dart';
import 'package:sentinelx_mobile/features/messages/dm_media_uploader.dart';
import 'package:sentinelx_mobile/features/messages/inbox_providers.dart';
import 'package:sentinelx_mobile/features/messages/thread_providers.dart';
import 'package:sentinelx_mobile/features/messages/voice/voice_ports.dart';
import 'package:sentinelx_mobile/features/messages/voice/voice_recorder_controller.dart';

import '../../../fakes/fake_dm_media.dart';
import '../../../fakes/fake_messages_repository.dart';
import '../../../fakes/fake_voice.dart';

const _t = 't1';

class _Rig {
  _Rig() {
    tmp = Directory.systemTemp.createTempSync('dm-voice-test');
    container = ProviderContainer(retry: (_, _) => null, overrides: [
      voiceRecorderFactoryProvider.overrideWithValue(() => recorder),
      voiceTempDirProvider.overrideWithValue(() => tmp),
      dmClockProvider.overrideWithValue(() => now),
      messagesRepositoryProvider.overrideWithValue(repo),
      dmViewerIdProvider.overrideWith((ref) async => 'me'),
      dmNudgeProvider.overrideWith((ref) => const Stream<RealtimeSignal>.empty()),
      dmMediaUploaderProvider.overrideWithValue(uploader),
    ]);
    container.listen(voiceRecorderControllerProvider(_t), (_, _) {});
  }

  final recorder = FakeVoiceRecorder();
  final uploader = FakeDmMediaUploader();
  final repo = FakeMessagesRepository()..messagesByThread[_t] = [];
  late final Directory tmp;
  late final ProviderContainer container;
  var now = DateTime.utc(2026, 10, 5, 12);

  VoiceRecorderController get ctl => container.read(voiceRecorderControllerProvider(_t).notifier);
  VoiceState get state => container.read(voiceRecorderControllerProvider(_t));

  void advance(Duration d) => now = now.add(d);

  Future<void> loadThread() async {
    container.listen(threadProvider(_t), (_, _) {});
    await container.read(threadProvider(_t).future);
  }

  void dispose() {
    container.dispose();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  }
}

_Rig _rig() {
  final r = _Rig();
  addTearDown(r.dispose);
  return r;
}

Future<void> _record(_Rig r, Duration length) async {
  await r.ctl.begin();
  r.advance(length);
  await r.ctl.stopToReview();
}

void main() {
  test('begin with permission granted starts the recorder on an .m4a in the cache dir with the exact AAC-LC config', () async {
    final r = _rig();
    await r.ctl.begin();
    expect(r.state.phase, VoicePhase.recording);
    final path = r.recorder.startedPaths.single;
    expect(path.endsWith('.m4a'), isTrue);
    expect(path.startsWith(r.tmp.path), isTrue);
    expect(kVoiceRecordConfig.encoder, AudioEncoder.aacLc);
    expect(kVoiceRecordConfig.bitRate, 64000);
    expect(kVoiceRecordConfig.sampleRate, 44100);
    expect(kVoiceRecordConfig.numChannels, 1);
  });

  group('permission (Ruling 1)', () {
    test('denied shows permissionDenied and never starts the recorder', () async {
      final r = _rig();
      r.recorder.ensureResult = MicPermission.denied;
      await r.ctl.begin();
      expect(r.state.phase, VoicePhase.permissionDenied);
      expect(r.recorder.startedPaths, isEmpty);
    });

    test('Try again asks again and proceeds once granted', () async {
      final r = _rig();
      r.recorder.ensureResult = MicPermission.denied;
      await r.ctl.begin();
      r.recorder.ensureResult = MicPermission.granted;
      await r.ctl.begin();
      expect(r.recorder.ensureCalls, 2);
      expect(r.state.phase, VoicePhase.recording);
    });

    test('coming back from settings with access granted returns to idle', () async {
      final r = _rig();
      r.recorder.ensureResult = MicPermission.denied;
      await r.ctl.begin();
      r.recorder.peekResult = MicPermission.granted;
      await r.ctl.recheckPermission();
      expect(r.state.phase, VoicePhase.idle);
      expect(r.recorder.peekCalls, 1);
    });

    test('coming back with access still denied stays on the banner', () async {
      final r = _rig();
      r.recorder.ensureResult = MicPermission.denied;
      await r.ctl.begin();
      await r.ctl.recheckPermission();
      expect(r.state.phase, VoicePhase.permissionDenied);
    });
  });

  group('recording', () {
    test('elapsed counts only recording time: 5 s, pause 10 s, resume 5 s is 10 s', () async {
      final r = _rig();
      await r.ctl.begin();
      r.advance(const Duration(seconds: 5));
      await r.ctl.pause();
      expect(r.state.phase, VoicePhase.paused);
      r.advance(const Duration(seconds: 10));
      await r.ctl.resume();
      r.advance(const Duration(seconds: 5));
      await r.ctl.stopToReview();
      expect(r.state.phase, VoicePhase.review);
      expect(r.state.elapsed, const Duration(seconds: 10));
    });

    test('the 120 s cap stops into review (never into upload) and stops the recorder', () async {
      final r = _rig();
      await r.ctl.begin();
      r.advance(const Duration(seconds: 121));
      await Future<void>.delayed(const Duration(milliseconds: 250)); // the 100 ms ticker notices
      expect(r.state.phase, VoicePhase.review);
      expect(r.state.elapsed, const Duration(seconds: kMaxVoiceSeconds));
      expect(r.recorder.calls, contains('stop'));
      expect(r.uploader.audioUploads, isEmpty);
      expect(r.repo.sendCalls, isEmpty);
    });

    test('an audio-focus pause (a call) shows paused, does not discard and never auto-resumes', () async {
      final r = _rig();
      await r.ctl.begin();
      r.advance(const Duration(seconds: 3));
      r.recorder.focusLost();
      expect(r.state.phase, VoicePhase.paused);
      r.advance(const Duration(minutes: 5));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(r.state.phase, VoicePhase.paused);
      expect(r.recorder.calls, isNot(contains('resume')));
      await r.ctl.stopToReview();
      expect(r.state.elapsed, const Duration(seconds: 3), reason: 'the call time was not recorded');
    });

    test('a recording under one second is discarded: file deleted, idle, with the too-short flag', () async {
      final r = _rig();
      await _record(r, const Duration(milliseconds: 500));
      expect(r.state.phase, VoicePhase.idle);
      expect(r.state.tooShort, isTrue);
      expect(File(r.recorder.startedPaths.single).existsSync(), isFalse);
      r.ctl.clearTooShort();
      expect(r.state.tooShort, isFalse);
    });

    test('discard cancels the recorder and deletes the file', () async {
      final r = _rig();
      await r.ctl.begin();
      final path = r.recorder.startedPaths.single;
      expect(File(path).existsSync(), isTrue);
      await r.ctl.discard();
      expect(r.state.phase, VoicePhase.idle);
      expect(r.recorder.cancelled, isTrue);
      expect(File(path).existsSync(), isFalse);
    });

    test('discard from review deletes the file', () async {
      final r = _rig();
      await _record(r, const Duration(seconds: 4));
      final path = r.state.file!.path;
      await r.ctl.discard();
      expect(File(path).existsSync(), isFalse);
      expect(r.state.phase, VoicePhase.idle);
    });

    test('disposing while recording cancels and disposes the recorder and deletes the file', () async {
      final r = _rig();
      await r.ctl.begin();
      final path = r.recorder.startedPaths.single;
      r.container.dispose();
      await pumpEventQueue();
      expect(r.recorder.cancelled, isTrue);
      expect(r.recorder.disposed, isTrue);
      expect(File(path).existsSync(), isFalse);
    });

    test('two recordings never share a file name', () async {
      final r = _rig();
      await _record(r, const Duration(seconds: 3));
      await r.ctl.discard();
      await _record(r, const Duration(seconds: 3));
      expect(r.recorder.startedPaths.toSet(), hasLength(2));
    });

    test('a recorder that fails to start leaves the controller idle', () async {
      final r = _rig();
      r.recorder.startError = StateError('mic busy');
      await r.ctl.begin();
      expect(r.state.phase, VoicePhase.idle);
    });
  });

  group('send', () {
    test('uploads once to <user>/<uuid>.m4a and sends the duration as a ceiling int within 1..120', () async {
      final r = _rig();
      await r.loadThread();
      await _record(r, const Duration(milliseconds: 4200));
      await r.ctl.send();
      await pumpEventQueue();
      final up = r.uploader.audioUploads.single;
      expect(up.userId, 'me');
      expect(r.repo.sendCalls.single.draft.audioPath, 'me/${up.pathId}.m4a');
      expect(r.repo.sendCalls.single.draft.audioDurationSeconds, 5);
      expect(r.repo.sendCalls.single.draft.audioDurationSeconds, isA<int>());
      expect(r.state.phase, VoicePhase.idle);
    });

    test('119.9 s sends 120 and a value over the cap is clamped', () async {
      final r = _rig();
      await r.loadThread();
      await _record(r, const Duration(milliseconds: 119900));
      await r.ctl.send();
      await pumpEventQueue();
      expect(r.repo.sendCalls.single.draft.audioDurationSeconds, 120);
    });

    test('the temp file is deleted after the message is confirmed', () async {
      final r = _rig();
      await r.loadThread();
      await _record(r, const Duration(seconds: 4));
      final path = r.state.file!.path;
      await r.ctl.send();
      await pumpEventQueue();
      expect(File(path).existsSync(), isFalse);
    });

    test('on failure the file is kept; retry reuses the key and path id and does not upload twice', () async {
      final r = _rig();
      await r.loadThread();
      await _record(r, const Duration(seconds: 4));
      final path = r.state.file!.path;
      r.repo.failures['send'] = networkError;
      await r.ctl.send();
      await pumpEventQueue();
      expect(File(path).existsSync(), isTrue, reason: 'kept until success or Discard');
      final item = r.container.read(threadProvider(_t)).value!.pending.single;
      r.repo.failures.clear();
      await r.container.read(threadProvider(_t).notifier).retry(item.localId);
      await pumpEventQueue();
      expect(r.uploader.audioUploads, hasLength(1), reason: 'the first upload had succeeded');
      expect(r.repo.sendCalls, hasLength(2));
      expect(r.repo.sendCalls[0].key, r.repo.sendCalls[1].key);
      expect(r.repo.sendCalls[0].draft.audioPath, r.repo.sendCalls[1].draft.audioPath);
      expect(File(path).existsSync(), isFalse, reason: 'deleted once confirmed');
    });

    test('discarding a failed bubble deletes the file', () async {
      final r = _rig();
      await r.loadThread();
      await _record(r, const Duration(seconds: 4));
      final path = r.state.file!.path;
      r.repo.failures['send'] = networkError;
      await r.ctl.send();
      await pumpEventQueue();
      r.container.read(threadProvider(_t).notifier).discard(r.container.read(threadProvider(_t)).value!.pending.single.localId);
      expect(File(path).existsSync(), isFalse);
    });

    test('an upload failure keeps the file and retry uploads again under the same path id', () async {
      final r = _rig();
      await r.loadThread();
      await _record(r, const Duration(seconds: 4));
      r.uploader.failure = networkError;
      await r.ctl.send();
      await pumpEventQueue();
      expect(r.repo.sendCalls, isEmpty);
      r.uploader.failure = null;
      await r.container.read(threadProvider(_t).notifier).retry(r.container.read(threadProvider(_t)).value!.pending.single.localId);
      await pumpEventQueue();
      expect(r.uploader.audioUploads, hasLength(2));
      expect(r.uploader.audioUploads[0].pathId, r.uploader.audioUploads[1].pathId);
      expect(r.repo.sendCalls, hasLength(1));
    });

    test('a double tap on Send sends once', () async {
      final r = _rig();
      await r.loadThread();
      await _record(r, const Duration(seconds: 4));
      unawaited(r.ctl.send());
      unawaited(r.ctl.send());
      await pumpEventQueue();
      expect(r.repo.sendCalls, hasLength(1));
      expect(r.uploader.audioUploads, hasLength(1));
    });

    test('Send is ignored outside review', () async {
      final r = _rig();
      await r.loadThread();
      await r.ctl.send();
      await r.ctl.begin();
      await r.ctl.send();
      expect(r.repo.sendCalls, isEmpty);
    });
  });
}
