import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/chat_models.dart';
import '../../core/providers.dart';

abstract class ChatRepository {
  Future<ChatHistoryPage> history({String? before});
  Future<void> clear();
  Stream<ChatEvent> send({required List<ChatTurnMessage> history, required String clientTurnId, required String locale, String? deviceId});
}

class ApiChatRepository implements ChatRepository {
  ApiChatRepository(this._api);
  final ApiClient _api;
  @override Future<ChatHistoryPage> history({String? before}) => _api.getChatHistory(before: before);
  @override Future<void> clear() => _api.deleteChatHistory();
  @override
  Stream<ChatEvent> send({required List<ChatTurnMessage> history, required String clientTurnId, required String locale, String? deviceId}) =>
      _api.postChatMessage(messages: history, clientTurnId: clientTurnId, locale: locale, deviceId: deviceId);
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ApiChatRepository(ref.watch(apiClientProvider)));
