import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/wallet_models.dart';

void main() {
  group('WalletOverview.fromJson', () {
    test('parses a full overview, with a null trend and a pending transaction', () {
      final o = WalletOverview.fromJson({
        'balance': 5000,
        'pendingWithdrawal': 1000,
        'earnings': {'tournamentPrize': 5000, 'referral': 250, 'bonus': 700, 'tournamentPrizeTrendPct': null},
        'recentTransactions': [
          {
            'id': 't1',
            'type': 'withdrawal_request',
            'category': 'withdrawal',
            'amount': -1000,
            'createdAt': '2026-10-14T09:00:00.000Z',
            'status': 'pending',
          },
        ],
        'payoutAccount': {'bankName': 'GTBank', 'accountName': 'ADA OBI', 'accountNumberMasked': '•••6789'},
        'kycVerified': true,
        'activeWithdrawal': {'id': 'wr1', 'amount': 1000, 'requestedAt': '2026-10-14T09:00:00.000Z'},
      });
      expect(o.balance, 5000);
      expect(o.pendingWithdrawal, 1000);
      expect(o.earnings.tournamentPrizeTrendPct, isNull);
      expect(o.earnings.bonus, 700);
      expect(o.recentTransactions.single.status, 'pending');
      expect(o.recentTransactions.single.amount, -1000);
      expect(o.recentTransactions.single.createdAt, DateTime.utc(2026, 10, 14, 9));
      expect(o.payoutAccount!.accountNumberMasked, '•••6789');
      expect(o.activeWithdrawal!.id, 'wr1');
    });

    test('parses an overview with no payout account and no active withdrawal', () {
      final o = WalletOverview.fromJson({
        'balance': 0,
        'pendingWithdrawal': 0,
        'earnings': {'tournamentPrize': 0, 'referral': 0, 'bonus': 0, 'tournamentPrizeTrendPct': 50},
        'recentTransactions': <Object>[],
        'payoutAccount': null,
        'kycVerified': false,
        'activeWithdrawal': null,
      });
      expect(o.payoutAccount, isNull);
      expect(o.activeWithdrawal, isNull);
      expect(o.kycVerified, isFalse);
      expect(o.earnings.tournamentPrizeTrendPct, 50);
    });
  });

  test('WalletTxnPage keeps a null nextCursor', () {
    final p = WalletTxnPage.fromJson({'items': <Object>[], 'nextCursor': null});
    expect(p.items, isEmpty);
    expect(p.nextCursor, isNull);
  });

  test('DepositStart and WalletBank parse', () {
    final d = DepositStart.fromJson({
      'reference': 'r1', 'authorizationUrl': 'https://pay.test/x', 'amount': 5000, 'fee': 175, 'total': 5175,
    });
    expect(d.total, 5175);
    expect(WalletBank.fromJson({'name': 'GTBank', 'code': '058'}).code, '058');
  });

  group('DepositPoll.fromJson', () {
    const cases = {
      'confirmed': DepositStatus.confirmed,
      'already_paid': DepositStatus.alreadyPaid,
      'not_successful': DepositStatus.notSuccessful,
      'not_found': DepositStatus.notFound,
    };
    for (final entry in cases.entries) {
      test('maps ${entry.key}', () {
        final poll = DepositPoll.fromJson({'status': entry.key, 'balance': entry.value == DepositStatus.confirmed ? 6000 : null});
        expect(poll.status, entry.value);
        expect(poll.balance, entry.value == DepositStatus.confirmed ? 6000 : isNull);
      });
    }

    test('an unknown status throws, so a contract change fails loudly instead of silently', () {
      expect(() => DepositPoll.fromJson({'status': 'refunded', 'balance': null}), throwsFormatException);
    });
  });

  group('Withdrawal.fromJson', () {
    test('parses a pending request with no resolved time', () {
      final w = Withdrawal.fromJson({
        'id': 'wr1', 'amount': 1500, 'status': 'pending',
        'requestedAt': '2026-10-15T10:00:00.000Z', 'resolvedAt': null,
        'payoutAccount': {'bankName': 'GTBank', 'accountName': 'ADA OBI', 'accountNumberMasked': '•••6789'},
      });
      expect(w.status, 'pending');
      expect(w.resolvedAt, isNull);
      expect(w.requestedAt, DateTime.utc(2026, 10, 15, 10));
      expect(w.payoutAccount.bankName, 'GTBank');
    });

    test('WithdrawalPage parses items and a cursor', () {
      final p = WithdrawalPage.fromJson({
        'items': [
          {
            'id': 'wr1', 'amount': 1500, 'status': 'paid',
            'requestedAt': '2026-10-15T10:00:00.000Z', 'resolvedAt': '2026-10-16T10:00:00.000Z',
            'payoutAccount': {'bankName': 'GTBank', 'accountName': 'ADA OBI', 'accountNumberMasked': '•••6789'},
          },
        ],
        'nextCursor': 'abc',
      });
      expect(p.items.single.resolvedAt, DateTime.utc(2026, 10, 16, 10));
      expect(p.nextCursor, 'abc');
    });
  });
}
