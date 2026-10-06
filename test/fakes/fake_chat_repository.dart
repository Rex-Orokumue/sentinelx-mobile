import 'dart:async';
import 'package:sentinelx_mobile/core/api/chat_models.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_repository.dart';

class FakeChatRepository implements ChatRepository {
  final sends = <({List<ChatTurnMessage> history, String turnId, String locale, String? deviceId})>[];
  final controllers = <StreamController<ChatEvent>>[];
  ChatHistoryPage historyPage = const ChatHistoryPage(messages: []);
  Object? historyError;
  Object? clearError;
  Object? sendError; // thrown by the stream before any event
  int clears = 0, historyCalls = 0;

  StreamController<ChatEvent> get last => controllers.last;

  @override
  Stream<ChatEvent> send({required List<ChatTurnMessage> history, required String clientTurnId, required String locale, String? deviceId}) {
    sends.add((history: history, turnId: clientTurnId, locale: locale, deviceId: deviceId));
    final c = StreamController<ChatEvent>();
    controllers.add(c);
    if (sendError != null) {
      scheduleMicrotask(() { c.addError(sendError!); c.close(); });
    }
    return c.stream;
  }
  @override Future<ChatHistoryPage> history({String? before}) async { historyCalls++; if (historyError != null) throw historyError!; return historyPage; }
  @override Future<void> clear() async { clears++; if (clearError != null) throw clearError!; }
}
