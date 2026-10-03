import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/community_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/utils/write_flow.dart';
import 'community_error_copy.dart';
import 'community_providers.dart';

class ReportTarget {
  const ReportTarget.post(this.id) : isComment = false;
  const ReportTarget.comment(this.id) : isComment = true;
  final String id;
  final bool isComment;
}

String _reasonLabel(AppLocalizations l10n, ReportReasonCode reason) => switch (reason) {
      ReportReasonCode.spam => l10n.cmtReportReasonSpam,
      ReportReasonCode.harassment => l10n.cmtReportReasonHarassment,
      ReportReasonCode.hateSpeech => l10n.cmtReportReasonHateSpeech,
      ReportReasonCode.nudityOrSexualContent => l10n.cmtReportReasonNudity,
      ReportReasonCode.violence => l10n.cmtReportReasonViolence,
      ReportReasonCode.misinformation => l10n.cmtReportReasonMisinformation,
      ReportReasonCode.other => l10n.cmtReportReasonOther,
    };

/// Report a post or comment. Callers gate sign-in themselves (same contract as reactions and
/// comments) — this sheet is only ever opened for a signed-in player. Staying open on a business
/// error such as `already_reported` is deliberate: closing would leave the player unsure whether
/// the report went through.
Future<void> showReportSheet(BuildContext context, {required ReportTarget target}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false, // a drag would bypass PopScope and orphan an in-flight report
    builder: (_) => _ReportSheetBody(target: target),
  );
}

class _ReportSheetBody extends ConsumerStatefulWidget {
  const _ReportSheetBody({required this.target});
  final ReportTarget target;

  @override
  ConsumerState<_ReportSheetBody> createState() => _ReportSheetBodyState();
}

class _ReportSheetBodyState extends ConsumerState<_ReportSheetBody> {
  ReportReasonCode? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String get _scope => 'report:${widget.target.isComment ? 'comment' : 'post'}:${widget.target.id}';

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final trimmed = _note.text.trim();
    final note = trimmed.isEmpty ? null : trimmed;
    final target = widget.target;
    final ok = await ref.read(writeFlowProvider(_scope).notifier).run(
          (key) {
            final repo = ref.read(communityRepositoryProvider);
            return target.isComment
                ? repo.reportComment(target.id, reasonCode: reason, note: note, idempotencyKey: key)
                : repo.reportPost(target.id, reasonCode: reason, note: note, idempotencyKey: key);
          },
          fingerprint: '${reason.wireName}|${note ?? ''}',
        );
    if (!ok || !mounted) return;
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.cmtReportSubmitted)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(writeFlowProvider(_scope));
    final busy = state.busy;
    final error = state.phase == WritePhase.failed ? communityErrorCopy(l10n, state.errorCode ?? '') : null;
    return PopScope(
      canPop: !busy,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.cmtReportTitle, style: Theme.of(context).textTheme.titleLarge),
          RadioGroup<ReportReasonCode>(
            groupValue: _reason,
            onChanged: (v) {
              if (!busy) setState(() => _reason = v);
            },
            child: Column(children: [
              for (final reason in ReportReasonCode.values)
                RadioListTile<ReportReasonCode>(
                  key: Key('report-reason-${reason.wireName}'),
                  value: reason,
                  title: Text(_reasonLabel(l10n, reason)),
                ),
            ]),
          ),
          TextField(
            key: const Key('report-note'),
            controller: _note,
            enabled: !busy,
            maxLines: 3,
            decoration: InputDecoration(hintText: l10n.cmtReportNoteHint),
          ),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error)),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('report-submit'),
            onPressed: busy || _reason == null ? null : _submit,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (busy) ...[
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
              ],
              Text(l10n.cmtReportSubmit),
            ]),
          ),
        ]),
      ),
    );
  }
}
