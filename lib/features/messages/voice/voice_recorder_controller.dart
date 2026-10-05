import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/idempotency_key.dart';
import '../dm_media_uploader.dart';
import '../inbox_providers.dart';
import '../messages_repository.dart';
import '../thread_providers.dart';
import 'voice_ports.dart';

enum VoicePhase { idle, requestingPermission, permissionDenied, recording, paused, review }

const kMaxVoiceSeconds = 120;
const kMinVoiceSeconds = 1;

class VoiceState {
  const VoiceState({this.phase = VoicePhase.idle, this.elapsed = Duration.zero, this.level = 0, this.file, this.tooShort = false});

  final VoicePhase phase;
  final Duration elapsed;
  final double level;
  final File? file;

  /// The last recording was under one second and was discarded; the screen says so once.
  final bool tooShort;

  VoiceState copyWith({VoicePhase? phase, Duration? elapsed, double? level, File? file, bool clearFile = false, bool? tooShort}) => VoiceState(
        phase: phase ?? this.phase,
        elapsed: elapsed ?? this.elapsed,
        level: level ?? this.level,
        file: clearFile ? null : (file ?? this.file),
        tooShort: tooShort ?? this.tooShort,
      );
}

/// Records, reviews and hands off one voice note for one thread. Never auto-sends: a recording that reaches the
/// 120 s cap stops into review. Elapsed counts recording time only (pauses, including audio-focus pauses from a
/// call, do not count). The recorder is created lazily and always cancelled and disposed with the controller.
class VoiceRecorderController extends Notifier<VoiceState> {
  VoiceRecorderController(this.threadId);

  final String threadId;

  VoiceRecorderPort? _recorder;
  StreamSubscription<VoiceRecorderState>? _stateSub;
  StreamSubscription<double>? _levelSub;
  Timer? _ticker;
  Duration _accum = Duration.zero;
  DateTime? _segmentStart;
  String? _path;
  bool _handingOff = false;
  bool _running = false; // recorder started and not yet stopped/cancelled (readable while disposing)

  @override
  VoiceState build() {
    ref.onDispose(_cleanup);
    return const VoiceState();
  }

  DateTime _now() => ref.read(dmClockProvider)();

  VoiceRecorderPort get _port => _recorder ??= ref.read(voiceRecorderFactoryProvider)();

  Duration _current() => _accum + (_segmentStart == null ? Duration.zero : _now().difference(_segmentStart!));

  void _freeze() {
    final start = _segmentStart;
    if (start != null) _accum += _now().difference(start);
    _segmentStart = null;
  }

