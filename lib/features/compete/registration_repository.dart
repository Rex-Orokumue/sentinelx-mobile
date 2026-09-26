import '../../core/api/api_client.dart';
import '../../core/api/compete_models.dart';

abstract class RegistrationRepository {
  Future<RegistrationState> registrationState(String tournamentId);
  Future<RegisterOutcome> register(String tournamentId,
      {required RegistrationDetails details, required int coinsUsed, required String idempotencyKey});
  Future<void> joinWaitlist(String tournamentId, {required RegistrationDetails details});
  Future<RegisterOutcome> acceptInvitation(String invitationId, {required String idempotencyKey});
  Future<void> declineInvitation(String invitationId);
  Future<PaymentStatus> paymentStatus(String reference);
}

class ApiRegistrationRepository implements RegistrationRepository {
  ApiRegistrationRepository(this._api);
  final ApiClient _api;

  @override
  Future<RegistrationState> registrationState(String id) => _api.getTournamentRegistrationState(id);

  @override
  Future<RegisterOutcome> register(String id,
          {required RegistrationDetails details, required int coinsUsed, required String idempotencyKey}) =>
      _api.postTournamentRegister(id, details: details, coinsUsed: coinsUsed, idempotencyKey: idempotencyKey);

  @override
  Future<void> joinWaitlist(String id, {required RegistrationDetails details}) =>
      _api.postTournamentWaitlist(id, details: details);

  @override
  Future<RegisterOutcome> acceptInvitation(String id, {required String idempotencyKey}) =>
      _api.postInvitationAccept(id, idempotencyKey: idempotencyKey);

  @override
  Future<void> declineInvitation(String id) => _api.postInvitationDecline(id);

  @override
  Future<PaymentStatus> paymentStatus(String reference) => _api.getPaymentStatus(reference);
}
