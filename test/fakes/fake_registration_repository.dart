import 'package:sentinelx_mobile/core/api/compete_models.dart';
import 'package:sentinelx_mobile/core/api/registration_fields_models.dart';
import 'package:sentinelx_mobile/features/compete/registration_repository.dart';

class FakeRegistrationRepository implements RegistrationRepository {
  final registerKeys = <String>[];
  final acceptKeys = <String>[];
  final waitlistCalls = <RegistrationDetails>[];
  final paymentChecks = <String>[];
  final registerCoins = <int>[];
  final registerDetails = <RegistrationDetails>[];
  final declined = <String>[];
  int stateCalls = 0;

  /// Queue of results for register(); each entry is a RegisterOutcome or an Exception to throw.
  /// The last entry repeats once the queue is down to one.
  final registerResults = <Object>[];
  final acceptResults = <Object>[];
  Object? waitlistResult;
  Object? declineResult;
  final paymentResults = <Object>[]; // PaymentStatus or Exception; last one repeats
  Object? stateResult;
  Object fieldsResult = const <RegistrationField>[
    RegistrationField(fieldKey: 'club_name', label: 'Club name', placeholder: null,
      inputType: RegistrationFieldInputType.text, required: true, validationPattern: null, validationMessage: null),
  ];
  int fieldsCalls = 0;
  Future<void>? registerGate; // when set, register() awaits it (to hold a request in flight)
  Future<void>? acceptGate;
  Future<void>? declineGate;

  Object _next(List<Object> q) => q.length > 1 ? q.removeAt(0) : q.first;

  @override
  Future<RegistrationState> registrationState(String tournamentId) async {
    stateCalls++;
    final r = stateResult;
    if (r is Exception) throw r;
    return (r as RegistrationState?) ??
        const RegistrationState(view: RegView.canRegister, feeNaira: 500, hasWaiver: false, coinDiscountEligible: true, agreementRequired: true);
  }

  @override
  Future<List<RegistrationField>> registrationFields(String tournamentId) async {
    fieldsCalls++;
    final result = fieldsResult;
    if (result is Exception) throw result;
    return result as List<RegistrationField>;
  }

  @override
  Future<RegisterOutcome> register(String tournamentId,
      {required RegistrationDetails details, required int coinsUsed, required String idempotencyKey}) async {
    registerKeys.add(idempotencyKey);
    registerCoins.add(coinsUsed);
    registerDetails.add(details);
    if (registerGate != null) await registerGate;
    final r = _next(registerResults);
    if (r is Exception) throw r;
    return r as RegisterOutcome;
  }

  @override
  Future<void> joinWaitlist(String tournamentId, {required RegistrationDetails details}) async {
    waitlistCalls.add(details);
    final r = waitlistResult;
    if (r is Exception) throw r;
  }

  @override
  Future<RegisterOutcome> acceptInvitation(String invitationId, {required String idempotencyKey}) async {
    acceptKeys.add(idempotencyKey);
    if (acceptGate != null) await acceptGate;
    final r = _next(acceptResults);
    if (r is Exception) throw r;
    return r as RegisterOutcome;
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    declined.add(invitationId);
    if (declineGate != null) await declineGate;
    final r = declineResult;
    if (r is Exception) throw r;
  }

  @override
  Future<PaymentStatus> paymentStatus(String reference) async {
    paymentChecks.add(reference);
    final r = _next(paymentResults);
    if (r is Exception) throw r;
    return r as PaymentStatus;
  }
}
