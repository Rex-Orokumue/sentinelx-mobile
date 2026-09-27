import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/utils/write_flow.dart';
import 'evidence.dart';
import 'match_error_copy.dart';
import 'match_providers.dart';
import 'match_reads_repository.dart';

class ResultSubmissionScreen extends ConsumerStatefulWidget {
  const ResultSubmissionScreen({super.key, required this.match});
  final MatchInfo match;

  @override
  ConsumerState<ResultSubmissionScreen> createState() => _ResultSubmissionScreenState();
}

class _ResultSubmissionScreenState extends ConsumerState<ResultSubmissionScreen> {
  final _scoreA = TextEditingController();
  final _scoreB = TextEditingController();
  final _recordingUrl = TextEditingController();

  ResultSubmitter? _submitter;
  PickedImage? _image;
  bool _screenshotMissing = false;
  String? _scoreAError;
  String? _scoreBError;

  @override
  void dispose() {
    _scoreA.dispose();
    _scoreB.dispose();
    _recordingUrl.dispose();
    super.dispose();
  }

  int? _validScore(String text) {
    final v = int.tryParse(text.trim());
    if (v == null || v < 0 || v > 99) return null;
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

  Future<void> _submit(String matchId) async {
    final l10n = AppLocalizations.of(context);
    final a = _validScore(_scoreA.text);
    final b = _validScore(_scoreB.text);
    setState(() {
      _scoreAError = a == null ? l10n.mtcValScore : null;
      _scoreBError = b == null ? l10n.mtcValScore : null;
      _screenshotMissing = _image == null;
    });
    final image = _image;
    if (a == null || b == null || image == null) return;

    final scope = 'result:$matchId';
    final flow = ref.read(writeFlowProvider(scope).notifier);
    final submitter = _submitter!;
    await submitter.submit(
      flow: flow,
      image: image,
      send: (path, key) => ref.read(matchRepositoryProvider).submitResult(
            matchId,
            scoreA: a,
            scoreB: b,
            recordingUrl: _recordingUrl.text.trim(),
            screenshotPath: path,
            idempotencyKey: key,
          ),
    );
    if (!mounted) return;
    final state = ref.read(writeFlowProvider(scope));
    if (state.phase == WritePhase.done) {
      ref.invalidate(matchCentreProvider(matchId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final match = widget.match;
    final me = ref.watch(meProvider);
    final scope = 'result:${match.id}';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mtcSubmitResult)),
      body: me.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.mtcEcSession))),
        data: (meResponse) {
          if (meResponse == null) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.mtcEcSession)));
          }
          _submitter ??= ResultSubmitter(uploader: ref.read(evidenceUploaderProvider), userId: meResponse.id, scopeId: match.id);
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
                key: const Key('score-a'),
                controller: _scoreA,
                enabled: !busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.mtcScoreA(match.nameA), errorText: _scoreAError),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('score-b'),
                controller: _scoreB,
                enabled: !busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.mtcScoreA(match.nameB), errorText: _scoreBError),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('recording-url'),
                controller: _recordingUrl,
                enabled: !busy,
                decoration: InputDecoration(labelText: l10n.mtcRecordingUrl),
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
                onPressed: busy ? null : () => _submit(match.id),
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
