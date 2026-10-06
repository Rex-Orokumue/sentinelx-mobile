import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/chat_models.dart';
import 'package:sentinelx_mobile/core/lifecycle/app_lifecycle_provider.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/storage/local_kv.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_notifier.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_repository.dart';
import '../../fakes/fake_chat_repository.dart';
import '../../fakes/fake_realtime.dart' show FakeLifecycle;

({ProviderContainer c, FakeChatRepository repo, FakeLifecycle life}) _setup({String? viewer = 'u1'}) {
  final repo = FakeChatRepository();
  final life = FakeLifecycle();
  final c = ProviderContainer(overrides: [
    viewerIdProvider.overrideWith((ref) async => viewer),
    chatRepositoryProvider.overrideWithValue(repo),
    appLifecycleSourceProvider.overrideWithValue(life),
    chatDeviceIdProvider.overrideWith((ref) async => 'device-abc-123'),
  ]);
  addTearDown(c.dispose);
  c.listen(chatProvider, (_, _) {}); // keep it alive for the test
  return (c: c, repo: repo, life: life);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('happy path: user bubble, streamed assistant text, done -> idle', () async {
    final s = _setup();
    await s.c.read(viewerIdProvider.future);
    final n = s.c.read(chatProvider.notifier);
    final f = n.send('how do fees work', locale: 'en');
    await _settle();
    expect(s.c.read(chatProvider).phase, ChatPhase.sending);
    s.repo.last.add(const ChatDelta('Entry is '));
    await _settle();
    expect(s.c.read(chatProvider).phase, ChatPhase.streaming);
    s.repo.last.add(const ChatDelta('₦500.'));
    s.repo.last.add(const ChatDone(true));
    await s.repo.last.close();
    await f;
    final st = s.c.read(chatProvider);
    expect(st.phase, ChatPhase.idle);
    expect(st.bubbles.map((b) => b.text), ['how do fees work', 'Entry is ₦500.']);
  });
  test('deltas are cleaned: bidi/control characters never reach the bubble, markup stays literal', () async {
    final s = _setup();
    await s.c.read(viewerIdProvider.future);
    final f = s.c.read(chatProvider.notifier).send('hi', locale: 'en');
    await _settle();
    s.repo.last.add(const ChatDelta('a\u202Eb <b>x</b>'));
    s.repo.last.add(const ChatDone(false));
    await s.repo.last.close();
    await f;
    expect(s.c.read(chatProvider).bubbles.last.text, 'ab <b>x</b>');
  });
  test('ignores blank, over-long and concurrent sends', () async {
    final s = _setup();
    await s.c.read(viewerIdProvider.future);
    final n = s.c.read(chatProvider.notifier);
    await n.send('   ', locale: 'en');
    await n.send('x' * 1001, locale: 'en');
    expect(s.repo.sends, isEmpty);
    final f = n.send('one', locale: 'en');
    await _settle();
    await n.send('two', locale: 'en'); // ignored while in flight
    expect(s.repo.sends, hasLength(1));
    s.repo.last.add(const ChatDone(false));
    await s.repo.last.close();
    await f;
  });
  test('request history: last 20, <= 8000 chars, per-role truncation', () async {
    final s = _setup();
    s.repo.historyPage = ChatHistoryPage(messages: [
      for (var i = 0; i < 30; i++)
        ChatHistoryItem(id: '$i', role: i.isEven ? 'user' : 'assistant', content: i.isEven ? 'u' * 900 : 'a' * 4500, createdAt: DateTime.utc(2026, 10, 1, 0, i)),
    ]);
    await s.c.read(viewerIdProvider.future);
    final n = s.c.read(chatProvider.notifier);
    await n.loadHistory();
    final f = n.send('now', locale: 'fr');
    await _settle();
    final h = s.repo.sends.single.history;
    expect(h.length, lessThanOrEqualTo(20));
    expect(h.fold<int>(0, (a, m) => a + m.content.length), lessThanOrEqualTo(8000));
    expect(h.every((m) => m.content.length <= (m.role == 'user' ? 1000 : 4000)), isTrue);
    expect(h.last.content, 'now');
    expect(s.repo.sends.single.locale, 'fr');
    s.repo.last.add(const ChatDone(false));
    await s.repo.last.close();
    await f;
  });
  test('stream ends without a terminal event -> interrupted, partial text kept, retry reuses the SAME turn id', () async {
    final s = _setup();
    await s.c.read(viewerIdProvider.future);
    final n = s.c.read(chatProvider.notifier);
    final f = n.send('q', locale: 'en');
    await _settle();
    s.repo.last.add(const ChatDelta('partial'));
    await s.repo.last.close(); // EOF, no ChatDone
    await f;
    var st = s.c.read(chatProvider);
    expect(st.phase, ChatPhase.interrupted);
    expect(st.bubbles.last.text, 'partial');
    expect(st.bubbles.where((b) => b.fromUser).single.failed, isTrue);
    final firstTurn = s.repo.sends.single.turnId;
    final r = n.retry(locale: 'en');
    await _settle();
    expect(s.repo.sends, hasLength(2));
    expect(s.repo.sends.last.turnId, firstTurn);
    expect(s.c.read(chatProvider).bubbles.where((b) => b.fromUser), hasLength(1)); // no duplicate user bubble
    s.repo.last.add(const ChatDelta('full answer'));
    s.repo.last.add(const ChatDone(true));
    await s.repo.last.close();
    await r;
    st = s.c.read(chatProvider);
    expect(st.phase, ChatPhase.idle);
    expect(st.bubbles.map((b) => b.text), ['q', 'full answer']);
  });
  test('pausing the app mid-stream interrupts the turn', () async {
    final s = _setup();
    await s.c.read(viewerIdProvider.future);
    final f = s.c.read(chatProvider.notifier).send('q', locale: 'en');
    await _settle();
    s.repo.last.add(const ChatDelta('a'));
    await _settle();
    s.life.push(AppLifecycleState.paused);
    await _settle();
    expect(s.c.read(chatProvider).phase, ChatPhase.interrupted);
    await s.repo.last.close();
    await f;
  });
  test('a terminal error event fails the turn with its code and removes an empty assistant bubble', () async {
    final s = _setup();
    await s.c.read(viewerIdProvider.future);
    final f = s.c.read(chatProvider.notifier).send('q', locale: 'en');
    await _settle();
    s.repo.last.add(const ChatError('chat_truncated'));
    await s.repo.last.close();
    await f;
    final st = s.c.read(chatProvider);
    expect(st.phase, ChatPhase.failed);
    expect(st.errorCode, 'chat_truncated');
    expect(st.bubbles.map((b) => b.fromUser), [true]);
  });
  test('rate limited before the stream: failed with code and retryAfterSeconds', () async {
    final s = _setup();
    s.repo.sendError = const ApiException(status: 429, code: 'chat_rate_limited', message: 'x', fields: {'retryAfterSeconds': '42'});
    await s.c.read(viewerIdProvider.future);
    await s.c.read(chatProvider.notifier).send('q', locale: 'en');
    final st = s.c.read(chatProvider);
    expect(st.errorCode, 'chat_rate_limited');
    expect(st.retryAfterSeconds, 42);
  });
  test('401 maps to unauthorized and a non-API error maps to network', () async {
    var s = _setup();
    s.repo.sendError = const ApiException(status: 401, code: 'unauthorized', message: 'x');
    await s.c.read(viewerIdProvider.future);
    await s.c.read(chatProvider.notifier).send('q', locale: 'en');
    expect(s.c.read(chatProvider).errorCode, 'unauthorized');
    s = _setup();
    s.repo.sendError = StateError('boom');
    await s.c.read(viewerIdProvider.future);
    await s.c.read(chatProvider.notifier).send('q', locale: 'en');
    expect(s.c.read(chatProvider).errorCode, 'network');
  });
  test('signed out: no history call, device id sent, signedIn false', () async {
    final s = _setup(viewer: null);
    await s.c.read(viewerIdProvider.future);
    final n = s.c.read(chatProvider.notifier);
    await n.loadHistory();
    expect(s.repo.historyCalls, 0);
    final f = n.send('q', locale: 'en');
    await _settle();
    expect(s.repo.sends.single.deviceId, 'device-abc-123');
    s.repo.last.add(const ChatDone(false));
    await s.repo.last.close();
    await f;
  });
  test('signed in: no device id is sent', () async {
    final s = _setup();
    await s.c.read(viewerIdProvider.future);
    final f = s.c.read(chatProvider.notifier).send('q', locale: 'en');
    await _settle();
    expect(s.repo.sends.single.deviceId, isNull);
    s.repo.last.add(const ChatDone(false));
    await s.repo.last.close();
    await f;
  });
  test('history loads once, prepends, sets nextBefore, and a failure is silent', () async {
    final s = _setup();
    s.repo.historyPage = ChatHistoryPage(messages: [ChatHistoryItem(id: 'a', role: 'user', content: 'old', createdAt: DateTime.utc(2026))], nextBefore: 'cur');
    await s.c.read(viewerIdProvider.future);
    final n = s.c.read(chatProvider.notifier);
    await n.loadHistory();
    await n.loadHistory(); // second call is a no-op
    expect(s.repo.historyCalls, 1);
    expect(s.c.read(chatProvider).bubbles.single.text, 'old');
    expect(s.c.read(chatProvider).nextBefore, 'cur');
    final s2 = _setup();
    s2.repo.historyError = StateError('x');
    await s2.c.read(viewerIdProvider.future);
    await s2.c.read(chatProvider.notifier).loadHistory();
    expect(s2.c.read(chatProvider).historyLoaded, isTrue);
  });
  test('clearHistory empties on success and keeps bubbles with clear_failed on failure', () async {
    final s = _setup();
    s.repo.historyPage = ChatHistoryPage(messages: [ChatHistoryItem(id: 'a', role: 'user', content: 'old', createdAt: DateTime.utc(2026))]);
    await s.c.read(viewerIdProvider.future);
    final n = s.c.read(chatProvider.notifier);
    await n.loadHistory();
    s.repo.clearError = StateError('x');
    await n.clearHistory();
    expect(s.c.read(chatProvider).errorCode, 'clear_failed');
    expect(s.c.read(chatProvider).bubbles, isNotEmpty);
    s.repo.clearError = null;
    await n.clearHistory();
    expect(s.c.read(chatProvider).bubbles, isEmpty);
  });
  test('the in-flight keep-alive is released after 90 s even if the stream never ends', () {
    fakeAsync((async) {
      final s = _setup();
      final n = s.c.read(chatProvider.notifier);
      n.send('q', locale: 'en');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 91));
      async.flushMicrotasks();
      expect(s.c.read(chatProvider).phase, ChatPhase.interrupted);
    });
  });
  test('the viewer id resolving mid-turn does not wipe the turn; a different account resets the chat', () async {
    final repo = FakeChatRepository();
    var viewer = 'u1';
    final c = ProviderContainer(overrides: [
      viewerIdProvider.overrideWith((ref) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return viewer;
      }),
      chatRepositoryProvider.overrideWithValue(repo),
      appLifecycleSourceProvider.overrideWithValue(FakeLifecycle()),
      chatDeviceIdProvider.overrideWith((ref) async => 'device-abc-123'),
    ]);
    addTearDown(c.dispose);
    c.listen(chatProvider, (_, _) {});
    final f = c.read(chatProvider.notifier).send('q', locale: 'en');
    await Future<void>.delayed(const Duration(milliseconds: 60)); // viewer resolves while the turn is open
    expect(c.read(chatProvider).bubbles, hasLength(2));
    expect(c.read(chatProvider).signedIn, isTrue);
    repo.last.add(const ChatDone(false));
    await repo.last.close();
    await f;
    viewer = 'u2';
    c.invalidate(viewerIdProvider);
    await c.read(viewerIdProvider.future);
    expect(c.read(chatProvider).bubbles, isEmpty);
  });

  test('loadOlder twice in a row fetches the page once (no duplicated bubbles)', () async {
    final s = _setup();
    s.repo.historyPage = ChatHistoryPage(
      messages: [ChatHistoryItem(id: 'a', role: 'user', content: 'newer', createdAt: DateTime.utc(2026, 2))],
      nextBefore: 'cur',
    );
    await s.c.read(viewerIdProvider.future);
    final n = s.c.read(chatProvider.notifier);
    await n.loadHistory();
    final calls = s.repo.historyCalls;
    s.repo.historyPage = ChatHistoryPage(messages: [ChatHistoryItem(id: 'z', role: 'user', content: 'older', createdAt: DateTime.utc(2026))]);
    await Future.wait([n.loadOlder(), n.loadOlder()]);
    expect(s.repo.historyCalls, calls + 1);
    expect(s.c.read(chatProvider).bubbles.map((b) => b.text), ['older', 'newer']);
  });
}
