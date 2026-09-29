import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations_en.dart';
import 'package:sentinelx_mobile/features/community/community_error_copy.dart';

void main() {
  group('communityErrorCopy', () {
    late AppLocalizations l10n;

    setUp(() {
      l10n = AppLocalizationsEn();
    });

    test('returns non-empty copy for all expected error codes', () {
      final codes = [
        'network',
        'unauthorized',
        'idempotency_in_progress',
        'validation_failed',
        'not_found',
        'forbidden',
        'already_boosted',
        'active_boost_exists',
        'insufficient_coins',
        'boost_failed',
        'voting_closed',
        'already_voted',
        'already_reported',
        'report_failed',
        'upload_failed',
      ];

      for (final code in codes) {
        final result = communityErrorCopy(l10n, code);
        expect(result.isNotEmpty, true,
            reason: 'Code "$code" should return non-empty copy');
      }
    });

    test('returns distinct strings for first 13 business-facing codes', () {
      final businessFacingCodes = [
        'network',
        'unauthorized',
        'idempotency_in_progress',
        'validation_failed',
        'not_found',
        'forbidden',
        'already_boosted',
        'active_boost_exists',
        'insufficient_coins',
        'voting_closed',
        'already_voted',
        'already_reported',
        'upload_failed',
      ];

      final outputs = <String>{};
      for (final code in businessFacingCodes) {
        outputs.add(communityErrorCopy(l10n, code));
      }

      expect(outputs.length, greaterThanOrEqualTo(12),
          reason:
              'Should have at least 12 distinct messages for business-facing codes');
    });

    test('returns generic error for unknown codes', () {
      expect(communityErrorCopy(l10n, 'something_new'), l10n.cmtEcGeneric);
      expect(communityErrorCopy(l10n, ''), l10n.cmtEcGeneric);
    });

    test('returns generic error for server-internal codes', () {
      expect(communityErrorCopy(l10n, 'boost_failed'), l10n.cmtEcGeneric,
          reason: 'boost_failed is internal 500, not player-facing');
      expect(communityErrorCopy(l10n, 'report_failed'), l10n.cmtEcGeneric,
          reason: 'report_failed is internal 500, not player-facing');
    });

    test('specific error codes map to expected localized strings', () {
      expect(communityErrorCopy(l10n, 'network'), l10n.cmtEcNetwork);
      expect(communityErrorCopy(l10n, 'unauthorized'), l10n.cmtEcSession);
      expect(communityErrorCopy(l10n, 'idempotency_in_progress'),
          l10n.cmtEcInProgress);
      expect(communityErrorCopy(l10n, 'validation_failed'),
          l10n.cmtEcValidation);
      expect(communityErrorCopy(l10n, 'not_found'), l10n.cmtEcNotFound);
      expect(communityErrorCopy(l10n, 'forbidden'), l10n.cmtEcForbidden);
      expect(
          communityErrorCopy(l10n, 'already_boosted'), l10n.cmtEcAlreadyBoosted);
      expect(communityErrorCopy(l10n, 'active_boost_exists'),
          l10n.cmtEcActiveBoostExists);
      expect(communityErrorCopy(l10n, 'insufficient_coins'),
          l10n.cmtEcInsufficientCoins);
      expect(communityErrorCopy(l10n, 'voting_closed'), l10n.cmtEcVotingClosed);
      expect(
          communityErrorCopy(l10n, 'already_voted'), l10n.cmtEcAlreadyVoted);
      expect(communityErrorCopy(l10n, 'already_reported'),
          l10n.cmtEcAlreadyReported);
      expect(communityErrorCopy(l10n, 'upload_failed'), l10n.cmtEcUploadFailed);
    });
  });
}
