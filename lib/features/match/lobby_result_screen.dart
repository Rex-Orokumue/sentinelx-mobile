import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/match_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/utils/write_flow.dart';
import 'evidence.dart';
import 'match_error_copy.dart';
import 'match_providers.dart';

/// Same shape as ResultSubmissionScreen (score-race matches): placement, kills, a required screenshot,
/// upload-once + the Idempotency-Key policy through WriteFlow, and a never-optimistic confirmation panel.
class LobbyResultScreen extends ConsumerStatefulWidget {
  const LobbyResultScreen({super.key, required this.lobbyId, this.lobby});
  final String lobbyId;
  final NextLobby? lobby;

  @override
  ConsumerState<LobbyResultScreen> createState() => _LobbyResultScreenState();
}

class _LobbyResultScreenState extends ConsumerState<LobbyResultScreen> {
  final _placement = TextEditingController();
  final _kills = TextEditingController();

  ResultSubmitter? _submitter;
  PickedImage? _image;
  bool _screenshotMissing = false;
  String? _placementError;
  String? _killsError;

  @override
  void dispose() {
    _placement.dispose();
    _kills.dispose();
    super.dispose();
  }

  int? _validPlacement(String text) {
    final v = int.tryParse(text.trim());
    if (v == null || v < 1 || v > 100) return null;
    return v;
  }

  int? _validKills(String text) {
    final v = int.tryParse(text.trim());
    if (v == null || v < 0 || v > 100) return null;
    return v;
  }

  Future<void> _pickScreenshot() async {
    final image = await ref.read(imagePickerProvider).pickScreenshot();
    if (!mounted || image == null) return;
    setState(() {
      _image = image;
      _screenshotMissing = false;
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final placement = _validPlacement(_placement.text);
    final kills = _validKills(_kills.text);
    setState(() {
      _placementError = placement == null ? l10n.mtcValPlacement : null;
      _killsError = kills == null ? l10n.mtcValKills : null;
      _screenshotMissing = _image == null;
    });
    final image = _image;
    if (placement == null || kills == null || image == null) return;

    final scope = 'lobby:${widget.lobbyId}';
    final flow = ref.read(writeFlowProvider(scope).notifier);
    final ok = await _submitter!.submit(
      flow: flow,
      image: image,
      fingerprint: '$placement:$kills',
      send: (path, key) => ref.read(matchRepositoryProvider).submitLobbyResult(
            widget.lobbyId,
            placement: placement,
            kills: kills,
            screenshotPath: path,
            idempotencyKey: key,
          ),
    );
    if (!mounted || !ok) return;
    ref.invalidate(meSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(meProvider);
    final scope = 'lobby:${widget.lobbyId}';
    final title = widget.lobby == null ? l10n.mtcLobbyResultTitle : '${l10n.mtcLobbyResultTitle} · ${widget.lobby!.label}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: me.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.mtcEcSession))),
        data: (meResponse) {
          if (meResponse == null) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.mtcEcSession)));
          }
          _submitter ??= ResultSubmitter(uploader: ref.read(evidenceUploaderProvider), userId: meResponse.id, scopeId: widget.lobbyId);
          final state = ref.watch(writeFlowProvider(scope));
          if (state.phase == WritePhase.done) {
            return _Confirmation(l10n: l10n);
          }
          final busy = state.busy;
          final errorCopy = state.phase == WritePhase.failed ? matchErrorCopy(l10n, state.errorCode ?? '') : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (errorCopy != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(errorCopy)),
              TextField(
                key: const Key('placement'),
                controller: _placement,
                enabled: !busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.mtcPlacement, errorText: _placementError),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('kills'),
                controller: _kills,
                enabled: !busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.mtcKills, errorText: _killsError),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const Key('pick-screenshot'),
                onPressed: busy ? null : _pickScreenshot,
                child: Text(_image == null ? l10n.mtcPickScreenshot : l10n.mtcChangeScreenshot),
              ),
              if (_image != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_image!.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (_screenshotMissing) Padding(padding: const EdgeInsets.only(top: 4), child: Text(l10n.mtcScreenshotRequired)),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('submit-result'),
                onPressed: busy ? null : _submit,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (busy) ...[
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                  ],
                  Text(busy ? l10n.mtcSubmitting : l10n.mtcSubmitResult),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.mtcResultSubmitted, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.mtcDone)),
          ]),
        ),
      );
}
