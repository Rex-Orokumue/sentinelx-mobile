import 'dart:convert';

enum ChatDestination {
  tournaments, matches, wallet, profile, notifications, rules, safety, help;
  static ChatDestination? parse(Object? v) {
    if (v is! String) return null;
    for (final d in values) {
      if (d.name == v) return d;
    }
    return null;
  }
}

sealed class ChatEvent { const ChatEvent(); }
class ChatStatus extends ChatEvent { const ChatStatus(); }
class ChatDelta extends ChatEvent { const ChatDelta(this.text); final String text; }
class ChatActions extends ChatEvent { const ChatActions(this.items); final List<ChatDestination> items; }
class ChatDone extends ChatEvent { const ChatDone(this.persisted); final bool persisted; }
class ChatError extends ChatEvent { const ChatError(this.code); final String code; }

/// One NDJSON line -> event. Anything unreadable or from a newer server returns null so the stream keeps going.
ChatEvent? parseChatLine(String line) {
  final s = line.trim();
  if (s.isEmpty) return null;
  final Object? j;
  try {
    j = jsonDecode(s);
  } catch (_) {
    return null;
  }
  if (j is! Map<String, dynamic>) return null;
  switch (j['t']) {
    case 'status':
      return const ChatStatus();
    case 'delta':
      final t = j['text'];
      return t is String ? ChatDelta(t) : null;
    case 'actions':
      final items = j['items'];
      return ChatActions(items is List ? items.map(ChatDestination.parse).whereType<ChatDestination>().toList() : const []);
    case 'done':
      return ChatDone(j['persisted'] == true);
    case 'error':
      final c = j['code'];
      return ChatError(c is String ? c : 'internal');
  }
  return null;
}

class ChatTurnMessage {
  const ChatTurnMessage(this.role, this.content);
  final String role;
  final String content;
  Map<String, Object?> toJson() => {'role': role, 'content': content};
}

class ChatHistoryItem {
  const ChatHistoryItem({required this.id, required this.role, required this.content, required this.createdAt});
  final String id, role, content;
  final DateTime createdAt;
  static ChatHistoryItem? tryParse(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    final id = j['id'], role = j['role'], content = j['content'], at = j['createdAt'];
    if (id is! String || content is! String || at is! String) return null;
    if (role != 'user' && role != 'assistant') return null;
    final t = DateTime.tryParse(at);
    return t == null ? null : ChatHistoryItem(id: id, role: role as String, content: content, createdAt: t);
  }
}

class ChatHistoryPage {
  const ChatHistoryPage({required this.messages, this.nextBefore});
  final List<ChatHistoryItem> messages;
  final String? nextBefore;
  factory ChatHistoryPage.fromJson(Map<String, dynamic> j) {
    final raw = j['messages'];
    return ChatHistoryPage(
      messages: raw is List ? raw.map(ChatHistoryItem.tryParse).whereType<ChatHistoryItem>().toList() : const [],
      nextBefore: j['nextBefore'] as String?,
    );
  }
}

// C0/C1 controls except \n \t \r, bidi overrides/isolates and marks. ZWJ/ZWNJ stay (emoji sequences).
final _unsafe = RegExp('[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]');
String cleanChatText(String s) => s.replaceAll(_unsafe, '');
