import 'dart:async';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import '../../core/api/api_client.dart';
import '../../core/api/chat_models.dart';
import '../../core/lifecycle/app_lifecycle_provider.dart';
import '../../core/providers.dart';
import '../../core/storage/local_kv.dart';
import '../../core/utils/idempotency_key.dart';
import 'chat_repository.dart';

enum ChatPhase { idle, sending, streaming, interrupted, failed }

class ChatBubble {
  const ChatBubble({required this.id, required this.fromUser, required this.text, this.failed = false});
  final String id;
  final bool fromUser;
  final String text;
  final bool failed;
  ChatBubble copyWith({String? text, bool? failed}) => ChatBubble(id: id, fromUser: fromUser, text: text ?? this.text, failed: failed ?? this.failed);
}

class ChatState {
  const ChatState({
    this.bubbles = const [],
    this.phase = ChatPhase.idle,
    this.errorCode,
    this.retryAfterSeconds,
    this.actions = const [],
    this.checkingAccount = false,
    this.historyLoaded = false,
    this.signedIn = false,
    this.nextBefore,
  });
  final List<ChatBubble> bubbles;
  final ChatPhase phase;
  final String? errorCode;
  final int? retryAfterSeconds;
  final List<ChatDestination> actions;
  final bool checkingAccount, historyLoaded, signedIn;
  final String? nextBefore;

  ChatState copyWith({
    List<ChatBubble>? bubbles,
    ChatPhase? phase,
    String? errorCode,
    int? retryAfterSeconds,
    bool clearError = false,
    List<ChatDestination>? actions,
    bool? checkingAccount,
    bool? historyLoaded,
    bool? signedIn,
    String? nextBefore,
  }) =>
      ChatState(
        bubbles: bubbles ?? this.bubbles,
        phase: phase ?? this.phase,
        errorCode: clearError ? null : (errorCode ?? this.errorCode),
        retryAfterSeconds: clearError ? null : (retryAfterSeconds ?? this.retryAfterSeconds),
        actions: actions ?? this.actions,
        checkingAccount: checkingAccount ?? this.checkingAccount,
        historyLoaded: historyLoaded ?? this.historyLoaded,
        signedIn: signedIn ?? this.signedIn,
        nextBefore: nextBefore ?? this.nextBefore,
      );
}

class ChatNotifier extends Notifier<ChatState> {
  static const _maxUser = 1000, _maxAssistant = 4000, _maxMessages = 20, _maxTotal = 8000;
  static const _inFlightCap = Duration(seconds: 90);

  StreamSubscription<ChatEvent>? _sub;
  KeepAliveLink? _keep;
  Timer? _cap;
  String? _turnId;
  int _seq = 0;
  bool _sawTerminal = false;
  Completer<void>? _pending; // completed whenever the current turn stops, so `_run` never hangs

  @override
  ChatState build() {
    // Not `watch`: the viewer id resolving for the first time must not rebuild (and so wipe) a turn already in
    // flight. A DIFFERENT account taking over does reset the conversation.
    var known = ref.read(viewerIdProvider).hasValue;
    var viewer = ref.read(viewerIdProvider).asData?.value;
    ref.listen(viewerIdProvider, (_, next) {
      if (!next.hasValue) return;
      final v = next.asData?.value;
      if (!known) {
        known = true;
        viewer = v;
        state = state.copyWith(signedIn: v != null);
      } else if (v != viewer) {
        ref.invalidateSelf();
      }
    });
    final life = ref.watch(appLifecycleSourceProvider).changes.listen((s) {
      if ((s == AppLifecycleState.paused || s == AppLifecycleState.hidden) && _inFlight) _interrupt();
    });
    ref.onDispose(() {
      life.cancel();
      _teardown();
    });
    return ChatState(signedIn: viewer != null);
  }

  bool get _inFlight => state.phase == ChatPhase.sending || state.phase == ChatPhase.streaming;

