import '../../core/api/notifications_models.dart';
import '../../core/routing/web_links.dart';

final _communityPost = RegExp(r'^/community/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$', caseSensitive: false);

String? _text(Object? v) => v is String ? v : null;

/// One row of the in-app bell (`player_notifications`). The server stores title/body already rendered in
/// the recipient's language, so the app displays them verbatim. Parsing is deliberately tolerant — a newer
/// server may add a `type` this build has never seen, and one odd row must never fail the whole list.
class BellNotification {
  const BellNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.link,
    required this.read,
    required this.createdAt,
  });

  final String id, type, title, body;
  final String? link;
  final bool read;
  final DateTime createdAt;

  /// Null only when `id` is missing: a row with no id cannot be marked read, muted or opened.
  static BellNotification? tryParse(Map<String, dynamic> row) {
    final id = _text(row['id']);
    if (id == null || id.isEmpty) return null;
    final link = _text(row['link'])?.trim();
    return BellNotification(
      id: id,
      type: _text(row['type']) ?? '',
      title: _text(row['title']) ?? '',
      body: _text(row['body']) ?? '',
      link: (link == null || link.isEmpty) ? null : link,
      read: row['read'] == true,
      createdAt: DateTime.tryParse(_text(row['created_at']) ?? '')?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  BellNotification copyWith({bool? read}) => BellNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        link: link,
        read: read ?? this.read,
        createdAt: createdAt,
      );

  /// The post id when `link` points at a community post (web path, with or without host/locale), else null.
  /// Reuses [resolveWebLink] so the notion of "a post link" has exactly one definition.
  String? get postId {
    final l = link;
    if (l == null) return null;
    final resolved = resolveWebLink(l);
    if (resolved == null) return null;
    return _communityPost.firstMatch(resolved)?.group(1);
  }

  /// True when the server lets this type be muted (the 17 user-toggleable push types).
  bool get typeMutable => kPushPrefKeys.contains(type);
}
