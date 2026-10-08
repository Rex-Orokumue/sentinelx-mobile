DateTime _utc(String iso) => DateTime.parse(iso).toUtc();

class DeletionState {
  const DeletionState({required this.requestedAt, required this.dueAt, required this.daysRemaining});
  factory DeletionState.fromJson(Map<String, dynamic> j) => DeletionState(
        requestedAt: _utc(j['requestedAt'] as String),
        dueAt: _utc(j['dueAt'] as String),
        daysRemaining: (j['daysRemaining'] as num).toInt(),
      );
  final DateTime requestedAt;
  final DateTime dueAt;
  final int daysRemaining;
}

class DeletionTicket {
  const DeletionTicket({required this.requestedAt, required this.dueAt});
  factory DeletionTicket.fromJson(Map<String, dynamic> j) =>
      DeletionTicket(requestedAt: _utc(j['requestedAt'] as String), dueAt: _utc(j['dueAt'] as String));
  final DateTime requestedAt;
  final DateTime dueAt;
}

/// One reason an account cannot be deleted yet. [code] is open-ended: an unknown code from a newer server
/// is kept (the screen shows a generic line for it) rather than dropped.
class DeletionBlocker {
  const DeletionBlocker({required this.code, this.amount, this.count});
  final String code;
  final num? amount;
  final int? count;

  static List<DeletionBlocker> listFrom(Map<String, dynamic> details) {
    final raw = details['blockers'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map<String, dynamic> && item['code'] is String)
          DeletionBlocker(
            code: item['code'] as String,
            amount: item['amount'] as num?,
            count: (item['count'] as num?)?.toInt(),
          ),
    ];
  }
}

class AccountSignIn {
  const AccountSignIn({required this.email, required this.pendingEmail, required this.passwordIdentity, required this.google});
  factory AccountSignIn.fromJson(Map<String, dynamic> j) => AccountSignIn(
        email: j['email'] as String?,
        pendingEmail: j['pendingEmail'] as String?,
        passwordIdentity: j['passwordIdentity'] as bool,
        google: j['google'] as bool,
      );
  final String? email;
  final String? pendingEmail;

  /// A hint, not truth: a Google user who set a password through the reset flow has no email identity.
  final bool passwordIdentity;
  final bool google;
}

class AccountPhone {
  const AccountPhone({required this.masked, required this.verifiedAt});
  factory AccountPhone.fromJson(Map<String, dynamic> j) =>
      AccountPhone(masked: j['masked'] as String, verifiedAt: _utc(j['verifiedAt'] as String));
  final String masked;
  final DateTime verifiedAt;
}

class MyAccount {
  const MyAccount({required this.deletion, required this.signIn, required this.phone, required this.locale});
  factory MyAccount.fromJson(Map<String, dynamic> j) => MyAccount(
        deletion: j['deletion'] == null ? null : DeletionState.fromJson(j['deletion'] as Map<String, dynamic>),
        signIn: AccountSignIn.fromJson(j['signIn'] as Map<String, dynamic>),
        phone: j['phone'] == null ? null : AccountPhone.fromJson(j['phone'] as Map<String, dynamic>),
        locale: j['locale'] as String?,
      );
  final DeletionState? deletion;
  final AccountSignIn signIn;
  final AccountPhone? phone;
  final String? locale;
}

class PhoneCodeTicket {
  const PhoneCodeTicket({required this.expiresAt, required this.resendAt});
  factory PhoneCodeTicket.fromJson(Map<String, dynamic> j) =>
      PhoneCodeTicket(expiresAt: _utc(j['expiresAt'] as String), resendAt: _utc(j['resendAt'] as String));
  final DateTime expiresAt;
  final DateTime resendAt;
}
