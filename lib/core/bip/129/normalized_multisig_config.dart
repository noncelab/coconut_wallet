import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/bip/129/signer_bsms.dart';

class NormalizedMultisigConfig {
  final String name;
  final int requiredCount; // m
  final List<SignerBsms> signerBsms; // 각 signer BSMS (BIP-129 형식)

  const NormalizedMultisigConfig._({required this.name, required this.requiredCount, required this.signerBsms});

  factory NormalizedMultisigConfig({
    required String name,
    required int requiredCount,
    required List<String> signerBsms,
  }) {
    if (requiredCount <= 0) {
      throw ArgumentError('requiredCount must be > 0');
    }
    if (signerBsms.length <= 1) {
      throw ArgumentError('signerBsms must have at least 2 elements');
    }
    if (requiredCount > signerBsms.length) {
      throw ArgumentError('requiredCount ($requiredCount) cannot be greater than total signers (${signerBsms.length})');
    }

    List<SignerBsms> signerBsmsList = [];
    try {
      signerBsmsList = signerBsms.map((sb) => SignerBsms.parse(sb)).toList();
    } catch (_) {
      throw const FormatException('Invalid BSMS format');
    }

    return NormalizedMultisigConfig._(name: name.trim(), requiredCount: requiredCount, signerBsms: signerBsmsList);
  }

  int get totalSigners => signerBsms.length;

  // # Keystone Multisig setup file (created by Coconut Vaults)
  // #
  //
  // Name: keyston-multisig
  // Policy: 2 of 2
  // Derivation: m/48'/0'/0'/2'
  // Format: P2WSH
  //
  // A3B2EB70: xpub6E9t6eQGiTVTG99xWo6KEdYAVyGtrmkCNgbTPVPSEvA6wgAS2irZxLdvbLBTz5XURtLSB2LPMZHf85CJxapgr8NpYcdDX56UKpVvZ5qxu9k
  // A0F6BA00: xpub6Dtc8ee6APa87VBy7LoZo6RfdGY3k8gnPzT1TYvHygVPJhur24RgEk9FftpzcvPhQgk9j5WKr5jkxs1Lhew25ffN5tLQfkcdE6Lz5DosnsT

  String getMultisigConfigString({AddressType? addressType}) {
    final type = addressType ?? AddressType.p2wsh;
    if (type == AddressType.p2wsh) {
      final coin = NetworkType.currentNetworkType == NetworkType.mainnet ? 0 : 1;
      final policy = '$requiredCount of ${signerBsms.length}';
      // 현재 정책에 따라 P2WSH만 지원하므로 고정
      final derivationPath = "m/${type.purposeIndex}'/$coin'/0'/2'";
      final scriptType = type.name.toUpperCase();

      final configString =
          StringBuffer()
            ..writeln('# Keystone Multisig setup file (created by Coconut Vault)')
            ..writeln('#')
            ..writeln()
            ..writeln('Name: $name')
            ..writeln('Policy: $policy')
            ..writeln('Derivation: $derivationPath')
            ..writeln('Format: $scriptType')
            ..writeln();

      for (final s in signerBsms) {
        configString.writeln('${s.fingerprint.toUpperCase()}: ${s.extendedKey}');
      }

      return configString.toString();
    } else {
      throw UnimplementedError('Unsupported address type: ${type.name}');
    }
  }

  Set<String> get signerFingerprints => signerBsms.map((bsms) => bsms.fingerprint).toSet();
}
