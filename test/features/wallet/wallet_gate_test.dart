import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/wallet/wallet_gate.dart';

import '../../fakes/fake_wallet_repository.dart';
import 'wallet_test_harness.dart';

void main() {
  testWidgets('a player sees the wallet screen', (tester) async {
    await pumpWallet(
      tester,
      const WalletGate(child: Text('wallet-child')),
      repo: FakeWalletRepository(),
      overrides: [roleProvider.overrideWithValue(AppRole.player)],
    );
    expect(find.text('wallet-child'), findsOneWidget);
  });

  testWidgets('a signed-out visitor sees the log-in prompt, not the child', (tester) async {
    await pumpWallet(tester, const WalletGate(child: Text('wallet-child')), repo: FakeWalletRepository(), viewer: null);
    expect(find.byKey(const Key('wallet-gate-login')), findsOneWidget);
    expect(find.text('wallet-child'), findsNothing);
  });

  testWidgets('a moderator is sent to /account and never sees a blank frame on the way', (tester) async {
    await pumpWallet(
      tester,
      const WalletGate(child: Text('wallet-child')),
      repo: FakeWalletRepository(),
      settle: false,
      overrides: [roleProvider.overrideWithValue(AppRole.moderator)],
    );
    // Walk frame by frame: at no point may the screen be empty (no spinner, no text, no child).
    for (var i = 0; i < 4; i++) {
      final visible = find.byKey(const Key('wallet-gate-loading')).evaluate().isNotEmpty ||
          find.text('wallet-child').evaluate().isNotEmpty ||
          find.text('page:/account').evaluate().isNotEmpty;
      expect(visible, isTrue, reason: 'frame $i was blank');
      expect(find.text('wallet-child'), findsNothing);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('page:/account'), findsOneWidget);
  });
}
