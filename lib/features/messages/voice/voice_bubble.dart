import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/messages_models.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/sx_colors.dart';
import 'voice_composer.dart' show formatVoiceClock;
import 'voice_ports.dart';

/// A confirmed voice message: play/pause, a progress bar and the duration (spoken with the plural
/// `dmVoiceSeconds`). One bubble plays at a time, playback pauses when the app backgrounds or the bubble goes
/// away, and a playback failure (an expired ~1 h signed URL) asks the thread for ONE rate-limited refetch and
/// offers a retry. A just-sent message whose URL is not fetched yet shows a disabled player.
class VoiceBubble extends ConsumerStatefulWidget {
  const VoiceBubble({super.key, required this.message, required this.onPlaybackError});

  final DmMessage message;

  /// Asks the thread for a rate-limited window refetch (fresh signed URLs).
  final VoidCallback onPlaybackError;

  @override
  ConsumerState<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends ConsumerState<VoiceBubble> with WidgetsBindingObserver {
  VoicePlayerPort? _player;
  StreamSubscription<VoicePlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  late final ActiveVoicePlayer _active;
  var _playing = false;
  var _loadedUrl = '';
  var _failed = false;
  Duration _position = Duration.zero;

  String get _id => widget.message.id;
  String get _url => widget.message.audioUrl ?? '';
  int get _seconds => widget.message.audioDurationSeconds ?? 1;

  @override
  void initState() {
    super.initState();
    _active = ref.read(activeVoicePlayerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(VoiceBubble old) {
    super.didUpdateWidget(old);
    // A refetch brought a fresh signed URL: the next play loads it, and a failed state is cleared.
    if (old.message.audioUrl != widget.message.audioUrl && _failed) setState(() => _failed = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stateSub?.cancel();
    _positionSub?.cancel();
    final p = _player;
    if (p != null) unawaited(p.dispose());
    scheduleMicrotask(() {
      try {
        _active.stop(_id);
      } catch (_) {}
    });
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) unawaited(_player?.pause());
  }

  Future<void> _toggle() async {
    if (_url.isEmpty) return;
    final player = _player ??= ref.read(voicePlayerFactoryProvider)();
    _stateSub ??= player.state.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s == VoicePlayerState.playing);
      if (s == VoicePlayerState.completed) {
        unawaited(player.seek(Duration.zero));
        _active.stop(_id);
      }
    });
    _positionSub ??= player.position.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    if (_playing) {
      await player.pause();
      return;
    }
    try {
      if (_loadedUrl != _url) {
        await player.load(_url);
        _loadedUrl = _url;
      }
      _active.start(_id); // pauses any other bubble that is playing
      setState(() => _failed = false);
      await player.play();
    } catch (_) {
      if (!mounted) return;
      _loadedUrl = '';
      setState(() => _failed = true);
      widget.onPlaybackError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Another bubble started: this one pauses.
    ref.listen(activeVoicePlayerProvider, (prev, next) {
      if (next != null && next != _id && _playing) unawaited(_player?.pause());
    });
    final total = Duration(seconds: _seconds);
    final progress = (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final ready = _url.isNotEmpty;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_failed)
          IconButton(
            key: Key('dm-voice-retry-$_id'),
            tooltip: l10n.dmVoicePlaybackError,
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(_toggle()),
          )
        else
          IconButton(
            key: Key('dm-voice-play-$_id'),
            tooltip: l10n.dmVoicePlay,
            icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 32),
            onPressed: ready ? () => unawaited(_toggle()) : null,
          ),
        Flexible(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            LinearProgressIndicator(key: Key('dm-voice-progress-$_id'), value: progress),
            const SizedBox(height: 4),
            Semantics(
              label: l10n.dmVoiceSeconds(_seconds),
              child: ExcludeSemantics(
                child: Text(
                  _failed ? l10n.dmVoicePlaybackError : formatVoiceClock(_playing ? _position : total),
                  key: Key('dm-voice-duration-$_id'),
                  style: const TextStyle(fontSize: 11, color: SxColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
