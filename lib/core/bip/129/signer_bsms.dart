import 'package:coconut_lib/coconut_lib.dart';

class SignerBsms {
  final String fingerprint;
  final String derivationPath;
  final String extendedKey;
  final String? label;

  SignerBsms._({required this.fingerprint, required this.derivationPath, required this.extendedKey, this.label});

  factory SignerBsms({
    required String fingerprint,
    required String derivationPath,
    required String extendedKey,
    String? label,
  }) {
    // 여기서 FormatException 던지기
    final fpReg = RegExp(r'^[0-9a-fA-F]{8}$');
    if (!fpReg.hasMatch(fingerprint)) {
      throw FormatException('Invalid fingerprint: $fingerprint');
    }

    if (derivationPath.isEmpty) {
      throw FormatException('Invalid derivation path: $derivationPath');
    }
    final splitedPath = derivationPath.split('/');
    if (splitedPath.length < 4) {
      throw FormatException('Invalidnvalid derivation path: $derivationPath');
    }

    if (extendedKey.isEmpty) {
      throw FormatException('Invalid extended key: $extendedKey');
    }
    // 일반적인 mainnet/testnet + SLIP-132 prefix들
    final xkeyReg = RegExp(r'^[a-zA-Z]pub[1-9A-HJ-NP-Za-km-z]+$');
    if (!xkeyReg.hasMatch(extendedKey)) {
      throw FormatException('Invalid extended key: $extendedKey');
    }
    try {
      ExtendedPublicKey.parse(extendedKey);
    } catch (e) {
      throw FormatException('Invalid extended key: $extendedKey');
    }

    return SignerBsms._(
      fingerprint: fingerprint,
      derivationPath: derivationPath,
      extendedKey: extendedKey,
      label: label,
    );
  }

  factory SignerBsms.parse(String raw) {
    final lines = raw.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    if (lines.length < 3) {
      throw FormatException('BSMS block too short: ${lines.length}');
    }

    final descLine = lines[2];
    final label = (lines.length >= 4) ? lines[3] : null;

    final reg = RegExp(r'^\[([0-9a-fA-F]{8})/([^\]]+)\](.+)$');
    final m = reg.firstMatch(descLine);
    if (m == null) {
      throw FormatException('Invalid BSMS descriptor line: $descLine');
    }

    final fp = m.group(1)!;
    final path = m.group(2)!;
    final xpub = m.group(3)!.trim();

    return SignerBsms(fingerprint: fp, derivationPath: path, extendedKey: xpub, label: label);
  }

  @override
  String toString() {
    return getSignerBsms();
  }

  String getSignerBsms({bool includesLabel = true}) {
    final descLine = '[$fingerprint/$derivationPath]$extendedKey';
    if (!includesLabel || (label == null || label!.isEmpty)) {
      return 'BSMS 1.0\n00\n$descLine';
    }

    return 'BSMS 1.0\n00\n$descLine\n$label';
  }
}
