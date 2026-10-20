import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/services/safety/wallet_verification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NetworkType previousNetwork;
  late List<Seed> seeds;
  late MultisignatureWallet multisig;

  setUpAll(() {
    previousNetwork = NetworkType.currentNetworkType;
    NetworkType.setNetworkType(NetworkType.regtest);
    seeds = List.generate(3, (i) => Seed.fromEntropy(Uint8List.fromList(List.filled(16, i + 1))));
    multisig = MultisignatureWallet.fromDescriptor(MultisignatureVault.fromSeedList(seeds, 2).descriptor);
  });
  tearDownAll(() => NetworkType.setNetworkType(previousNetwork));

  for (final kind in ['p2wpkh', 'taproot', 'p2wsh']) {
    group(kind, () {
      late WalletBase wallet;
      setUp(() {
        wallet = switch (kind) {
          'p2wpkh' => SingleSignatureWallet.fromDescriptor(SingleSignatureVault.fromSeed(seeds.first).descriptor),
          'taproot' => TaprootWallet.fromDescriptor(
            SingleSignatureVault.fromSeed(seeds.first, addressType: AddressType.p2tr).descriptor,
          ),
          _ => multisig,
        };
      });
      test(
        'matches receive index 0',
        () => expect(WalletVerification.matchReceiveAddress(wallet, wallet.getAddress(0)), 0),
      );
      test(
        'matches receive index 19',
        () => expect(WalletVerification.matchReceiveAddress(wallet, wallet.getAddress(19)), 19),
      );
      test(
        'rejects receive index 20',
        () => expect(WalletVerification.matchReceiveAddress(wallet, wallet.getAddress(20)), isNull),
      );
      test(
        'rejects change index 0',
        () => expect(WalletVerification.matchReceiveAddress(wallet, wallet.getAddress(0, isChange: true)), isNull),
      );
      test('accepts BIP21 and uppercase Bech32', () {
        expect(
          WalletVerification.matchReceiveAddress(wallet, ' BITCOIN:${wallet.getAddress(0).toUpperCase()}?amount=1 '),
          0,
        );
      });
      test('rejects mixed-case Bech32', () {
        final address = wallet.getAddress(0);
        expect(WalletVerification.matchReceiveAddress(wallet, 'B${address.substring(1)}'), isNull);
      });
      test('rejects non-address input', () {
        expect(WalletVerification.matchReceiveAddress(wallet, 'not an address'), isNull);
      });
    });
  }

  String backup(String descriptor) => 'BSMS 1.0\n$descriptor';
  String body() => multisig.descriptor.split('#').first;
  List<String> keys() => RegExp(r'\[[^\]]+\][A-Za-z0-9]+/<0;1>/\*').allMatches(body()).map((m) => m.group(0)!).toList();

  group('BSMS', () {
    test('accepts full BIP129 and the app descriptor-only export', () {
      final full = Bsms.fromCoordinator(multisig.getAddress(0), multisig.descriptor).serializeCoordinator();
      expect(WalletVerification.compareBsms(multisig, full).matched, isTrue);
      expect(WalletVerification.compareBsms(multisig, backup(multisig.descriptor)).matched, isTrue);
    });
    test('accepts Coconut and descriptor JSON exports', () {
      expect(
        WalletVerification.compareBsms(multisig, jsonEncode({'coordinatorBsms': backup(multisig.descriptor)})).matched,
        isTrue,
      );
      expect(WalletVerification.compareBsms(multisig, {'descriptor': multisig.descriptor}).matched, isTrue);
    });
    test('normalizes hardened path and fingerprint notation', () {
      final normalized = body()
          .replaceAll("'", 'h')
          .replaceAllMapped(RegExp(r'\[([A-Fa-f0-9]{8})/'), (match) => '[${match.group(1)!.toLowerCase()}/');
      expect(WalletVerification.compareBsms(multisig, backup(normalized)).matched, isTrue);
    });
    test('accepts reordered complete sortedmulti signer tuples', () {
      final reordered = 'wsh(sortedmulti(2,${keys().reversed.join(',')}))';
      expect(WalletVerification.compareBsms(multisig, backup(reordered)).matched, isTrue);
    });
    test('accepts a BIP129 descriptor template record with receive/change restrictions', () {
      final template = body().replaceAll('/<0;1>/*', '/**');
      final record = 'BSMS 1.0\n00\n$template\n/0/*,/1/*\n${multisig.getAddress(0)}';
      expect(WalletVerification.compareBsms(multisig, record).matched, isTrue);
    });
    test('rejects a template without the exact receive/change restrictions', () {
      final template = body().replaceAll('/<0;1>/*', '/**');
      for (final restrictions in ['', 'No path restrictions', '/1/*,/0/*', '/0/*,/2/*']) {
        final record =
            restrictions.isEmpty ? backup(template) : '${backup(template)}\n$restrictions\n${multisig.getAddress(0)}';
        expect(() => WalletVerification.compareBsms(multisig, record), throwsFormatException);
      }
    });
    test('keeps signer origins associated with their account keys', () {
      final original = keys();
      final origins = original.map((key) => key.substring(0, key.indexOf(']') + 1)).toList();
      final swapped = [
        original[0].replaceFirst(origins[0], origins[1]),
        original[1].replaceFirst(origins[1], origins[0]),
        original[2],
      ];
      expect(
        WalletVerification.compareBsms(multisig, backup('wsh(sortedmulti(2,${swapped.join(',')}))')).matched,
        isFalse,
      );
    });
    test('retains signer multiplicity and rejects unsorted multi', () {
      final duplicate = [keys()[0], keys()[0], keys()[2]];
      expect(
        () => WalletVerification.compareBsms(multisig, backup('wsh(sortedmulti(2,${duplicate.join(',')}))')),
        throwsFormatException,
      );
      expect(
        () => WalletVerification.compareBsms(multisig, backup(body().replaceFirst('sortedmulti(', 'multi('))),
        throwsFormatException,
      );
    });
    test('rejects changed fingerprint', () {
      final changed = body().replaceFirst(RegExp(r'\[[A-Fa-f0-9]{8}/'), '[deadbeef/');
      final result = WalletVerification.compareBsms(multisig, backup(changed));
      expect(result.fingerprints, isFalse);
      expect(result.matched, isFalse);
    });
    test('rejects changed derivation path', () {
      final changed = body().replaceFirst("48'/1'/0'/2'", "48'/1'/1'/2'");
      final result = WalletVerification.compareBsms(multisig, backup(changed));
      expect(result.derivationPaths, isFalse);
      expect(result.matched, isFalse);
    });
    test('rejects changed quorum', () {
      final result = WalletVerification.compareBsms(
        multisig,
        backup(body().replaceFirst('sortedmulti(2,', 'sortedmulti(1,')),
      );
      expect(result.quorum, isFalse);
      expect(result.matched, isFalse);
    });
    test('rejects changed account key', () {
      final other = KeyStore.fromSeed(Seed.fromEntropy(Uint8List.fromList(List.filled(16, 9))), AddressType.p2wsh);
      final changed = body().replaceFirst(
        multisig.keyStoreList.first.extendedPublicKey.serialize(),
        other.extendedPublicKey.serialize(),
      );
      final result = WalletVerification.compareBsms(multisig, backup(changed));
      expect(result.extendedPublicKeys, isFalse);
      expect(result.matched, isFalse);
    });
    test('rejects changed script wrapper', () {
      final result = WalletVerification.compareBsms(multisig, backup('sh(${body()})'));
      expect(result.scriptType, isFalse);
      expect(result.matched, isFalse);
    });
    test('rejects changed receive/change chain suffix', () {
      final result = WalletVerification.compareBsms(multisig, backup(body().replaceFirst('/<0;1>/*', '/<1;0>/*')));
      expect(result.scriptType, isFalse);
      expect(result.matched, isFalse);
    });
    test('rejects inconsistent first address in backup', () {
      final full = '${backup(multisig.descriptor)}\n/0/*,/1/*\n${multisig.getAddress(1)}';
      expect(WalletVerification.compareBsms(multisig, full).matched, isFalse);
    });
    test('rejects invalid checksum without exposing the backup in the exception', () {
      expect(
        () => WalletVerification.compareBsms(multisig, backup('${body()}#aaaaaaaa')),
        throwsA(isA<FormatException>().having((e) => e.message, 'sanitized error', 'Invalid BSMS backup')),
      );
    });
    test('rejects malformed and ambiguous backups', () {
      for (final malformed in [
        '',
        'not BSMS',
        'BSMS 2.0\n${multisig.descriptor}',
        '${backup(multisig.descriptor)}\n${multisig.descriptor}',
        '${backup(multisig.descriptor)}\nunexpected',
      ]) {
        expect(() => WalletVerification.compareBsms(multisig, malformed), throwsFormatException);
      }
    });
    test('rejects oversized raw and JSON backups before parsing', () {
      final oversized = '${backup(multisig.descriptor)}${' ' * (64 * 1024)}';
      for (final input in [
        oversized,
        jsonEncode({'coordinatorBsms': oversized}),
        {'descriptor': oversized},
      ]) {
        expect(() => WalletVerification.compareBsms(multisig, input), throwsFormatException);
      }
    });
    test('rejects a backup from another network', () {
      late String mainnet;
      try {
        NetworkType.setNetworkType(NetworkType.mainnet);
        mainnet = MultisignatureVault.fromSeedList(seeds, 2).descriptor;
      } finally {
        NetworkType.setNetworkType(NetworkType.regtest);
      }
      expect(() => WalletVerification.compareBsms(multisig, backup(mainnet)), throwsFormatException);
    });
  });

  test('descriptor hash is stable and differs by wallet', () {
    final first = WalletVerification.descriptorHash(multisig.descriptor);
    final same = WalletVerification.configHash(MultisignatureWallet.fromDescriptor(multisig.descriptor));
    final different = WalletVerification.descriptorHash(SingleSignatureVault.fromSeed(seeds.first).descriptor);
    expect(first == same, isTrue);
    expect(first != different, isTrue);
    expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(first), isTrue);
  });
  test('config hash changes when quorum, fingerprint, or key order changes', () {
    final original = WalletVerification.configHash(multisig);
    final alternatives = [
      body().replaceFirst('sortedmulti(2,', 'sortedmulti(1,'),
      body().replaceFirst(RegExp(r'\[[A-Fa-f0-9]{8}/'), '[deadbeef/'),
      'wsh(sortedmulti(2,${keys().reversed.join(',')}))',
    ];
    for (final descriptor in alternatives) {
      final other = MultisignatureWallet.fromDescriptor(descriptor, ignoreChecksum: true);
      expect(WalletVerification.configHash(other) != original, isTrue);
    }
  });
}