  void _hold() {
    _keep ??= ref.keepAlive();
    _cap?.cancel();
    _cap = Timer(_inFlightCap, () {
      if (ref.mounted && _inFlight) _interrupt();
    });
  }

  void _release() {
    _cap?.cancel();
    _cap = null;
    _keep?.close();
    _keep = null;
  }

  void _teardown() {
    _cap?.cancel();
    _sub?.cancel();
    _sub = null;
    if (_pending?.isCompleted == false) _pending!.complete();
  }

  Future<void> loadHistory() async {
    if (!state.signedIn || state.historyLoaded) return;
    try {
      final page = await ref.read(chatRepositoryProvider).history();
      if (!ref.mounted) return;
      final hist = [for (final m in page.messages) ChatBubble(id: 'h${m.id}', fromUser: m.role == 'user', text: m.content)];
      state = state.copyWith(bubbles: [...hist, ...state.bubbles], historyLoaded: true, nextBefore: page.nextBefore);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(historyLoaded: true);
    }
  }

  Future<void> loadOlder() async {
    final before = state.nextBefore;
    if (!state.signedIn || before == null) return;
    try {
      final page = await ref.read(chatRepositoryProvider).history(before: before);
      if (!ref.mounted) return;
      final hist = [for (final m in page.messages) ChatBubble(id: 'h${m.id}', fromUser: m.role == 'user', text: m.content)];
      state = ChatState(
        bubbles: [...hist, ...state.bubbles], phase: state.phase, errorCode: state.errorCode, retryAfterSeconds: state.retryAfterSeconds,
        actions: state.actions, checkingAccount: state.checkingAccount, historyLoaded: true, signedIn: state.signedIn, nextBefore: page.nextBefore,
      );
    } catch (_) {}
  }

  Future<void> send(String raw, {required String locale}) async {
    final text = cleanChatText(raw).trim();
    if (text.isEmpty || text.length > _maxUser || _inFlight) return;
    final seq = ++_seq;
    _turnId = newIdempotencyKey();
    state = state.copyWith(
      bubbles: [
        ...state.bubbles,
        ChatBubble(id: 'u$seq', fromUser: true, text: text),
        ChatBubble(id: 'a$seq', fromUser: false, text: ''),
      ],
      phase: ChatPhase.sending,
      clearError: true,
      actions: const [],
      checkingAccount: false,
    );
    await _run(locale: locale, userId: 'u$seq', assistantId: 'a$seq');
  }

  Future<void> retry({required String locale}) async {
    if ((state.phase != ChatPhase.failed && state.phase != ChatPhase.interrupted) || _turnId == null) return;
    final idx = state.bubbles.lastIndexWhere((b) => b.fromUser);
    if (idx < 0 || !state.bubbles[idx].failed) return;
    final user = state.bubbles[idx];
    final seq = ++_seq;
    final kept = [for (var i = 0; i <= idx; i++) i == idx ? user.copyWith(failed: false) : state.bubbles[i]];
    state = state.copyWith(
      bubbles: [...kept, ChatBubble(id: 'a$seq', fromUser: false, text: '')],
      phase: ChatPhase.sending,
      clearError: true,
      actions: const [],
      checkingAccount: false,
    );
    await _run(locale: locale, userId: user.id, assistantId: 'a$seq');
  }

  List<ChatTurnMessage> _requestHistory(String assistantId) {
    final msgs = <ChatTurnMessage>[
      for (final b in state.bubbles)
        if (b.id != assistantId && b.text.isNotEmpty)
          ChatTurnMessage(
            b.fromUser ? 'user' : 'assistant',
            b.text.length > (b.fromUser ? _maxUser : _maxAssistant) ? b.text.substring(0, b.fromUser ? _maxUser : _maxAssistant) : b.text,
          ),
    ];
    var recent = msgs.length > _maxMessages ? msgs.sublist(msgs.length - _maxMessages) : msgs;
    var total = recent.fold<int>(0, (a, m) => a + m.content.length);
    while (total > _maxTotal && recent.length > 1) {
      total -= recent.first.content.length;
      recent = recent.sublist(1);
    }
    return recent;
  }

