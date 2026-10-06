import '../../core/l10n/gen/app_localizations.dart';

/// Chat error code -> copy. Server text is never shown; unknown codes use the generic message.
String chatErrorMessage(AppLocalizations l, String code, {required bool signedIn, int? retryAfterSeconds}) => switch (code) {
      'chat_rate_limited' => l.chatErrorRateLimited(retryAfterSeconds ?? 60),
      'chat_unavailable' => signedIn ? l.chatErrorUnavailable : l.chatErrorUnavailableSignedOut,
      'unauthorized' => l.chatErrorUnauthorized,
      'chat_truncated' => l.chatErrorTruncated,
      'network' => l.chatErrorNetwork,
      'clear_failed' => l.chatErrorClear,
      _ => l.chatErrorGeneric,
    };
