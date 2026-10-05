import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/chat_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/sx_colors.dart';
import 'chat_bubble_view.dart';
import 'chat_destinations.dart';
import 'chat_error_copy.dart';
import 'chat_notifier.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Wait for the viewer before building the notifier, so a cold start never builds it as a guest.
    final viewer = ref.watch(viewerIdProvider);
    if (viewer.isLoading && !viewer.hasValue) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).chatTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return const _ChatBody();
  }
}

class _ChatBody extends ConsumerStatefulWidget {
  const _ChatBody();

  @override
  ConsumerState<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends ConsumerState<_ChatBody> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _countdown;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(chatProvider.notifier).loadHistory();
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _locale => Localizations.localeOf(context).languageCode == 'fr' ? 'fr' : 'en';

  bool get _nearBottom {
    if (!_scroll.hasClients) return true;
    final p = _scroll.position;
    return p.pixels >= p.maxScrollExtent - 80;
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    setState(() => _remaining = seconds);
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining = _remaining > 0 ? _remaining - 1 : 0);
      if (_remaining <= 0) t.cancel();
    });
  }

  void _onChange(ChatState? prev, ChatState next) {
    final wasNear = _nearBottom;
    if (next.phase == ChatPhase.failed &&
        next.errorCode == 'chat_rate_limited' &&
        (next.retryAfterSeconds ?? 0) > 0 &&
        (prev?.phase != ChatPhase.failed || prev?.retryAfterSeconds != next.retryAfterSeconds)) {
      _startCountdown(next.retryAfterSeconds!);
    }
    if (prev == null || prev.bubbles.length != next.bubbles.length || _lastLen(prev) != _lastLen(next)) {
      if (wasNear) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    }
  }

  int _lastLen(ChatState s) => s.bubbles.isEmpty ? 0 : s.bubbles.last.text.length;

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await ref.read(chatProvider.notifier).send(text, locale: _locale);
  }

  Future<void> _confirmClear() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.chatClearConfirmTitle),
        content: Text(l10n.chatClearConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.chatCancel)),
          TextButton(key: const Key('chat-clear-confirm'), onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.chatClear)),
        ],
      ),
    );
    if (ok == true && mounted) await ref.read(chatProvider.notifier).clearHistory();
  }

  String _destLabel(AppLocalizations l, ChatDestination d) => switch (d) {
        ChatDestination.tournaments => l.chatDestTournaments,
        ChatDestination.matches => l.chatDestMatches,
        ChatDestination.profile => l.chatDestProfile,
        ChatDestination.notifications => l.chatDestNotifications,
        ChatDestination.wallet => l.chatDestWallet,
        ChatDestination.rules => l.chatDestRules,
        ChatDestination.safety => l.chatDestSafety,
        ChatDestination.help => l.chatDestHelp,
      };

  @override
  Widget build(BuildContext context) {
    ref.listen(chatProvider, _onChange);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(chatProvider);
    final busy = state.phase == ChatPhase.sending || state.phase == ChatPhase.streaming;
    final lastBubble = state.bubbles.isEmpty ? null : state.bubbles.last;
    final showTyping = busy && lastBubble != null && !lastBubble.fromUser && lastBubble.text.isEmpty;
    final visible = [for (final b in state.bubbles) if (!(b.id == lastBubble?.id && showTyping)) b];
    final chips = [
      for (final d in state.actions)
        if (destinationRoute(d) != null) d,
    ];
    final showChips = chips.isNotEmpty && !busy && lastBubble != null && !lastBubble.fromUser && lastBubble.text.isNotEmpty;
    final canRetry = state.phase == ChatPhase.failed || state.phase == ChatPhase.interrupted;
    final rateLimited = state.errorCode == 'chat_rate_limited';
    final errorText = state.phase == ChatPhase.interrupted
        ? l10n.chatInterrupted
        : state.errorCode == null
            ? null
            : chatErrorMessage(
                l10n,
                state.errorCode!,
                signedIn: state.signedIn,
                retryAfterSeconds: rateLimited && _remaining > 0 ? _remaining : state.retryAfterSeconds,
              );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatTitle),
        actions: [
          if (state.signedIn)
            IconButton(key: const Key('chat-clear'), tooltip: l10n.chatClear, icon: const Icon(Icons.delete_outline), onPressed: busy ? null : _confirmClear),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: visible.isEmpty && !showTyping
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.chatEmptyPrompt, textAlign: TextAlign.center, style: const TextStyle(color: SxColors.textSecondary)),
                  ),
                )
              : ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (state.nextBefore != null)
                      TextButton(onPressed: () => ref.read(chatProvider.notifier).loadOlder(), child: Text(l10n.chatLoadEarlier)),
                    for (final b in visible) ChatBubbleView(text: b.text, fromUser: b.fromUser, failed: b.failed),
                    if (showTyping)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          state.checkingAccount ? l10n.chatCheckingAccount : l10n.chatTyping,
                          style: const TextStyle(color: SxColors.textSecondary),
                        ),
                      ),
                    if (showChips)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Wrap(spacing: 8, children: [
                          for (final d in chips)
                            ActionChip(
                              key: Key('chat-chip-${d.name}'),
                              label: Text(_destLabel(l10n, d)),
                              onPressed: () => GoRouter.of(context).push(destinationRoute(d)!),
                            ),
                        ]),
                      ),
                  ],
                ),
        ),
        if (errorText != null)
          Container(
            width: double.infinity,
            color: SxColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(child: Text(errorText, style: TextStyle(color: Theme.of(context).colorScheme.error))),
              if (canRetry)
                TextButton(
                  key: const Key('chat-retry'),
                  onPressed: rateLimited && _remaining > 0 ? null : () => ref.read(chatProvider.notifier).retry(locale: _locale),
                  child: Text(l10n.chatRetry),
                ),
            ]),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  key: const Key('chat-input'),
                  controller: _input,
                  maxLength: 1000,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(hintText: l10n.chatHint, counterText: ''),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _input,
                builder: (context, value, _) => IconButton(
                  key: const Key('chat-send'),
                  tooltip: l10n.chatSend,
                  icon: const Icon(Icons.send),
                  onPressed: busy || value.text.trim().isEmpty ? null : _send,
                ),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            state.signedIn ? l10n.chatRetentionNotice : l10n.chatSignedOutNotice,
            textAlign: TextAlign.center,
            style: const TextStyle(color: SxColors.textSecondary, fontSize: 12),
          ),
        ),
      ]),
    );
  }
}
