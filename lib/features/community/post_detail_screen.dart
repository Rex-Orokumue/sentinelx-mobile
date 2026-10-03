import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/community_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/utils/write_flow.dart';
import '../../shared/widgets/player_avatar.dart';
import 'boost_sheet.dart';
import 'community_error_copy.dart';
import 'community_providers.dart';
import 'community_realtime.dart';
import 'reaction_bar.dart';
import 'report_sheet.dart';

/// The API returns at most this many comments and has no comments pagination endpoint (Stage B
/// Ruling 4), so reaching it means older comments exist that this screen cannot show.
const _kCommentCap = 50;

enum _DetailAction { boost, delete, report }

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId, required this.onLogin, required this.onDeleted});
  final String postId;
  final VoidCallback onLogin, onDeleted;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String get _commentScope => 'comment:${widget.postId}';

  Future<bool> _confirm(String body, {required Key confirmKey, required Key cancelKey}) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(body),
        actions: [
          TextButton(key: cancelKey, onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cmtDeleteConfirmCancel)),
          TextButton(key: confirmKey, onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.cmtDeleteConfirmYes)),
        ],
      ),
    );
    return result == true && mounted;
  }

  void _showError(String scope) {
    final l10n = AppLocalizations.of(context);
    final code = ref.read(writeFlowProvider(scope)).errorCode ?? 'network';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(communityErrorCopy(l10n, code))));
  }

  Future<void> _deletePost() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.cmtDeletePostConfirm, confirmKey: const Key('post-delete-confirm'), cancelKey: const Key('post-delete-cancel'))) return;
    final scope = 'delete-post:${widget.postId}';
    final ok = await ref.read(writeFlowProvider(scope).notifier).run((_) => ref.read(communityRepositoryProvider).deletePost(widget.postId));
    if (!mounted) return;
    if (!ok) return _showError(scope);
    ref.invalidate(communityFeedProvider);
    widget.onDeleted();
  }

  Future<void> _deleteComment(String id) async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.cmtDeleteCommentConfirm, confirmKey: const Key('comment-delete-confirm'), cancelKey: const Key('comment-delete-cancel'))) return;
    final scope = 'delete-comment:$id';
    final ok = await ref.read(writeFlowProvider(scope).notifier).run((_) => ref.read(communityRepositoryProvider).deleteComment(id));
    if (!mounted) return;
    if (!ok) return _showError(scope);
    ref.read(communityPostDetailProvider(widget.postId).notifier).removeComment(id);
  }

  Future<void> _submitComment() async {
    final content = _input.text.trim();
    if (content.isEmpty) return;
    final me = ref.read(meProvider).asData?.value;
    if (me == null) return widget.onLogin();
    String? newId;
    final ok = await ref.read(writeFlowProvider(_commentScope).notifier).run(
          (key) async => newId = await ref.read(communityRepositoryProvider).createComment(widget.postId, content: content, idempotencyKey: key),
          fingerprint: content,
        );
    if (!mounted) return;
    if (!ok || newId == null) return _showError(_commentScope);
    final profile = me.profile;
    ref.read(communityPostDetailProvider(widget.postId).notifier).addComment(CommentView(
          id: newId!,
          content: content,
          createdAt: DateTime.now().toUtc().toIso8601String(),
          author: PlayerRef(
            id: me.id,
            username: profile?.username,
            displayName: profile?.displayName,
            avatarUrl: profile?.avatarUrl,
            membershipTier: profile?.membershipTier ?? 'free',
          ),
          canDelete: true,
        ));
    _input.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final postId = widget.postId;
    final signedIn = ref.watch(meProvider).asData?.value != null;
    final async = ref.watch(communityPostDetailProvider(postId));

    ref.listen(communityPostDetailRealtimeProvider(postId), (_, next) {
      if (next.hasValue) ref.invalidate(communityPostDetailProvider(postId));
    });

    // Last good value wins so a background refetch never swaps the page for a spinner.
    final detail = async.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cmtPostDetailTitle),
        actions: [
          if (detail != null && (signedIn || detail.post.canDelete || detail.post.canBoost))
            PopupMenuButton<_DetailAction>(
              key: const Key('detail-menu'),
              onSelected: (action) => switch (action) {
                _DetailAction.boost => showBoostSheet(context, post: detail.post),
                _DetailAction.delete => _deletePost(),
                _DetailAction.report => showReportSheet(context, target: ReportTarget.post(postId)),
              },
              itemBuilder: (_) => [
                if (detail.post.canBoost) PopupMenuItem(key: const Key('detail-boost'), value: _DetailAction.boost, child: Text(l10n.cmtBoostAction)),
                if (detail.post.canDelete) PopupMenuItem(key: const Key('detail-delete'), value: _DetailAction.delete, child: Text(l10n.cmtDeletePost)),
                if (signedIn) PopupMenuItem(key: const Key('detail-report'), value: _DetailAction.report, child: Text(l10n.cmtReportPost)),
              ],
            ),
        ],
      ),
      body: detail != null
          ? Column(children: [
              Expanded(child: _content(context, detail, signedIn: signedIn)),
              _composer(context, signedIn: signedIn),
            ])
          : async.hasError
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(l10n.cmtFeedLoadError),
                    const SizedBox(height: 8),
                    FilledButton(key: const Key('detail-retry'), onPressed: () => ref.invalidate(communityPostDetailProvider(postId)), child: Text(l10n.cmtRetry)),
                  ]),
                )
              : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _content(BuildContext context, CommunityPostDetail detail, {required bool signedIn}) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final post = detail.post;
    final notifier = ref.read(communityPostDetailProvider(widget.postId).notifier);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        PlayerAvatar(avatarUrl: post.author.avatarUrl, frameUrl: post.author.frameUrl),
        const SizedBox(width: 10),
        Expanded(child: Text(_name(post.author), style: theme.textTheme.titleSmall)),
      ]),
      if (post.content.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(post.content)),
      if (post.matchResult != null) _MatchResultCard(result: post.matchResult!),
      for (final url in {if (post.imageUrl != null) post.imageUrl!, ...post.imageUrls})
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Image.network(url, errorBuilder: (_, _, _) => const SizedBox.shrink()),
        ),
      const SizedBox(height: 8),
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
        ReactionBar(post: post, onUpdate: notifier.updatePost, onSignInRequired: widget.onLogin),
        Text(l10n.cmtCommentCount(post.commentCount)),
      ]),
      const Divider(),
      Text(l10n.cmtCommentsTitle, style: theme.textTheme.titleMedium),
      if (detail.comments.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(l10n.cmtCommentsEmpty)),
      for (final c in detail.comments) _commentRow(context, c, signedIn: signedIn),
      if (detail.comments.length >= _kCommentCap)
        Padding(
          key: const Key('comments-cap-notice'),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(l10n.cmtCommentsCapNotice, style: theme.textTheme.bodySmall),
        ),
    ]);
  }

  Widget _commentRow(BuildContext context, CommentView c, {required bool signedIn}) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PlayerAvatar(avatarUrl: c.author.avatarUrl, frameUrl: c.author.frameUrl, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_name(c.author), style: Theme.of(context).textTheme.labelLarge),
            Text(c.content),
            Text(_when(l10n, c.createdAt), style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        if (signedIn)
          IconButton(
            key: Key('comment-report-${c.id}'),
            tooltip: l10n.cmtReportComment,
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => showReportSheet(context, target: ReportTarget.comment(c.id)),
          ),
        if (c.canDelete)
          IconButton(
            key: Key('comment-delete-${c.id}'),
            tooltip: l10n.cmtDeleteComment,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteComment(c.id),
          ),
      ]),
    );
  }

  Widget _composer(BuildContext context, {required bool signedIn}) {
    final l10n = AppLocalizations.of(context);
    if (!signedIn) {
      return SafeArea(
        child: ListTile(key: const Key('comment-signin-prompt'), title: Text(l10n.cmtSignInToComment), onTap: widget.onLogin),
      );
    }
    final busy = ref.watch(writeFlowProvider(_commentScope)).busy;
    final canSend = !busy && _input.text.trim().isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              key: const Key('comment-input'),
              controller: _input,
              enabled: !busy,
              minLines: 1,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: l10n.cmtCommentHint),
            ),
          ),
          IconButton(
            key: const Key('comment-submit'),
            tooltip: l10n.cmtCommentSend,
            icon: const Icon(Icons.send),
            onPressed: canSend ? _submitComment : null,
          ),
        ]),
      ),
    );
  }

  String _name(PlayerRef p) => p.displayName ?? p.username ?? '';

  String _when(AppLocalizations l10n, String iso) {
    final t = DateTime.tryParse(iso)?.toLocal();
    return t == null ? iso : DateFormat.yMMMd(l10n.localeName).add_Hm().format(t);
  }
}

class _MatchResultCard extends StatelessWidget {
  const _MatchResultCard({required this.result});
  final MatchResultDetail result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String name(PlayerRef? p) => p == null ? '' : (p.displayName ?? p.username ?? '');
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Text(result.tournamentTitle, style: theme.textTheme.titleSmall),
          Text(result.roundLabel, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Flexible(child: Text(name(result.playerA), textAlign: TextAlign.center)),
            Text('${result.scoreA ?? '-'} - ${result.scoreB ?? '-'}', style: theme.textTheme.titleLarge),
            Flexible(child: Text(name(result.playerB), textAlign: TextAlign.center)),
          ]),
        ]),
      ),
    );
  }
}
