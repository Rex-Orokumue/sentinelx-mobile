import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/messages_models.dart';
import 'package:sentinelx_mobile/features/messages/dm_media_uploader.dart';
import 'package:sentinelx_mobile/features/messages/voice/voice_ports.dart';

import '../../../fakes/fake_dm_media.dart';
import '../../../fakes/fake_messages_repository.dart';
import '../../../fakes/fake_voice.dart';
import '../../../support/pump_conversation.dart';

class _Env {
  _Env() {
    tmp = Directory.systemTemp.createTempSync('dm-voice-widget');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
  }

  final recorder = FakeVoiceRecorder();
  final uploader = FakeDmMediaUploader();
  final players = <FakeVoicePlayer>[];
  var settingsOpened = 0;
  var offset = Duration.zero;
  late final Directory tmp;

  /// Tests may replace how players are made (e.g. one that fails to load).
  FakeVoicePlayer Function() makePlayer = FakeVoicePlayer.new;

  DateTime clock() => kNow.add(offset);

  List<dynamic> get overrides => [
        voiceRecorderFactoryProvider.overrideWithValue(() => recorder),
        voicePlayerFactoryProvider.overrideWithValue(() {
          final p = makePlayer();
          players.add(p);
          return p;
        }),
        voiceTempDirProvider.overrideWithValue(() => tmp),
        openAppSettingsProvider.overrideWithValue(() async => settingsOpened++),
        dmMediaUploaderProvider.overrideWithValue(uploader),
      ];
}

FakeMessagesRepository _repo({ThreadHeader? header, List<DmMessage>? messages}) => FakeMessagesRepository()
  ..headers['t1'] = header ?? _accepted()
  ..messagesByThread['t1'] = messages ?? [dmMsg('a', body: 'hi', at: kNow.subtract(const Duration(minutes: 5)))];

ThreadHeader _accepted() => header('t1', name: 'Ada', otherId: 'ada-id');

Future<ConvRig> _pump(WidgetTester tester, _Env env, FakeMessagesRepository repo, {Locale locale = const Locale('en')}) =>
    pumpConversation(tester, repo, clock: env.clock, locale: locale, overrides: [...env.overrides.cast()]);

DmMessage _voice(String id, {int seconds = 12, String url = 'https://signed.test/a.m4a', int minutesAgo = 2}) =>
    dmMsg(id, audioUrl: url, audioSeconds: seconds, at: kNow.subtract(Duration(minutes: minutesAgo)));

