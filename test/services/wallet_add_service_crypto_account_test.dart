import 'dart:convert';
import 'dart:typed_data';

import 'package:cbor/simple.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur/ur.dart';

void main() {
  final publicKey = Codec.decodeHex('033558A7656D16D946497D8B458AEB84CFCEB4F2D471D7FF5A9E4FA4488412DF63');
  final chainCode = Codec.decodeHex('23936EF00D3B0C27674C3EE47CFE8A5032AB161B3A1F851CF39977DFE06DD756');
  const master = 953202145;
  const parent = 3254928504;
  final service = WalletAddService();

  UR accountUr(List<Object> origin, {bool children = true}) {
    return UR(
      'crypto-account',
      Uint8List.fromList(
        cbor.encode({
          1: master,
          2: [
            {
              2: false,
              3: publicKey,
              4: chainCode,
              6: {1: origin, 2: master, 3: origin.length ~/ 2},
              if (children)
                7: {
                  1: [5, false, [], false],
                  3: 0,
                },
              8: parent,
            },
          ],
        }),
      ),
    );
  }

  WatchOnlyWallet import(UR ur) => service.createWalletFromUrCryptoAccount(
    ur: ur,
    name: 'Public account regression',
    walletImportSource: WalletImportSource.keystone,
  );

  setUp(() => NetworkType.setNetworkType(NetworkType.regtest));

  for (final index in [0, 7, 0x7fffffff]) {
    for (final hardened in [false, true]) {
      for (final children in [false, true]) {
        test('preserves account $index hardened=$hardened children=$children through reload', () {
          final imported = import(accountUr([84, true, 1, true, index, hardened], children: children));
          final reloaded = WatchOnlyWallet.fromJson(jsonDecode(imported.toJson()) as Map<String, dynamic>);
          final actual = SingleSignatureWallet.fromDescriptor(reloaded.descriptor);
          final path = "m/84'/1'/$index${hardened ? "'" : ''}";
          final expectedIndex = index + (hardened ? 0x80000000 : 0);
          final expectedKey = ExtendedPublicKey(
            3,
            Codec.decodeHex(Converter.decToHexWithPadding(parent, 8)),
            expectedIndex,
            chainCode,
            publicKey,
            AddressType.p2wpkh.versionForTestnet,
          );
          final original = SingleSignatureWallet(
            Converter.decToHexWithPadding(master, 8),
            HDWallet.fromPublicKey(publicKey, chainCode),
            AddressType.p2wpkh,
            path,
            expectedKey,
          );
          final key = actual.keyStore.extendedPublicKey;
          expect(key.index, expectedIndex);
          expect(key.depth, 3);
          expect(key.parentFingerprintByte, expectedKey.parentFingerprintByte);
          expect(key.publicKey, publicKey);
          expect(key.chainCode, chainCode);
          expect(key.version, expectedKey.version);
          expect(key.serialize(), expectedKey.serialize());
          expect(actual.derivationPath, path);
          expect(actual.keyStore.masterFingerprint.toLowerCase(), original.keyStore.masterFingerprint.toLowerCase());
          expect(actual.keyStore.hasSeed, isFalse);
          expect(imported.name, 'Public account regression');
          expect(imported.walletImportSource, WalletImportSource.keystone);
          for (final change in [false, true]) {
            for (var child = 0; child < 20; child++) {
              expect(actual.getAddress(child, isChange: change), original.getAddress(child, isChange: change));
            }
          }
        });
      }
    }
  }

  for (final origin in <List<Object>>[
    [84, true, 1, true, 0x80000000, false],
    [84, true, 1, true, 0x80000000, true],
    [84, true, 1, true, -1, true],
    [84, true, 1, true, '7junk', true],
    [84, true, 1, true, 7],
    [84, true, 0, true, 7, true],
    [
      84,
      true,
      1,
      true,
      0,
      true,
      for (var i = 0; i < 253; i++) ...[0, false],
    ],
  ]) {
    test('rejects invalid origin ${origin.length <= 6 ? origin : 'depth 256'}', () {
      expect(() => import(accountUr(origin)), throwsA(anything));
    });
  }
}
