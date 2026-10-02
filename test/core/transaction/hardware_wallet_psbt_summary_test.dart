import 'dart:convert';
import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/hardware_wallet_psbt_summary.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestWallet extends WalletBase {
  final String changeAddress;

  _TestWallet(this.changeAddress) : super(AddressType.p2wpkh, "m/84'/1'/0'");

  @override
  String addSignatureToPsbt(String psbt) => throw UnimplementedError();

  @override
  String getAddress(int addressIndex, {bool isChange = false}) => throw UnimplementedError();

  @override
  String getAddressWithDerivationPath(String derivationPath) => changeAddress;

  @override
  String getKeyOriginExpression() => throw UnimplementedError();

  @override
  bool hasPublicKeyInPsbt(String psbt) => throw UnimplementedError();
}

void main() {
  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));
  tearDownAll(() => NetworkType.setNetworkType(NetworkType.testnet));

  test('보낼 금액과 주소에서 거스름돈 output을 제외한다', () {
    final fixture =
        jsonDecode(File('test/fixtures/signing/trezor_usb.json').readAsStringSync()) as Map<String, dynamic>;
    final psbtBase64 = fixture['unsignedPsbt'] as String;
    final psbt = Psbt.parse(psbtBase64);
    final changeOutput = psbt.outputs.firstWhere(
      (output) => output.bip32Derivations.any((derivation) => derivation.path.split('/').reversed.skip(1).first == '1'),
    );

    final summary = HardwareWalletPsbtSummary.parse(
      psbtBase64: psbtBase64,
      wallet: _TestWallet(changeOutput.outAddress),
    );

    expect(summary.amount, 10000);
    expect(summary.fee, 141);
    expect(summary.totalCost, 10141);
    expect(summary.recipientAddresses, hasLength(1));
    expect(summary.recipientAddresses, isNot(contains(changeOutput.outAddress)));
  });
}