void main() {
  group('composer', () {
    testWidgets('the mic button appears for an accepted thread and is absent while an outgoing request waits', (tester) async {
      final env = _Env();
      await _pump(tester, env, _repo());
      expect(find.byKey(const Key('dm-mic-button')), findsOneWidget);

      final env2 = _Env();
      await _pump(tester, env2, _repo(header: header('t1', name: 'Ada', requestState: RequestState.pending, direction: RequestDirection.outgoing)));
      expect(find.byKey(const Key('dm-mic-button')), findsNothing);
    });

    testWidgets('recording shows the timer and level with Pause/Resume and Stop; stopping opens the review with Play, Delete and Send', (tester) async {
      final env = _Env();
      await _pump(tester, env, _repo());
      await tester.tap(find.byKey(const Key('dm-mic-button')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('dm-voice-composer')), findsOneWidget);
      expect(find.byKey(const Key('dm-voice-timer')), findsOneWidget);
      expect(find.byKey(const Key('dm-voice-level')), findsOneWidget);
      expect(find.byKey(const Key('dm-composer')), findsNothing);

      await tester.tap(find.byKey(const Key('dm-voice-pause')));
      await tester.pump();
      expect(find.byKey(const Key('dm-voice-resume')), findsOneWidget);
      expect(find.byKey(const Key('dm-voice-paused-label')), findsOneWidget);
      await tester.tap(find.byKey(const Key('dm-voice-resume')));
      await tester.pump();
      expect(find.byKey(const Key('dm-voice-pause')), findsOneWidget);

      env.offset = const Duration(seconds: 7);
      await tester.tap(find.byKey(const Key('dm-voice-stop')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('dm-voice-play')), findsOneWidget);
      expect(find.byKey(const Key('dm-voice-delete')), findsOneWidget);
      expect(find.byKey(const Key('dm-voice-send')), findsOneWidget);
      expect(find.text('0:07'), findsOneWidget);
    });

    testWidgets('review: Play loads the local file; Delete returns to the text composer; Send hands off and returns to the text composer', (tester) async {
      final env = _Env();
      final repo = _repo();
      await _pump(tester, env, repo);
      await tester.tap(find.byKey(const Key('dm-mic-button')));
      await tester.pump();
      await tester.pump();
      env.offset = const Duration(seconds: 5);
      await tester.tap(find.byKey(const Key('dm-voice-stop')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('dm-voice-play')));
      await tester.pump();
      await tester.pump();
      expect(env.players.single.loads.single, env.recorder.startedPaths.single);
      expect(env.players.single.plays, 1);

      await tester.tap(find.byKey(const Key('dm-voice-delete')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-composer')), findsOneWidget);
      expect(File(env.recorder.startedPaths.single).existsSync(), isFalse);
      expect(repo.sendCalls, isEmpty);

      await tester.tap(find.byKey(const Key('dm-mic-button')));
      await tester.pump();
      await tester.pump();
      env.offset += const Duration(seconds: 5);
      await tester.tap(find.byKey(const Key('dm-voice-stop')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('dm-voice-send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-composer')), findsOneWidget);
      expect(repo.sendCalls.single.draft.audioDurationSeconds, 5);
    });

    testWidgets('a too-short recording says so and returns to the text composer', (tester) async {
      final env = _Env();
      await _pump(tester, env, _repo());
      await tester.tap(find.byKey(const Key('dm-mic-button')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('dm-voice-stop')));
      await tester.pumpAndSettle();
      expect(find.text('That was too short. Hold on a little longer.'), findsOneWidget);
      expect(find.byKey(const Key('dm-composer')), findsOneWidget);
    });

    testWidgets('denied shows both actions; Open settings calls app settings; Try again asks again', (tester) async {
      final env = _Env();
      env.recorder.ensureResult = MicPermission.denied;
      await _pump(tester, env, _repo());
      await tester.tap(find.byKey(const Key('dm-mic-button')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Microphone access is needed to record voice messages.'), findsOneWidget);
      expect(find.byKey(const Key('dm-mic-try-again')), findsOneWidget);
      expect(find.byKey(const Key('dm-mic-settings')), findsOneWidget);
      await tester.tap(find.byKey(const Key('dm-mic-settings')));
      await tester.pump();
      expect(env.settingsOpened, 1);
      env.recorder.ensureResult = MicPermission.granted;
      await tester.tap(find.byKey(const Key('dm-mic-try-again')));
      await tester.pump();
      await tester.pump();
      expect(env.recorder.ensureCalls, 2);
      expect(find.byKey(const Key('dm-voice-timer')), findsOneWidget);
    });

    testWidgets('returning from settings with access granted clears the banner', (tester) async {
      final env = _Env();
      env.recorder.ensureResult = MicPermission.denied;
      await _pump(tester, env, _repo());
      await tester.tap(find.byKey(const Key('dm-mic-button')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('dm-mic-settings')), findsOneWidget);
      env.recorder.peekResult = MicPermission.granted;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-mic-settings')), findsNothing);
      expect(find.byKey(const Key('dm-composer')), findsOneWidget);
    });

    testWidgets('backgrounding the app pauses a recording and does not discard it', (tester) async {
      final env = _Env();
      await _pump(tester, env, _repo());
      await tester.tap(find.byKey(const Key('dm-mic-button')));
      await tester.pump();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(env.recorder.calls, contains('pause'));
      expect(env.recorder.cancelled, isFalse);
      expect(File(env.recorder.startedPaths.single).existsSync(), isTrue);
    });

    testWidgets('popping the screen mid-recording cancels the recorder and deletes the file', (tester) async {
      final env = _Env();
      final rig = await _pump(tester, env, _repo());
      await tester.tap(find.byKey(const Key('dm-mic-button')));
      await tester.pump();
      await tester.pump();
      final path = env.recorder.startedPaths.single;
      rig.router.go('/');
      await tester.pumpAndSettle();
      expect(env.recorder.cancelled, isTrue);
      expect(env.recorder.disposed, isTrue);
      expect(File(path).existsSync(), isFalse);
    });
  });

  group('voice bubble', () {
    testWidgets('play/pause toggles and the player loads the signed URL once', (tester) async {
      final env = _Env();
      await _pump(tester, env, _repo(messages: [_voice('v1')]));
      await tester.tap(find.byKey(const Key('dm-voice-play-v1')));
      await tester.pump();
      await tester.pump();
      final player = env.players.single;
      expect(player.loads, ['https://signed.test/a.m4a']);
      expect(player.plays, 1);
      await tester.tap(find.byKey(const Key('dm-voice-play-v1')));
      await tester.pump();
      expect(player.pauses, 1);
      await tester.tap(find.byKey(const Key('dm-voice-play-v1')));
      await tester.pump();
      await tester.pump();
      expect(player.loads, hasLength(1), reason: 'already loaded');
      expect(player.plays, 2);
    });

    testWidgets('starting a second voice bubble pauses the first', (tester) async {
      final env = _Env();
      await _pump(tester, env, _repo(messages: [_voice('v1', minutesAgo: 2), _voice('v2', minutesAgo: 3, url: 'https://signed.test/b.m4a')]));
      await tester.tap(find.byKey(const Key('dm-voice-play-v1')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('dm-voice-play-v2')));
      await tester.pump();
      await tester.pump();
      expect(env.players, hasLength(2));
      expect(env.players[0].pauses, 1, reason: 'the first bubble paused when the second started');
      expect(env.players[1].plays, 1);
    });

    testWidgets('progress follows the player position', (tester) async {
      final env = _Env();
      await _pump(tester, env, _repo(messages: [_voice('v1', seconds: 10)]));
      await tester.tap(find.byKey(const Key('dm-voice-play-v1')));
      await tester.pump();
      await tester.pump();
      env.players.single.emitPosition(const Duration(seconds: 5));
      await tester.pump();
      expect(tester.widget<LinearProgressIndicator>(find.byKey(const Key('dm-voice-progress-v1'))).value, closeTo(0.5, 0.001));
    });

    testWidgets('the duration is spoken with the plural: 1 second vs 12 seconds, en and fr', (tester) async {
      Finder labelled(String l) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == l);
      await _pump(tester, _Env(), _repo(messages: [_voice('one', seconds: 1), _voice('twelve', seconds: 12, minutesAgo: 3)]));
      expect(labelled('1 second'), findsOneWidget);
      expect(labelled('12 seconds'), findsOneWidget);
      await _pump(tester, _Env(), _repo(messages: [_voice('one', seconds: 1), _voice('twelve', seconds: 12, minutesAgo: 3)]), locale: const Locale('fr'));
      expect(labelled('1 seconde'), findsOneWidget);
      expect(labelled('12 secondes'), findsOneWidget);
    });

    testWidgets('a playback error triggers exactly one window refetch and shows a retry', (tester) async {
      final env = _Env();
      var created = 0;
      env.makePlayer = () => FakeVoicePlayer()..loadError = created++ == 0 ? StateError('403 expired') : null;
      final repo = _repo(messages: [_voice('v1')]);
      await _pump(tester, env, repo);
      final base = repo.messagesCalls.length;
      await tester.tap(find.byKey(const Key('dm-voice-play-v1')));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(repo.messagesCalls.length, base + 1, reason: 'exactly one refetch');
      expect(find.byKey(const Key('dm-voice-retry-v1')), findsOneWidget);
    });

    testWidgets('a removed voice message shows the removed bubble, not a player', (tester) async {
      final repo = _repo(messages: [dmMsg('gone', deletedAt: kNow.subtract(const Duration(minutes: 1)), at: kNow.subtract(const Duration(minutes: 2)))]);
      await _pump(tester, _Env(), repo);
      expect(find.text('Message removed'), findsOneWidget);
      expect(find.byKey(const Key('dm-voice-play-gone')), findsNothing);
    });

    testWidgets('a just-sent voice message (URL not fetched yet) shows a disabled player', (tester) async {
      await _pump(tester, _Env(), _repo(messages: [_voice('fresh', url: '')]));
      expect(tester.widget<IconButton>(find.byKey(const Key('dm-voice-play-fresh'))).onPressed, isNull);
    });

    testWidgets('a long duration does not overflow at 375 px', (tester) async {
      await _pump(tester, _Env(), _repo(messages: [_voice('long', seconds: 120)]));
      expect(find.text('2:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