  Future<void> begin() async {
    if (!ref.mounted) return;
    if (state.phase != VoicePhase.idle && state.phase != VoicePhase.permissionDenied) return;
    state = const VoiceState(phase: VoicePhase.requestingPermission);
    final port = _port;
    final permission = await port.ensurePermission();
    if (!ref.mounted) return;
    if (permission == MicPermission.denied) {
      state = const VoiceState(phase: VoicePhase.permissionDenied);
      return;
    }
    final dir = ref.read(voiceTempDirProvider)();
    final path = '${dir.path}${Platform.pathSeparator}dm-voice-${newIdempotencyKey()}.m4a';
    try {
      await port.start(path);
    } catch (_) {
      if (ref.mounted) state = const VoiceState();
      return;
    }
    if (!ref.mounted) {
      _discardFile(path);
      return;
    }
    _path = path;
    _running = true;
    _accum = Duration.zero;
    _segmentStart = _now();
    _stateSub = port.states.listen(_onRecorderState);
    _levelSub = port.levels.listen((l) {
      if (ref.mounted && state.phase == VoicePhase.recording) state = state.copyWith(level: l);
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    state = const VoiceState(phase: VoicePhase.recording);
  }

  /// The player came back from system settings (or retried): clear the denied state once access is granted.
  Future<void> recheckPermission() async {
    if (!ref.mounted || state.phase != VoicePhase.permissionDenied) return;
    final permission = await _port.peekPermission();
    if (ref.mounted && permission == MicPermission.granted && state.phase == VoicePhase.permissionDenied) state = const VoiceState();
  }

  void _onRecorderState(VoiceRecorderState s) {
    // An audio-focus loss (phone call, another app) pauses the recorder; show it as a pause and never auto-resume.
    if (s == VoiceRecorderState.paused && state.phase == VoicePhase.recording) {
      _freeze();
      state = state.copyWith(phase: VoicePhase.paused, elapsed: _accum);
    }
  }

  void _tick() {
    if (!ref.mounted) return;
    if (state.phase != VoicePhase.recording && state.phase != VoicePhase.paused) return;
    final elapsed = _current();
    if (state.phase == VoicePhase.recording && elapsed >= const Duration(seconds: kMaxVoiceSeconds)) {
      unawaited(stopToReview());
      return;
    }
    state = state.copyWith(elapsed: elapsed);
  }

  Future<void> pause() async {
    if (!ref.mounted || state.phase != VoicePhase.recording) return;
    _freeze();
    state = state.copyWith(phase: VoicePhase.paused, elapsed: _accum);
    try {
      await _port.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (!ref.mounted || state.phase != VoicePhase.paused) return;
    try {
      await _port.resume();
    } catch (_) {
      return;
    }
    if (!ref.mounted) return;
    _segmentStart = _now();
    state = state.copyWith(phase: VoicePhase.recording);
  }

  /// Stops into review. Under one second is discarded with a message instead.
  Future<void> stopToReview() async {
    if (!ref.mounted || (state.phase != VoicePhase.recording && state.phase != VoicePhase.paused)) return;
    _freeze();
    _ticker?.cancel();
    _ticker = null;
    _running = false;
    var elapsed = _accum;
    if (elapsed > const Duration(seconds: kMaxVoiceSeconds)) elapsed = const Duration(seconds: kMaxVoiceSeconds);
    final fallback = _path;
    String? finished;
    try {
      finished = await _port.stop();
    } catch (_) {}
    if (!ref.mounted) return;
    final path = finished ?? fallback;
    if (elapsed < const Duration(seconds: kMinVoiceSeconds) || path == null) {
      if (path != null) _discardFile(path);
      _reset();
      state = const VoiceState(tooShort: true);
      return;
    }
    state = VoiceState(phase: VoicePhase.review, elapsed: elapsed, file: File(path));
  }

  void clearTooShort() {
    if (ref.mounted && state.tooShort) state = const VoiceState();
  }

  /// Throws the recording away: cancels the recorder if it is running and deletes the temp file.
  Future<void> discard() async {
    if (!ref.mounted) return;
    final wasRunning = state.phase == VoicePhase.recording || state.phase == VoicePhase.paused;
    final path = state.file?.path ?? _path;
    _ticker?.cancel();
    _ticker = null;
    _running = false;
    if (wasRunning) {
      try {
        await _port.cancel();
      } catch (_) {}
    }
    if (path != null) _discardFile(path);
    if (!ref.mounted) return;
    _reset();
    state = const VoiceState();
  }

  /// Hands the note to the thread: the upload runs inside the send's prepare step (memoized, one storage path per
  /// recording, so a retry uploads at most once) and the temp file is deleted when the message is confirmed or
  /// its failed bubble is discarded. The pending bubble in the thread carries the failure UI.
  Future<void> send() async {
    if (!ref.mounted || state.phase != VoicePhase.review || _handingOff) return;
    final file = state.file;
    if (file == null) return;
    _handingOff = true;
    final seconds = (state.elapsed.inMilliseconds / 1000).ceil().clamp(kMinVoiceSeconds, kMaxVoiceSeconds);
    final viewer = ref.read(dmViewerIdProvider).asData?.value;
    final uploader = ref.read(dmMediaUploaderProvider);
    final notifier = ref.read(threadProvider(threadId).notifier);
    if (viewer == null) {
      _handingOff = false;
      return;
    }
    final pathId = newIdempotencyKey();
    String? uploaded;
    _reset();
    state = const VoiceState();
    _handingOff = false;
    await notifier.send(
      SendDraft(audioDurationSeconds: seconds),
      prepare: (draft) async {
        uploaded ??= await uploader.uploadAudio(userId: viewer, file: file, pathId: pathId);
        return draft.copyWith(audioPath: uploaded);
      },
      onDone: () => _discardFile(file.path),
    );
  }

  void _reset() {
    _stateSub?.cancel();
    _stateSub = null;
    _levelSub?.cancel();
    _levelSub = null;
    _ticker?.cancel();
    _ticker = null;
    _accum = Duration.zero;
    _segmentStart = null;
    _path = null;
    _running = false;
  }

  // Synchronous on purpose: a small temp file, and it keeps the cleanup observable under fake time.
  void _discardFile(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  void _cleanup() {
    final running = _running;
    final path = running ? _path : null; // a file already handed off belongs to its pending message
    final recorder = _recorder;
    _recorder = null;
    _ticker?.cancel();
    _stateSub?.cancel();
    _levelSub?.cancel();
    if (recorder != null) {
      unawaited(() async {
        try {
          if (running) await recorder.cancel();
        } catch (_) {}
        try {
          await recorder.dispose();
        } catch (_) {}
        if (path != null) _discardFile(path);
      }());
    }
  }
}

final voiceRecorderControllerProvider =
    NotifierProvider.autoDispose.family<VoiceRecorderController, VoiceState, String>(VoiceRecorderController.new);