  Future<void> _run({required String locale, required String userId, required String assistantId}) async {
    _hold();
    _sawTerminal = false;
    final history = _requestHistory(assistantId);
    final String? device = state.signedIn ? null : await ref.read(chatDeviceIdProvider.future);
    if (!ref.mounted || !_inFlight) return; // interrupted (e.g. paused) while the device id was loading
    final done = Completer<void>();
    _pending = done;
    _sub = ref
        .read(chatRepositoryProvider)
        .send(history: history, clientTurnId: _turnId!, locale: locale, deviceId: device)
        .listen(
      (e) => _onEvent(e, userId, assistantId),
      onError: (Object err) {
        if (!_sawTerminal && ref.mounted) _failWith(err, userId, assistantId);
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        if (!_sawTerminal && ref.mounted && _inFlight) _interrupt(assistantId: assistantId, userId: userId);
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    await done.future;
  }

  void _onEvent(ChatEvent e, String userId, String assistantId) {
    if (!ref.mounted) return;
    switch (e) {
      case ChatStatus():
        state = state.copyWith(checkingAccount: true);
      case ChatDelta(:final text):
        final t = cleanChatText(text);
        state = state.copyWith(
          bubbles: [for (final b in state.bubbles) b.id == assistantId ? b.copyWith(text: b.text + t) : b],
          phase: ChatPhase.streaming,
          checkingAccount: false,
        );
      case ChatActions(:final items):
        state = state.copyWith(actions: items);
      case ChatDone():
        _sawTerminal = true;
        state = state.copyWith(phase: ChatPhase.idle, checkingAccount: false);
        _release();
      case ChatError(:final code):
        _sawTerminal = true;
        _fail(code, userId, assistantId);
    }
  }

  void _failWith(Object err, String userId, String assistantId) {
    if (err is ApiException) {
      final retry = int.tryParse(err.fields['retryAfterSeconds'] ?? '');
      _fail(err.isUnauthorized ? 'unauthorized' : err.code, userId, assistantId, retryAfterSeconds: retry);
    } else {
      _fail('network', userId, assistantId);
    }
  }

  void _fail(String code, String userId, String assistantId, {int? retryAfterSeconds}) {
    state = state.copyWith(
      bubbles: _settle(userId, assistantId),
      phase: ChatPhase.failed,
      errorCode: code,
      retryAfterSeconds: retryAfterSeconds,
      checkingAccount: false,
    );
    _release();
  }

  /// An empty assistant bubble is removed; the user bubble is marked failed so Retry knows what to resend.
  List<ChatBubble> _settle(String userId, String assistantId) => [
        for (final b in state.bubbles)
          if (b.id == assistantId && b.text.isEmpty) ...const <ChatBubble>[] else if (b.id == userId) b.copyWith(failed: true) else b,
      ];

  void _interrupt({String? assistantId, String? userId}) {
    _sub?.cancel();
    _sub = null;
    if (_pending?.isCompleted == false) _pending!.complete();
    final lastUser = userId ?? (state.bubbles.lastIndexWhere((b) => b.fromUser) >= 0 ? state.bubbles[state.bubbles.lastIndexWhere((b) => b.fromUser)].id : '');
    final lastAssistant = assistantId ?? (state.bubbles.isNotEmpty && !state.bubbles.last.fromUser ? state.bubbles.last.id : '');
    state = state.copyWith(bubbles: _settle(lastUser, lastAssistant), phase: ChatPhase.interrupted, checkingAccount: false);
    _release();
  }

  Future<void> clearHistory() async {
    try {
      await ref.read(chatRepositoryProvider).clear();
      if (!ref.mounted) return;
      state = ChatState(signedIn: state.signedIn, historyLoaded: true);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(errorCode: 'clear_failed');
    }
  }
}

final chatProvider = NotifierProvider.autoDispose<ChatNotifier, ChatState>(ChatNotifier.new);
