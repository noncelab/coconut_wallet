import 'package:coconut_wallet/utils/mfp_format.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mock/wallet_mock.dart';

void main() {
  test('formatMfp splits eight characters into two upper-case groups', () {
    expect(formatMfp('73c5da0a'), '73C5 DA0A');
  });

  test('formatMfp returns other lengths unchanged', () {
    expect(formatMfp('abc'), 'abc');
  });

  test('walletMasterFingerprint reads a single-sig wallet fingerprint', () {
    expect(walletMasterFingerprint(WalletMock.createSingleSigWalletItem())?.toUpperCase(), 'D45AA182');
  });

  test('walletMasterFingerprint is null for a multisig wallet', () {
    expect(walletMasterFingerprint(WalletMock.createMultiSigWalletItem()), isNull);
  });
}
