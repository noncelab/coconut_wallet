import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/bip/129/multisig_normalizer.dart';
import 'package:coconut_wallet/core/bip/129/signer_bsms.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/hash_util.dart';

class BsmsComparison {
  const BsmsComparison({
    required this.quorum,
    required this.fingerprints,
    required this.derivationPaths,
    required this.extendedPublicKeys,
    required this.scriptType,
    required this.firstAddress,
    required this.configHash,
  });

  final bool quorum, fingerprints, derivationPaths, extendedPublicKeys, scriptType, firstAddress;
  final String configHash;

  bool get matched => quorum && fingerprints && derivationPaths && extendedPublicKeys && scriptType && firstAddress;
}

abstract final class WalletVerification {
  static const maxBackupBytes = 64 * 1024;

  static int? matchReceiveAddress(WalletBase wallet, String scanned) {
    final address = extractAddressFromBip21(scanned.trim());
    // Bech32 전체 대문자는 허용하지만 대소문자 혼합은 잘못된 QR이다.
    final bech32 = RegExp(r'^(bc1|tb1|bcrt1)', caseSensitive: false).hasMatch(address);
    if (bech32 && address != address.toLowerCase() && address != address.toUpperCase()) return null;
    final normalized = bech32 ? address.toLowerCase() : address;
    for (var index = 0; index < 20; index++) {
      if (wallet.getAddress(index, isChange: false) == normalized) return index;
    }
    return null;
  }

  static String descriptorHash(String descriptor) => generateHashString(descriptor);

  static String configHash(MultisignatureWallet wallet) => descriptorHash(wallet.descriptor);

  static BsmsComparison compareBsms(MultisignatureWallet wallet, Object backup) {
    try {
      final text = _backupText(backup);
      final lines = text.split(RegExp(r'\r?\n')).map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
      if (lines.first != 'BSMS 1.0') throw const FormatException();
      final descriptorLines = lines.where((line) => line.contains('sortedmulti(')).toList();
      if (descriptorLines.length != 1) throw const FormatException();
      final descriptor = descriptorLines.single;
      final actual = MultisigNormalizer.fromCoordinatorResult(text);
      final expected = MultisigNormalizer.fromCoordinatorResult('BSMS 1.0\n${wallet.descriptor}');
      final sameCount = actual.totalSigners == expected.totalSigners;
      bool every(bool Function(int index) matches) =>
          sameCount && List.generate(expected.totalSigners, (index) => index).every(matches);

      // sortedmulti는 순서가 달라도 같지만 키와 출처의 연결은 보존해야 한다.
      String identity(SignerBsms signer) =>
          '${signer.extendedKey}:${signer.fingerprint.toUpperCase()}:'
          '${MultisigNormalizer.normalizeDerivationPath(signer.derivationPath)}';
      final actualSigners = [...actual.signerBsms]..sort((a, b) => identity(a).compareTo(identity(b)));
      final expectedSigners = [...expected.signerBsms]..sort((a, b) => identity(a).compareTo(identity(b)));

      var firstAddressMatches = true;
      final descriptorIndex = lines.indexOf(descriptor);
      final extraLines = lines.sublist(descriptorIndex + 1);
      if (extraLines.isNotEmpty) {
        if (extraLines.length != 2 || (extraLines.first != '/0/*,/1/*' && extraLines.first != 'No path restrictions')) {
          throw const FormatException();
        }
        firstAddressMatches = extraLines.last == wallet.getAddress(0);
      }
      if (descriptorIndex > 2 || (descriptorIndex == 2 && lines[1] != '00')) throw const FormatException();

      // 정규화기가 버리는 스크립트·주소 체인도 원문에서 확인한다.
      var script = descriptor.split('#').first;
      if (script.contains('/**')) {
        if (extraLines.isEmpty || extraLines.first != '/0/*,/1/*') throw const FormatException();
        script = script.replaceAll('/**', '/<0;1>/*');
      }
      final expectedScript = wallet.descriptor.split('#').first;
      String structure(String value) => value.replaceAll(RegExp(r'\[[^\]]+\][A-Za-z0-9]+'), 'KEY');
      final scriptMatches =
          structure(script).replaceFirst(RegExp(r'sortedmulti\(\d+,'), 'sortedmulti(M,') ==
          structure(expectedScript).replaceFirst(RegExp(r'sortedmulti\(\d+,'), 'sortedmulti(M,');
      if (scriptMatches) Descriptor.parse(descriptor, ignoreChecksum: !descriptor.contains('#'));

      return BsmsComparison(
        quorum: actual.requiredCount == wallet.requiredSignature && sameCount,
        fingerprints: every(
          (i) => actualSigners[i].fingerprint.toUpperCase() == expectedSigners[i].fingerprint.toUpperCase(),
        ),
        derivationPaths: every(
          (i) =>
              MultisigNormalizer.normalizeDerivationPath(actualSigners[i].derivationPath) ==
              MultisigNormalizer.normalizeDerivationPath(expectedSigners[i].derivationPath),
        ),
        extendedPublicKeys: every((i) => actualSigners[i].extendedKey == expectedSigners[i].extendedKey),
        scriptType: scriptMatches,
        firstAddress: firstAddressMatches,
        configHash: configHash(wallet),
      );
    } catch (_) {
      // 파서 예외에 공개키나 디스크립터가 포함될 수 있다.
      throw const FormatException('Invalid BSMS backup');
    }
  }

  static String _backupText(Object backup) {
    String bounded(String text) {
      if (text.length > maxBackupBytes || utf8.encode(text).length > maxBackupBytes) throw const FormatException();
      return text.trim();
    }

    Object value = backup;
    if (value is String) {
      final text = bounded(value);
      value = text.startsWith('{') ? jsonDecode(text) : text;
    }
    if (value is Map) {
      final text = value['coordinatorBsms'];
      if (text is String) return bounded(text);
      final descriptor = value['descriptor'];
      if (descriptor is String) return 'BSMS 1.0\n${bounded(descriptor)}';
      throw const FormatException();
    }
    if (value is! String || value.trim().isEmpty) throw const FormatException();
    final text = value.trim();
    return text.startsWith('BSMS') ? text : 'BSMS 1.0\n$text';
  }
}
