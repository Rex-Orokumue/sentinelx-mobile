// Phase 5b direct-message wire models. Shapes come from the web repo's mobile-v1 OpenAPI contract
// (messages/** operations). Parsing is deliberately tolerant: `preview.kind`, `requestState` and
// `direction` are plain strings on the wire, an unknown value degrades instead of throwing, and one
// malformed row is skipped rather than failing the whole response.

enum PreviewKind { text, image, sticker, voice, removed, unknown }

PreviewKind parsePreviewKind(String? s) => switch (s) {
      'text' => PreviewKind.text,
      'image' => PreviewKind.image,
      'sticker' => PreviewKind.sticker,
      'voice' => PreviewKind.voice,
      'removed' => PreviewKind.removed,
      _ => PreviewKind.unknown,
    };

enum RequestState { pending, accepted, declined, unknown }

RequestState parseRequestState(Object? s) => switch (s) {
      'pending' => RequestState.pending,
      'accepted' => RequestState.accepted,
      'declined' => RequestState.declined,
      _ => RequestState.unknown,
    };

enum RequestDirection { incoming, outgoing }

RequestDirection? parseRequestDirection(Object? s) => switch (s) {
      'incoming' => RequestDirection.incoming,
      'outgoing' => RequestDirection.outgoing,
      _ => null,
    };

enum MessageKind { text, image, sticker, voice, removed, unknown }

String? _str(Object? v) => v is String ? v : null;

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

class OtherPlayer {
  const OtherPlayer({required this.id, required this.name, this.username, this.avatarUrl});

  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;

  String get displayName => name.trim().isNotEmpty ? name : (username ?? '?');

  static OtherPlayer? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = _str(json['id']);
    if (id == null) return null;
    return OtherPlayer(
      id: id,
      name: _str(json['name']) ?? '',
      username: _str(json['username']),
      avatarUrl: _str(json['avatarUrl']),
    );
  }
}

class ThreadPreview {
  const ThreadPreview({required this.kind, this.text, this.stickerId});

  final PreviewKind kind;
  final String? text;
  final String? stickerId;

  factory ThreadPreview.fromJson(Object? json) {
    if (json is! Map) return const ThreadPreview(kind: PreviewKind.unknown);
    return ThreadPreview(
      kind: parsePreviewKind(_str(json['kind'])),
      text: _str(json['text']),
      stickerId: _str(json['stickerId']),
    );
  }
}

class ThreadSummary {
  const ThreadSummary({
    required this.threadId,
    required this.other,
    required this.preview,
    required this.lastMessageAt,
    required this.unread,
    required this.requestState,
    this.direction,
  });

  final String threadId;
  final OtherPlayer other;
  final ThreadPreview preview;
  final DateTime lastMessageAt;
  final int unread;
  final RequestState requestState;
  final RequestDirection? direction;

  /// Null for a malformed row (missing id / other player).
  static ThreadSummary? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = _str(json['threadId']);
    final other = OtherPlayer.tryParse(json['other']);
    if (id == null || other == null) return null;
    final unread = json['unread'];
    return ThreadSummary(
      threadId: id,
      other: other,
      preview: ThreadPreview.fromJson(json['preview']),
      lastMessageAt: _date(json['lastMessageAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      unread: unread is num ? unread.toInt() : 0,
      requestState: parseRequestState(json['requestState']),
      direction: parseRequestDirection(json['direction']),
    );
  }
}

class ThreadsPage {
  const ThreadsPage({required this.threads, this.nextCursor, this.requestCount = 0});

  final List<ThreadSummary> threads;
  final String? nextCursor;
  final int requestCount;

  factory ThreadsPage.fromJson(Map<String, dynamic> j) {
    final rows = j['threads'];
    final count = j['requestCount'];
    return ThreadsPage(
      threads: [
        if (rows is List)
          for (final r in rows)
            ?ThreadSummary.tryParse(r),
      ],
      nextCursor: _str(j['nextCursor']),
      requestCount: count is num ? count.toInt() : 0,
    );
  }
}

class ThreadHeader {
  const ThreadHeader({
    required this.threadId,
    required this.other,
    required this.blockedByMe,
    required this.blockedByThem,
    required this.requestState,
    this.direction,
  });

  final String threadId;
  final OtherPlayer other;
  final bool blockedByMe;
  final bool blockedByThem;
  final RequestState requestState;
  final RequestDirection? direction;

