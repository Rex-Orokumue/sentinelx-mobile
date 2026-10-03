import '../../l10n/gen/app_localizations.dart';

/// OS-level notification permission, as the gateway reports it. Below Android 13 only [authorized] and
/// [denied] occur ([denied] there means notifications are turned off in system settings); [notDetermined]
/// exists only where a runtime prompt does.
enum PushPermission { notDetermined, authorized, denied, deniedPermanently }

String? _str(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

/// A push as the app sees it, independent of firebase_messaging's types.
class PushMessage {
  const PushMessage({this.title, this.body, this.url, this.type});

  final String? title, body, url, type;

  /// `data.url` is what the server sends today; `data.link` is accepted if it ever appears (spec §3.7).
  /// Blank or non-string values become null. Never throws.
  factory PushMessage.fromData(Map<String, dynamic> data, {String? title, String? body}) => PushMessage(
        title: _str(title) ?? _str(data['title']),
        body: _str(body) ?? _str(data['body']),
        url: _str(data['url']) ?? _str(data['link']),
        type: _str(data['type']),
      );
}

/// Android notification channels. Ids are versioned (Android freezes importance/sound at creation, so a
/// change needs a new id) and must match the web sender's table (lib/notifications/channels.ts).
const kPushChannelIds = <String>['matches_v1', 'social_v1', 'messages_v1', 'money_v1', 'admin_v1'];

class PushChannelSpec {
  const PushChannelSpec({required this.id, required this.name, required this.description, required this.highImportance});
  final String id, name, description;
  final bool highImportance;
}

List<PushChannelSpec> buildPushChannels(AppLocalizations l) => [
      PushChannelSpec(id: 'matches_v1', name: l.ntfChannelMatches, description: l.ntfChannelMatchesDesc, highImportance: true),
      PushChannelSpec(id: 'social_v1', name: l.ntfChannelSocial, description: l.ntfChannelSocialDesc, highImportance: false),
      PushChannelSpec(id: 'messages_v1', name: l.ntfChannelMessages, description: l.ntfChannelMessagesDesc, highImportance: true),
      PushChannelSpec(id: 'money_v1', name: l.ntfChannelMoney, description: l.ntfChannelMoneyDesc, highImportance: true),
      PushChannelSpec(id: 'admin_v1', name: l.ntfChannelAdmin, description: l.ntfChannelAdminDesc, highImportance: true),
    ];
