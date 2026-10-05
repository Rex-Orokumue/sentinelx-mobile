import 'dart:async';
import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:record/record.dart';

/// AAC-LC in an `.m4a`, mono, 44.1 kHz, 64 kbit/s: small, universally playable, and what the server expects.
const kVoiceRecordConfig = RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1);

/// Microphone permission as `record` reports it (Ruling 1: `permission_handler` breaks this project's Android
/// build, so permission goes through `record`; denied-once and denied-forever cannot be told apart, so the
/// denial UI always offers both Try again and Open settings).
enum MicPermission { granted, denied }

enum VoiceRecorderState { recording, paused, stopped }

/// Everything the voice controller needs from the platform recorder. Production wraps `record` 6.2.1; tests
/// use a fake. An audio-focus loss (a call, another app) pauses the recorder: that arrives as [states] paused.
abstract class VoiceRecorderPort {
  /// Shows the OS dialog when needed.
  Future<MicPermission> ensurePermission();

  /// Reads the permission without asking.
  Future<MicPermission> peekPermission();

  /// AAC-LC in an `.m4a`, mono, 44.1 kHz, 64 kbit/s.
  Future<void> start(String path);
  Future<void> pause();
  Future<void> resume();

  /// The finished file's path, or null.
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
  Stream<VoiceRecorderState> get states;

  /// 0..1.
  Stream<double> get levels;
}

class RecordVoiceRecorder implements VoiceRecorderPort {
  RecordVoiceRecorder() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<MicPermission> ensurePermission() async => await _recorder.hasPermission() ? MicPermission.granted : MicPermission.denied;

  @override
  Future<MicPermission> peekPermission() async => await _recorder.hasPermission(request: false) ? MicPermission.granted : MicPermission.denied;

  @override
  Future<void> start(String path) => _recorder.start(kVoiceRecordConfig, path: path);

  @override
  Future<void> pause() => _recorder.pause();

  @override
  Future<void> resume() => _recorder.resume();

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();

  @override
  Stream<VoiceRecorderState> get states => _recorder.onStateChanged().map((s) => switch (s) {
        RecordState.record => VoiceRecorderState.recording,
        RecordState.pause => VoiceRecorderState.paused,
        RecordState.stop => VoiceRecorderState.stopped,
      });

  @override
  Stream<double> get levels => _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).map((a) {
        // dBFS (-160..0) to a 0..1 meter, flooring at -60 dB
        final db = a.current.clamp(-60.0, 0.0);
        return (db + 60) / 60;
      });
}

enum VoicePlayerState { idle, loading, playing, paused, completed, error }

abstract class VoicePlayerPort {
  /// A local file path or a signed https URL.
  Future<void> load(String urlOrPath);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Stream<Duration> get position;
  Stream<VoicePlayerState> get state;
  Duration? get duration;
  Future<void> dispose();
}

class JustAudioVoicePlayer implements VoicePlayerPort {
  final _player = ja.AudioPlayer();

  @override
  Future<void> load(String urlOrPath) async {
    if (urlOrPath.startsWith('http')) {
      await _player.setUrl(urlOrPath);
    } else {
      await _player.setFilePath(urlOrPath);
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Stream<VoicePlayerState> get state => _player.playerStateStream.map((s) {
        switch (s.processingState) {
          case ja.ProcessingState.idle:
            return VoicePlayerState.idle;
          case ja.ProcessingState.loading:
          case ja.ProcessingState.buffering:
            return VoicePlayerState.loading;
          case ja.ProcessingState.completed:
            return VoicePlayerState.completed;
          case ja.ProcessingState.ready:
            return s.playing ? VoicePlayerState.playing : VoicePlayerState.paused;
        }
      });

  @override
  Duration? get duration => _player.duration;

  @override
  Future<void> dispose() => _player.dispose();
}

final voiceRecorderFactoryProvider = Provider<VoiceRecorderPort Function()>((_) => RecordVoiceRecorder.new);
final voicePlayerFactoryProvider = Provider<VoicePlayerPort Function()>((_) => JustAudioVoicePlayer.new);

/// The cache directory recordings are written to (`Directory.systemTemp` is the app cache dir on Android).
final voiceTempDirProvider = Provider<Directory Function()>((_) => () => Directory.systemTemp);

/// Opens the system settings page for this app, for the microphone-denied banner.
final openAppSettingsProvider = Provider<Future<void> Function()>((_) => () => AppSettings.openAppSettings(type: AppSettingsType.settings));

/// Which voice bubble is currently playing (null = none). Starting one pauses the others.
class ActiveVoicePlayer extends Notifier<String?> {
  @override
  String? build() => null;

  void start(String id) => state = id;

  void stop(String id) {
    if (state == id) state = null;
  }
}

final activeVoicePlayerProvider = NotifierProvider<ActiveVoicePlayer, String?>(ActiveVoicePlayer.new);
