import 'dart:convert';
import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur/ur.dart';

void main() {
  NetworkType.setNetworkType(NetworkType.regtest);

  group('createWalletFromUrBytes', () {
    const vpub =
        'vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg';
    const fingerprint = 'F75F5AB5';
    final walletAddService = WalletAddService();

    UR buildUrBytes(Map<String, dynamic> json) {
      final payload = cbor.encode(CborBytes(utf8.encode(jsonEncode(json))));
      return UR('bytes', Uint8List.fromList(payload));
    }

    test('Passport Prime(Sparrow) 형식의 UR bytes로 지갑을 생성', () {
      final ur = buildUrBytes({
        'chain': 'TBTC',
        'xfp': fingerprint,
        'account': 0,
        'bip84': {'deriv': "m/84'/1'/0'", 'xpub': vpub, 'xfp': fingerprint, 'name': 'p2wpkh'},
      });

      final wallet = walletAddService.createWalletFromUrBytes(
        ur: ur,
        name: '패스포트 프라임',
        walletImportSource: WalletImportSource.passport,
      );

      expect(wallet.name, '패스포트 프라임');
      expect(wallet.walletImportSource, WalletImportSource.passport);
      expect(wallet.descriptor, contains(vpub));
      expect(wallet.descriptor.toUpperCase(), contains(fingerprint));
    });

    test('bip84 정보가 없으면 예외 발생', () {
      final ur = buildUrBytes({'chain': 'TBTC', 'xfp': fingerprint, 'account': 0});

      expect(
        () => walletAddService.createWalletFromUrBytes(
          ur: ur,
          name: '패스포트 프라임',
          walletImportSource: WalletImportSource.passport,
        ),
        throwsException,
      );
    });

    test('JSON이 아닌 UR bytes는 예외 발생', () {
      final payload = cbor.encode(CborBytes(utf8.encode('not json')));
      final ur = UR('bytes', Uint8List.fromList(payload));

      expect(
        () => walletAddService.createWalletFromUrBytes(
          ur: ur,
          name: '패스포트 프라임',
          walletImportSource: WalletImportSource.passport,
        ),
        throwsA(anything),
      );
    });
  });
}
