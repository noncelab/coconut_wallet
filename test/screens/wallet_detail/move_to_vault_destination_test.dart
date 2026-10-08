import 'package:coconut_wallet/screens/wallet_detail/move_to_vault_bottom_sheets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no balance takes priority over every watch-only wallet count', () {
    for (final count in [0, 1, 2, 3]) {
      expect(resolveMoveToVaultDestination(0, count), MoveToVaultDestination.noBalance);
    }
  });
  test('positive balance without watch-only wallets shows the add-wallet sheet', () {
    expect(resolveMoveToVaultDestination(1, 0), MoveToVaultDestination.noWatchOnlyWallet);
  });
  test('two or more watch-only wallets show the selection sheet', () {
    for (final count in [2, 3]) {
      expect(resolveMoveToVaultDestination(1, count), MoveToVaultDestination.selectWatchOnlyWallet);
    }
  });
  test('positive balance with exactly one watch-only wallet opens send', () {
    expect(resolveMoveToVaultDestination(1, 1), MoveToVaultDestination.send);
  });
}
