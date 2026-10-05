import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/sx_colors.dart';
import 'voice_ports.dart';
import 'voice_recorder_controller.dart';

String formatVoiceClock(Duration d) {
  final total = d.inSeconds;
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

/// Replaces the text composer while a voice note is being permission-checked, recorded, or reviewed.
/// Backgrounding the app pauses a recording (never discards it); coming back from system settings re-checks the
/// microphone permission.
class VoiceComposer extends ConsumerStatefulWidget {
  const VoiceComposer({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<VoiceComposer> createState() => _VoiceComposerState();
}

class _VoiceComposerState extends ConsumerState<VoiceComposer> with WidgetsBindingObserver {
  VoicePlayerPort? _player;
  StreamSubscription<VoicePlayerState>? _playerSub;
  StreamSubscription<Duration>? _positionSub;
  var _playing = false;
  var _loaded = false;
  Duration _position = Duration.zero;

  VoiceRecorderController get _ctl => ref.read(voiceRecorderControllerProvider(widget.threadId).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerSub?.cancel();
    _positionSub?.cancel();
    final p = _player;
    if (p != null) unawaited(p.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      unawaited(_ctl.pause()); // no-op unless recording
      unawaited(_player?.pause());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_ctl.recheckPermission());
    }
  }

  Future<void> _togglePlayback(String path) async {
    final player = _player ??= ref.read(voicePlayerFactoryProvider)();
    _playerSub ??= player.state.listen((s) {
      if (mounted) setState(() => _playing = s == VoicePlayerState.playing);
    });
    _positionSub ??= player.position.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    if (_playing) {
      await player.pause();
      return;
    }
    if (!_loaded) {
      await player.load(path);
      _loaded = true;
    }
    await player.play();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = ref.watch(voiceRecorderControllerProvider(widget.threadId));
    final Widget body;
    switch (v.phase) {
      case VoicePhase.idle:
        body = const SizedBox.shrink();
      case VoicePhase.requestingPermission:
        body = const Padding(padding: EdgeInsets.all(16), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))));
      case VoicePhase.permissionDenied:
        body = Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.mic_off_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.dmMicDenied)),
              IconButton(key: const Key('dm-mic-close'), icon: const Icon(Icons.close, size: 18), onPressed: () => unawaited(_ctl.discard())),
            ]),
            Wrap(spacing: 8, children: [
              FilledButton(key: const Key('dm-mic-try-again'), onPressed: () => unawaited(_ctl.begin()), child: Text(l10n.dmMicTryAgain)),
              OutlinedButton(
                key: const Key('dm-mic-settings'),
                onPressed: () => unawaited(ref.read(openAppSettingsProvider)()),
                child: Text(l10n.dmMicOpenSettings),
              ),
            ]),
          ]),
        );
      case VoicePhase.recording:
      case VoicePhase.paused:
        final paused = v.phase == VoicePhase.paused;
        body = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            IconButton(
              key: const Key('dm-voice-cancel'),
              tooltip: l10n.dmVoiceDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => unawaited(_ctl.discard()),
            ),
            Icon(paused ? Icons.pause_circle_outline : Icons.fiber_manual_record, size: 16, color: paused ? SxColors.textSecondary : Colors.redAccent),
            const SizedBox(width: 6),
            Text(formatVoiceClock(v.elapsed), key: const Key('dm-voice-timer'), style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(width: 8),
            Expanded(
              child: paused
                  ? Text(l10n.dmVoicePaused, key: const Key('dm-voice-paused-label'), style: const TextStyle(color: SxColors.textSecondary))
                  : LinearProgressIndicator(key: const Key('dm-voice-level'), value: v.level.clamp(0.0, 1.0)),
            ),
            IconButton(
              key: Key(paused ? 'dm-voice-resume' : 'dm-voice-pause'),
              tooltip: paused ? l10n.dmVoiceResume : l10n.dmVoicePause,
              icon: Icon(paused ? Icons.mic : Icons.pause),
              onPressed: () => unawaited(paused ? _ctl.resume() : _ctl.pause()),
            ),
            IconButton(key: const Key('dm-voice-stop'), tooltip: l10n.dmVoiceStop, icon: const Icon(Icons.stop_circle_outlined), onPressed: () => unawaited(_ctl.stopToReview())),
          ]),
        );
      case VoicePhase.review:
        final total = v.elapsed.inMilliseconds == 0 ? 1 : v.elapsed.inMilliseconds;
        body = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            IconButton(key: const Key('dm-voice-delete'), tooltip: l10n.dmVoiceDelete, icon: const Icon(Icons.delete_outline), onPressed: () => unawaited(_ctl.discard())),
            IconButton(
              key: const Key('dm-voice-play'),
              tooltip: l10n.dmVoicePlay,
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              onPressed: () => unawaited(_togglePlayback(v.file!.path)),
            ),
            Expanded(child: LinearProgressIndicator(value: (_position.inMilliseconds / total).clamp(0.0, 1.0))),
            const SizedBox(width: 8),
            Text(formatVoiceClock(v.elapsed), key: const Key('dm-voice-total')),
            IconButton(key: const Key('dm-voice-send'), tooltip: l10n.dmSend, icon: const Icon(Icons.send), color: SxColors.primary, onPressed: () => unawaited(_ctl.send())),
          ]),
        );
    }
    return SafeArea(
      top: false,
      child: Container(
        key: const Key('dm-voice-composer'),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: SxColors.surface))),
        child: body,
      ),
    );
  }
}