  factory ThreadHeader.fromJson(Map<String, dynamic> j) => ThreadHeader(
        threadId: _str(j['threadId']) ?? '',
        other: OtherPlayer.tryParse(j['other']) ?? const OtherPlayer(id: '', name: ''),
        blockedByMe: j['blockedByMe'] == true,
        blockedByThem: j['blockedByThem'] == true,
        requestState: parseRequestState(j['requestState']),
        direction: parseRequestDirection(j['direction']),
      );

  /// The sender-side decline is reported by the server as `blockedByThem`; the app never shows "declined".
  bool get iAmBlocked => blockedByThem;

  bool get canSend => !blockedByMe && !blockedByThem && requestState != RequestState.declined;
}

class ReplyPreview {
  const ReplyPreview({required this.id, this.senderName, this.body, this.removed = false});

  final String id;
  final String? senderName;
  final String? body;
  final bool removed;

  static ReplyPreview? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = _str(json['id']);
    if (id == null) return null;
    return ReplyPreview(
      id: id,
      senderName: _str(json['senderName']),
      body: _str(json['body']),
      removed: json['removed'] == true,
    );
  }
}

class DmMessage {
  const DmMessage({
    required this.id,
    required this.senderId,
    required this.createdAt,
    this.body,
    this.imageUrl,
    this.stickerId,
    this.audioUrl,
    this.audioDurationSeconds,
    this.forwarded = false,
    this.deliveredAt,
    this.readAt,
    this.editedAt,
    this.deletedAt,
    this.replyTo,
  });

  final String id;
  final String senderId;
  final String? body;
  final String? imageUrl;
  final String? stickerId;
  final String? audioUrl;
  final int? audioDurationSeconds;
  final bool forwarded;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final ReplyPreview? replyTo;

  /// Removed iff `deletedAt` is set (even with a stale body); else audio > image > sticker > text.
  MessageKind get kind {
    if (deletedAt != null) return MessageKind.removed;
    if (audioUrl != null) return MessageKind.voice;
    if (imageUrl != null) return MessageKind.image;
    if (stickerId != null) return MessageKind.sticker;
    if (body != null) return MessageKind.text;
    return MessageKind.unknown;
  }

  bool isMine(String viewerId) => senderId == viewerId;

  bool get isEdited => editedAt != null;

  DmMessage copyWith({
    String? body,
    DateTime? editedAt,
    DateTime? deletedAt,
    bool clearContent = false,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) =>
      DmMessage(
        id: id,
        senderId: senderId,
        createdAt: createdAt,
        body: clearContent ? null : (body ?? this.body),
        imageUrl: clearContent ? null : imageUrl,
        stickerId: clearContent ? null : stickerId,
        audioUrl: clearContent ? null : audioUrl,
        audioDurationSeconds: clearContent ? null : audioDurationSeconds,
        forwarded: forwarded,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        readAt: readAt ?? this.readAt,
        editedAt: editedAt ?? this.editedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        replyTo: replyTo,
      );

  static DmMessage? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = _str(json['id']);
    final senderId = _str(json['senderId']);
    final createdAt = _date(json['createdAt']);
    if (id == null || senderId == null || createdAt == null) return null;
    final dur = json['audioDurationSeconds'];
    return DmMessage(
      id: id,
      senderId: senderId,
      createdAt: createdAt,
      body: _str(json['body']),
      imageUrl: _str(json['imageUrl']),
      stickerId: _str(json['stickerId']),
      audioUrl: _str(json['audioUrl']),
      audioDurationSeconds: dur is num ? dur.round().clamp(1, 1 << 30) : null,
      forwarded: json['forwarded'] == true,
      deliveredAt: _date(json['deliveredAt']),
      readAt: _date(json['readAt']),
      editedAt: _date(json['editedAt']),
      deletedAt: _date(json['deletedAt']),
      replyTo: ReplyPreview.tryParse(json['replyTo']),
    );
  }
}

class MessagesPage {
  const MessagesPage({required this.messages, this.nextBefore});

  /// Newest first.
  final List<DmMessage> messages;
  final String? nextBefore;

  factory MessagesPage.fromJson(Map<String, dynamic> j) {
    final rows = j['messages'];
    return MessagesPage(
      messages: [
        if (rows is List)
          for (final r in rows)
            ?DmMessage.tryParse(r),
      ],
      nextBefore: _str(j['nextBefore']),
    );
  }
}
