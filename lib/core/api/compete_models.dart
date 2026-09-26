enum RegView { guest, canRegister, completePayment, registered, waitlisted, full, closed, ended, invitationOnly }

RegView _parseView(String s) => switch (s) {
      'guest' => RegView.guest,
      'can_register' => RegView.canRegister,
      'complete_payment' => RegView.completePayment,
      'registered' => RegView.registered,
      'waitlisted' => RegView.waitlisted,
      'full' => RegView.full,
      'closed' => RegView.closed,
      'ended' => RegView.ended,
      'invitation_only' => RegView.invitationOnly,
      _ => throw FormatException('Unknown registration view: $s'),
    };

class RegistrationState {
  const RegistrationState({
    required this.view,
    required this.feeNaira,
    required this.hasWaiver,
    required this.coinDiscountEligible,
    required this.agreementRequired,
  });

  factory RegistrationState.fromJson(Map<String, dynamic> j) => RegistrationState(
        view: _parseView(j['view'] as String),
        feeNaira: (j['feeNaira'] as num).toInt(),
        hasWaiver: j['hasWaiver'] as bool,
        coinDiscountEligible: j['coinDiscountEligible'] as bool,
        agreementRequired: j['agreementRequired'] as bool,
      );

  final RegView view;
  final int feeNaira;
  final bool hasWaiver;
  final bool coinDiscountEligible;
  final bool agreementRequired;
}

class RegistrationDetails {
  const RegistrationDetails({
    required this.displayName,
    required this.whatsapp,
    required this.clubName,
    this.ignTag,
    required this.agreedToRules,
  });

  final String displayName;
  final String whatsapp;
  final String clubName;
  final String? ignTag;
  final bool agreedToRules;

  Map<String, Object?> toJson() => {
        'displayName': displayName,
        'whatsapp': whatsapp,
        'clubName': clubName,
        if (ignTag != null && ignTag!.isNotEmpty) 'ignTag': ignTag,
        'agreedToRules': agreedToRules,
      };
}

sealed class RegisterOutcome {
  const RegisterOutcome();
}

class RegisterConfirmed extends RegisterOutcome {
  const RegisterConfirmed();
}

class RegisterPending extends RegisterOutcome {
  const RegisterPending({required this.authorizationUrl, required this.reference});
  final String authorizationUrl;
  final String reference;
}

RegisterOutcome parseRegisterOutcome(Object? data) {
  final j = data! as Map<String, dynamic>;
  return switch (j['status']) {
    'confirmed' => const RegisterConfirmed(),
    'pending' => RegisterPending(authorizationUrl: j['authorizationUrl'] as String, reference: j['reference'] as String),
    final other => throw FormatException('Unknown register status: $other'),
  };
}

enum PaymentStatus {
  confirmed,
  alreadyPaid,
  notFound,
  notSuccessful;

  bool get isPaid => this == confirmed || this == alreadyPaid;
}

PaymentStatus parsePaymentStatus(String s) => switch (s) {
      'confirmed' => PaymentStatus.confirmed,
      'already_paid' => PaymentStatus.alreadyPaid,
      'not_found' => PaymentStatus.notFound,
      'not_successful' => PaymentStatus.notSuccessful,
      _ => throw FormatException('Unknown payment status: $s'),
    };

class ProfileEdit {
  const ProfileEdit({
    required this.displayName,
    required this.username,
    required this.whatsapp,
    required this.country,
    required this.bio,
  });

  final String displayName;
  final String username;
  final String whatsapp;
  final String country;
  final String bio;

  Map<String, Object?> toJson() => {
        'displayName': displayName,
        'username': username,
        'whatsapp': whatsapp,
        'country': country,
        'bio': bio,
      };
}
