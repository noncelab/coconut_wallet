import 'package:coconut_wallet/utils/wallet_section_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('moving down preserves interleaved wallets of the other type', () {
    final order = [1, 10, 2, 20, 3];
    expect(reorderWalletSection(order, [1, 2, 3], 0, 3), [2, 10, 3, 20, 1]);
    expect(order, [1, 10, 2, 20, 3]);
  });

  test('moving up only changes the selected section', () {
    expect(reorderWalletSection([1, 10, 2, 20, 3], [10, 20], 1, 0), [1, 20, 2, 10, 3]);
  });

  test('dropping in the same position preserves the order', () {
    expect(reorderWalletSection([1, 10, 2], [1, 2], 0, 1), [1, 10, 2]);
  });

  test('a single-wallet section preserves the order', () {
    expect(reorderWalletSection([1, 10], [10], 0, 1), [1, 10]);
  });
}
