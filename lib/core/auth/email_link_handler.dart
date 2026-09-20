import 'package:supabase_flutter/supabase_flutter.dart';

enum EmailLinkOutcome { verified, recovery, failed }

class EmailLinkResult {
  const EmailLinkResult(this.outcome);
  final EmailLinkOutcome outcome;
}

const _typeMap = {
  'signup': OtpType.signup,
  'recovery': OtpType.recovery,
  'email_change': OtpType.emailChange,
  'invite': OtpType.invite,
  'magiclink': OtpType.magiclink,
};

// Handles a claimed https://sentinelxesports.com.ng/auth/confirm App Link.
// Same token_hash+type flow the web route (app/auth/confirm/route.ts) uses —
// verifyOtp establishes a session locally, no code exchange, no fragment.
Future<EmailLinkResult> handleEmailLink(Uri link, {required GoTrueClient auth}) async {
  final tokenHash = link.queryParameters['token_hash'];
  final typeParam = link.queryParameters['type'];
  final type = typeParam == null ? null : _typeMap[typeParam];
  if (tokenHash == null || type == null) return const EmailLinkResult(EmailLinkOutcome.failed);

  try {
    await auth.verifyOTP(type: type, tokenHash: tokenHash);
  } catch (_) {
    return const EmailLinkResult(EmailLinkOutcome.failed);
  }

  return EmailLinkResult(type == OtpType.recovery ? EmailLinkOutcome.recovery : EmailLinkOutcome.verified);
}
