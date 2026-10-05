import 'dart:async';
import 'dart:io';

import 'package:sentinelx_mobile/features/messages/voice/voice_ports.dart';

/// A recorder the test drives by hand. `start` creates the file so deletion can be asserted.
class FakeVoiceRecorder implements VoiceRecorderPort {
  MicPermission ensureResult = MicPermission.granted;
  MicPermission peekResult = MicPermission.denied;
  int ensureCalls = 0;
  int peekCalls = 0;
  final startedPaths = <String>[];
  final calls = <String>[];
  bool disposed = false;
  bool cancelled = false;
  Object? startError;

  final _states = StreamController<VoiceRecorderState>.broadcast(sync: true);
  final _levels = StreamController<double>.broadcast(sync: true);

  @override
  Future<MicPermission> ensurePermission() async {
    ensureCalls++;
    return ensureResult;
  }

  @override
  Future<MicPermission> peekPermission() async {
    peekCalls++;
    return peekResult;
  }

  @override
  Future<void> start(String path) async {
    calls.add('start');
    if (startError != null) throw startError!;
    startedPaths.add(path);
    File(path).writeAsBytesSync([1, 2, 3]);
    _states.add(VoiceRecorderState.recording);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _states.add(VoiceRecorderState.paused);
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    _states.add(VoiceRecorderState.recording);
  }

  @override
  Future<String?> stop() async {
    calls.add('stop');
    _states.add(VoiceRecorderState.stopped);
    return startedPaths.isEmpty ? null : startedPaths.last;
  }

  @override
  Future<void> cancel() async {
    calls.add('cancel');
    cancelled = true;
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    disposed = true;
  }

  @override
  Stream<VoiceRecorderState> get states => _states.stream;

  @override
  Stream<double> get levels => _levels.stream;

  // --- test drivers ---
  /// What an audio-focus loss does: the platform pauses the recorder on its own.
  void focusLost() => _states.add(VoiceRecorderState.paused);

  void emitLevel(double v) => _levels.add(v);
}

class FakeVoicePlayer implements VoicePlayerPort {
  final loads = <String>[];
  int plays = 0;
  int pauses = 0;
  bool disposed = false;
  Object? loadError;
  final _position = StreamController<Duration>.broadcast(sync: true);
  final _state = StreamController<VoicePlayerState>.broadcast(sync: true);
  Duration? _duration;

  @override
  Future<void> load(String urlOrPath) async {
    loads.add(urlOrPath);
    if (loadError != null) {
      _state.add(VoicePlayerState.error);
      throw loadError!;
    }
    _duration = const Duration(seconds: 12);
  }

  @override
  Future<void> play() async {
    plays++;
    _state.add(VoicePlayerState.playing);
  }

  @override
  Future<void> pause() async {
    pauses++;
    _state.add(VoicePlayerState.paused);
  }

  @override
  Future<void> seek(Duration position) async => _position.add(position);

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<VoicePlayerState> get state => _state.stream;

  @override
  Duration? get duration => _duration;

  @override
  Future<void> dispose() async => disposed = true;

  // --- test drivers ---
  void emitPosition(Duration d) => _position.add(d);
  void emitState(VoicePlayerState s) => _state.add(s);
}
