import 'dart:convert';
import 'dart:typed_data';

import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_server_config.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the total adds spendable and every pending part', () {
    final balance = ArkBalance.fromBark(
      bark.Balance(
        spendableSats: 1000,
        pendingInRoundSats: 1,
        pendingExitSats: 2,
        pendingLightningSendSats: 3,
        claimableLightningReceiveSats: 4,
        pendingBoardSats: 5,
      ),
    );

    expect(balance.spendable, 1000);
    expect(balance.pending, 15);
    expect(balance.total, 1015);
  });

  test('the fingerprint is the BIP32 master fingerprint without a passphrase', () async {
    NetworkType.setNetworkType(NetworkType.regtest);
    final mnemonic = Uint8List.fromList(utf8.encode('${'abandon ' * 11}about'));

    expect(await ArkWalletService().fingerprintOf(mnemonic), '73c5da0a');
  });

  test('without a server address the server counts as reachable', () async {
    expect(ArkServerConfig.serverUrl, isEmpty);
    expect(await ArkWalletService.canReachServer(), isTrue);
  });
}
