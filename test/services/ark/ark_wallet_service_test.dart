import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_wallet/services/ark/ark_wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final exitConfirmed = bark.BlockRef(height: 100, hash: 'a' * 64);
  final claimed = bark.BlockRef(height: 112, hash: 'b' * 64);

  test('an exit dates from the block that confirmed its exit transaction', () {
    final states = <bark.ExitState>[
      bark.AwaitingDeltaExitState(tipHeight: 101, confirmedBlock: exitConfirmed, claimableHeight: 112),
      bark.ClaimedExitState(tipHeight: 113, txid: 'c' * 64, block: claimed),
    ];

    expect(ArkWalletService.exitConfirmedBlock(states)?.height, 100);
  });

  test('without that step in its history, an exit dates from the block it was claimed in', () {
    final states = <bark.ExitState>[bark.ClaimedExitState(tipHeight: 113, txid: 'c' * 64, block: claimed)];

    expect(ArkWalletService.exitConfirmedBlock(states)?.height, 112);
    expect(ArkWalletService.exitConfirmedBlock(const []), isNull);
  });
}
