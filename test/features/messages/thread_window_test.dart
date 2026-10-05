import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/messages_models.dart';
import 'package:sentinelx_mobile/features/messages/messages_repository.dart';
import 'package:sentinelx_mobile/features/messages/thread_window.dart';

import '../../fakes/fake_messages_repository.dart';

DateTime _at(int i) => DateTime.utc(2026, 10, 5, 10).add(Duration(seconds: i));

/// Newest first, like the server: ids m(n-1) down to m0, where m(i) was created at second i.
List<DmMessage> _thread(int n, {int offset = 0}) => [for (var i = n - 1; i >= 0; i--) dmMsg('m${i + offset}', at: _at(i + offset))];

List<String> _ids(List<DmMessage> l) => [for (final m in l) m.id];

/// A fake server holding [all] (newest first), serving pages of [size] with positional cursors.
Future<MessagesPage> Function(String?) _server(List<DmMessage> all, {int size = 40, List<String?>? log}) => (before) async {
      log?.add(before);
      final start = before == null ? 0 : int.parse(before);
      final end = (start + size).clamp(0, all.length);
      return MessagesPage(messages: all.sublist(start, end), nextBefore: end < all.length ? '$end' : null);
    };

void main() {
  group('mergeNewestPage', () {
    test('replaces an edited message in place (same id, new body and editedAt)', () {
      final window = _thread(3);
      final edited = dmMsg('m1', at: _at(1), body: 'changed', editedAt: _at(9));
      final merged = mergeNewestPage(window, MessagesPage(messages: [window[0], edited, window[2]]));
      expect(_ids(merged), ['m2', 'm1', 'm0']);
      expect(merged[1].body, 'changed');
      expect(merged[1].isEdited, isTrue);
    });

    test('applies an unsend (deletedAt) and a receipt (readAt)', () {
      final window = _thread(3);
      final unsent = dmMsg('m2', at: _at(2), deletedAt: _at(8));
      final read = dmMsg('m0', at: _at(0), readAt: _at(7));
      final merged = mergeNewestPage(window, MessagesPage(messages: [unsent, window[1], read]));
      expect(merged[0].kind, MessageKind.removed);
      expect(merged[2].readAt, isNotNull);
    });

    test('inserts a new newest message and keeps newest-first order', () {
      final window = _thread(3);
      final merged = mergeNewestPage(window, MessagesPage(messages: [dmMsg('new', at: _at(50)), ...window]));
      expect(_ids(merged), ['new', 'm2', 'm1', 'm0']);
    });

    test('older loaded rows beyond the page are untouched', () {
      final window = _thread(80); // m79..m0
      final newest = [dmMsg('m80', at: _at(80)), ...window.take(39)]; // a page of 40: m80, m79..m41
      final merged = mergeNewestPage(window, MessagesPage(messages: newest, nextBefore: '40'));
      expect(merged, hasLength(81));
      expect(_ids(merged).first, 'm80');
      expect(_ids(merged).last, 'm0');
      expect(identical(merged.last, window.last), isTrue, reason: 'older rows are the same objects');
    });

    test('a local row newer than the whole page is kept (a send that landed after the fetch)', () {
      final window = [dmMsg('just-sent', at: _at(99)), ..._thread(3)];
      final merged = mergeNewestPage(window, MessagesPage(messages: _thread(3)));
      expect(_ids(merged), ['just-sent', 'm2', 'm1', 'm0']);
    });

    test('a row inside the page range that the server no longer returns is dropped', () {
      final window = _thread(3);
      final merged = mergeNewestPage(window, MessagesPage(messages: [window[0], window[2]]));
      expect(_ids(merged), ['m2', 'm0']);
    });

    test('an empty page leaves the window alone', () {
      final window = _thread(3);
      expect(identical(mergeNewestPage(window, const MessagesPage(messages: [])), window), isTrue);
    });
  });

  group('reconcileWindow', () {
    test('three new messages: a single fetch and no gap', () async {
      final log = <String?>[];
      final window = _thread(10);
      final server = [dmMsg('n3', at: _at(103)), dmMsg('n2', at: _at(102)), dmMsg('n1', at: _at(101)), ...window];
      final r = await reconcileWindow(window: window, windowNextBefore: null, fetch: _server(server, log: log));
      expect(log, [null]);
      expect(_ids(r.messages), ['n3', 'n2', 'n1', for (var i = 9; i >= 0; i--) 'm$i']);
      expect(r.droppedOld, isFalse);
    });

    test('60 new messages (more than a page): walks to a second page until it overlaps, no hole', () async {
      final log = <String?>[];
      final window = _thread(10); // m9..m0
      final fresh = [for (var i = 59; i >= 0; i--) dmMsg('n$i', at: _at(200 + i))];
      final server = [...fresh, ...window];
      final r = await reconcileWindow(window: window, windowNextBefore: null, fetch: _server(server, log: log));
      expect(log, [null, '40'], reason: 'second page needed to reach the overlap');
      expect(_ids(r.messages), [for (var i = 59; i >= 0; i--) 'n$i', for (var i = 9; i >= 0; i--) 'm$i']);
      expect(r.droppedOld, isFalse);
    });

    test('keeps the window next-before when the overlap is found (older pages stay reachable)', () async {
      final window = _thread(80);
      final r = await reconcileWindow(window: window, windowNextBefore: 'older-cursor', fetch: _server(window));
      expect(r.nextBefore, 'older-cursor');
      expect(r.messages, hasLength(80));
    });

    test('no overlap within maxPages: the old window is dropped, hasMore stays true, no exception', () async {
      final log = <String?>[];
      final window = _thread(5);
      final server = [for (var i = 399; i >= 0; i--) dmMsg('n$i', at: _at(1000 + i))]; // never reaches the old rows
      final r = await reconcileWindow(window: window, windowNextBefore: null, maxPages: 3, fetch: _server(server, log: log));
      expect(log, [null, '40', '80']);
      expect(r.droppedOld, isTrue);
      expect(r.messages, hasLength(120));
      expect(r.nextBefore, '120');
      expect(r.messages.any((m) => m.id.startsWith('m')), isFalse);
    });

    test('an empty window takes the first page only', () async {
      final log = <String?>[];
      final r = await reconcileWindow(window: const [], windowNextBefore: null, fetch: _server(_thread(100), log: log));
      expect(log, [null]);
      expect(r.messages, hasLength(40));
      expect(r.nextBefore, '40');
    });

    test('a fetch error propagates and leaves the caller free to keep its window', () async {
      await expectLater(
        reconcileWindow(window: _thread(3), windowNextBefore: null, fetch: (_) async => throw networkError),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('appendOlder / upsertMessage', () {
    test('appendOlder de-dupes a message that slid across the boundary', () {
      final window = _thread(4);
      final page = MessagesPage(messages: [window.last, dmMsg('older', at: _at(-5))]);
      final merged = appendOlder(window, page);
      expect(_ids(merged), ['m3', 'm2', 'm1', 'm0', 'older']);
    });

    test('upsertMessage replaces by id and otherwise inserts in createdAt order', () {
      final window = _thread(3);
      expect(_ids(upsertMessage(window, dmMsg('m1', at: _at(1), body: 'x'))), ['m2', 'm1', 'm0']);
      expect(upsertMessage(window, dmMsg('m1', at: _at(1), body: 'x'))[1].body, 'x');
      expect(_ids(upsertMessage(window, dmMsg('mid', at: DateTime.utc(2026, 10, 5, 10, 0, 1, 500)))), ['m2', 'mid', 'm1', 'm0']);
      expect(_ids(upsertMessage(window, dmMsg('newest', at: _at(99)))), ['newest', 'm2', 'm1', 'm0']);
    });
  });

  group('pending items', () {
    test('a non-retryable code hides retry; network and unknown errors keep it', () {
      PendingItem item(Object e) => PendingItem(
            clientKey: 'k',
            localId: 'l',
            draft: const SendDraft(body: 'x'),
            status: PendingStatus.failed,
            error: e,
            queuedAt: _at(0),
          );
      for (final code in ['blocked', 'blocked_by_me', 'messaging_restricted', 'request_pending_limit', 'request_media_not_allowed', 'validation']) {
        expect(item(apiError(code, status: 403)).canRetry, isFalse, reason: code);
      }
      expect(item(networkError).canRetry, isTrue);
      expect(item(apiError('send_failed', status: 500)).canRetry, isTrue);
      expect(item(StateError('x')).canRetry, isTrue);
    });
  });
}
