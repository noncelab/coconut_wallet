import 'dart:convert';
import 'dart:typed_data';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/bip/129/normalized_multisig_config.dart';
import 'package:coconut_wallet/core/exceptions/network_mismatch_exception.dart';

/// CoordinatorBsmsQrDataHandler.result -> NormalizedMultisigConfig
class MultisigNormalizer {
  static NormalizedMultisigConfig fromCoordinatorResult(dynamic result) {
    if (result == null) {
      throw const FormatException('Empty coordinator result');
    }

    if (result is String) {
      final trimmed = result.trim();

      // 1) Coconut export 텍스트
      //    {name: ..., coordinatorBsms: ...} 같은 형태
      if (trimmed.contains('coordinatorBsms:')) {
        return _normalizeCoconutText(trimmed);
      }

      // 2) Sparrow / BlueWallet 텍스트
      if (trimmed.contains('Policy:') && trimmed.contains('Derivation:')) {
        return _normalizeText(trimmed);
      }

      // 3) BSMS 1.0 텍스트
      if (trimmed.startsWith('BSMS 1.0') && trimmed.contains('sortedmulti(')) {
        return _normalizeRawBsmsText(trimmed);
      }

      // 4) JSON Sparrow descriptor export 등
      if (trimmed.startsWith('{')) {
        try {
          final map = jsonDecode(trimmed) as Map<String, dynamic>;
          return _normalizeJson(map);
        } on FormatException catch (_) {
          final map = _parseLooseJsonLikeMap(trimmed);
          return _normalizeJson(map);
        }
      }
    }
    // json 형식
    final coordinatorBsms = result['coordinatorBsms'] as String?;
    if (coordinatorBsms != null) {
      return _normalizeCoconutText(result.toString().trim());
    }
    return _normalizeJson(result as Map<String, dynamic>);
  }

  static NormalizedMultisigConfig _normalizeCoconutText(String text) {
    final nameMatch = RegExp(r'name:\s*([^,}]+)').firstMatch(text);
    if (nameMatch == null) {
      throw const FormatException('name not found in coconut export');
    }
    final name = nameMatch.group(1)!.trim();

    final namesMapMatch = RegExp(r'namesMap:\s*\{([^}]+)\}').firstMatch(text);
    Map<String, String> namesMap = {};
    if (namesMapMatch != null) {
      final entries = namesMapMatch.group(1)!;
      for (final entry in entries.split(',')) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          final fingerprint = parts[0].trim().toUpperCase();
          final label = parts[1].trim();
          namesMap[fingerprint] = label;
        }
      }
    }

    final coordIdx = text.indexOf('coordinatorBsms:');
    if (coordIdx < 0) {
      throw const FormatException('coordinatorBsms not found in coconut export');
    }

    String coordBlock = text.substring(coordIdx + 'coordinatorBsms:'.length).trim();

    if (coordBlock.endsWith('}')) {
      coordBlock = coordBlock.substring(0, coordBlock.length - 1).trim();
    }

    final coordLines = coordBlock.split('\n');
    if (coordLines.length < 2) {
      throw const FormatException('Invalid coordinatorBsms block');
    }

    final descriptorLine = coordLines[1].trim();

    final sortedmultiMatch = RegExp(r'sortedmulti\((\d+),').firstMatch(descriptorLine);
    if (sortedmultiMatch == null) {
      throw const FormatException('Not a sortedmulti descriptor in coordinatorBsms');
    }
    final requiredCount = int.parse(sortedmultiMatch.group(1)!);

    final signerMatches = RegExp(r'\[([^\]]+)\]([A-Za-z0-9]+)').allMatches(descriptorLine);

    final signerBsms = <String>[];

    for (final match in signerMatches) {
      final bracketContent = match.group(1)!; // 73C5DA0A/48'/1'/0'/2'
      final xpub = match.group(2)!; // tpub...

      final slashIdx = bracketContent.indexOf('/');
      if (slashIdx <= 0) continue;

      final fpRaw = bracketContent.substring(0, slashIdx);
      final pathRaw = bracketContent.substring(slashIdx + 1); // 48'/1'/0'/2'

      final fingerprint = _normalizeFingerprint(fpRaw);
      final normalizedPath = _normalizeHardenedPath(pathRaw);

      final label = namesMap[fingerprint];

      final bsms = _buildSignerBsms(
        fingerprint: fingerprint,
        derivationPath: normalizedPath,
        extendedKey: xpub,
        label: label,
      );
      signerBsms.add(bsms);
    }

    return NormalizedMultisigConfig(name: name, requiredCount: requiredCount, signerBsms: signerBsms);
  }

  static NormalizedMultisigConfig _normalizeText(String text) {
    final lines = text.split('\n');

    final nameLine = lines.firstWhere(
      (l) => l.startsWith('Name:'),
      orElse: () => throw const FormatException('Name not found'),
    );
    final name = nameLine.split(':')[1].trim();

    final policyLine = lines.firstWhere(
      (l) => l.startsWith('Policy:'),
      orElse: () => throw const FormatException('Policy not found'),
    );
    final requiredCount = int.parse(policyLine.split(':')[1].trim().split(' ')[0]);

    final derivationLine = lines.firstWhere(
      (l) => l.startsWith('Derivation:'),
      orElse: () => throw const FormatException('Derivation not found'),
    );
    final derivationPath = derivationLine.split(':')[1].trim().replaceAll('m/', ''); // 예: 48'/1'/0'/2'

    // signer lines: FINGERPRINT: XPUB
    final signerLines = lines.where((l) => l.contains(':') && l.contains('pub')).toList();

    final signerBsms = <String>[];

    for (int i = 0; i < signerLines.length; i++) {
      final line = signerLines[i].trim();
      final parts = line.split(':');
      final xpub = parts[1].trim();

      final bsms = _buildSignerBsms(
        fingerprint: _normalizeFingerprint(parts[0]),
        derivationPath: _normalizeHardenedPath(derivationPath),
        extendedKey: xpub,
      );

      signerBsms.add(bsms);
    }

    return NormalizedMultisigConfig(name: name, requiredCount: requiredCount, signerBsms: signerBsms);
  }

  static NormalizedMultisigConfig _normalizeRawBsmsText(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    if (lines.isEmpty || lines[0] != 'BSMS 1.0') {
      throw const FormatException('Invalid BSMS header');
    }

    final descriptorLine = lines.firstWhere(
      (l) => l.contains('sortedmulti('),
      orElse: () => throw const FormatException('Descriptor line not found in BSMS text'),
    );

    final sortedmultiMatch = RegExp(r'sortedmulti\((\d+),').firstMatch(descriptorLine);
    if (sortedmultiMatch == null) {
      throw const FormatException('Not a sortedmulti descriptor in BSMS text');
    }
    final requiredCount = int.parse(sortedmultiMatch.group(1)!);

    final signerMatches = RegExp(r'\[([^\]]+)\]([A-Za-z0-9]+)').allMatches(descriptorLine);

    final signerBsms = <String>[];

    for (final match in signerMatches) {
      final bracketContent = match.group(1)!;
      final extendedKey = match.group(2)!;

      final slashIdx = bracketContent.indexOf('/');
      if (slashIdx <= 0) continue;

      final fpRaw = bracketContent.substring(0, slashIdx);
      final pathRaw = bracketContent.substring(slashIdx + 1);

      final fingerprint = _normalizeFingerprint(fpRaw);
      final normalizedPath = _normalizeHardenedPath(pathRaw);

      final bsms = _buildSignerBsms(fingerprint: fingerprint, derivationPath: normalizedPath, extendedKey: extendedKey);

      signerBsms.add(bsms);
    }

    return NormalizedMultisigConfig(name: '', requiredCount: requiredCount, signerBsms: signerBsms);
  }

  static NormalizedMultisigConfig _normalizeJson(Map<String, dynamic> json) {
    final name = (json['label'] ?? '') as String;
    final descriptor = json['descriptor'] as String?;

    if (descriptor == null) {
      throw const FormatException('descriptor not found in JSON');
    }

    final sortedmultiMatch = RegExp(r'sortedmulti\((\d+),').firstMatch(descriptor);
    if (sortedmultiMatch == null) {
      throw const FormatException('Not a sortedmulti descriptor');
    }
    final requiredCount = int.parse(sortedmultiMatch.group(1)!);

    final signerMatches = RegExp(r'\[([^\]]+)\]([A-Za-z0-9]+)').allMatches(descriptor);

    final signerBsms = <String>[];

    for (final match in signerMatches) {
      final bracketContent = match.group(1)!; // 73c5da0a/48h/1h/0h/2h
      final xpub = match.group(2)!; // tpub...

      final slashIdx = bracketContent.indexOf('/');
      if (slashIdx <= 0) continue;

      final fpRaw = bracketContent.substring(0, slashIdx);
      final pathRaw = bracketContent.substring(slashIdx + 1); // 48h/1h/0h/2

      final fingerprint = _normalizeFingerprint(fpRaw);
      final normalizedPath = _normalizeHardenedPath(pathRaw);

      final bsms = _buildSignerBsms(fingerprint: fingerprint, derivationPath: normalizedPath, extendedKey: xpub);
      signerBsms.add(bsms);
    }

    return NormalizedMultisigConfig(name: name, requiredCount: requiredCount, signerBsms: signerBsms);
  }

  static Map<String, dynamic> _parseLooseJsonLikeMap(String input) {
    var body = input.trim();

    if (body.startsWith('{')) {
      body = body.substring(1);
    }
    if (body.endsWith('}')) {
      body = body.substring(0, body.length - 1);
    }
    body = body.trim();

    final labelMatch = RegExp(r'label\s*:\s*([^,}]+)').firstMatch(body);
    if (labelMatch == null) {
      throw const FormatException('label not found in loose json-like string');
    }
    final label = labelMatch.group(1)!.trim();

    final descIndex = body.indexOf('descriptor:');
    if (descIndex < 0) {
      throw const FormatException('descriptor not found in loose json-like string');
    }
    var descriptor = body.substring(descIndex + 'descriptor:'.length).trim();
    if (descriptor.endsWith(',')) {
      descriptor = descriptor.substring(0, descriptor.length - 1).trim();
    }

    return <String, dynamic>{'label': label, 'descriptor': descriptor};
  }

  static String _normalizeFingerprint(String fp) {
    return fp.trim().toUpperCase();
  }

  static String _normalizeHardenedPath(String rawPathNoM) {
    final segments = rawPathNoM.split('/');

    final normalized =
        segments.map((seg) {
          seg = seg.trim();
          if (seg.isEmpty) return seg;

          if (seg.endsWith('h') || seg.endsWith('H')) {
            final trimmed = seg.substring(0, seg.length - 1);
            return '$trimmed\'';
          }
          return seg;
        }).toList();

    return normalized.join('/');
  }

  static String _buildSignerBsms({
    required String fingerprint,
    required String derivationPath,
    required String extendedKey,
    String? label,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('BSMS 1.0');
    buffer.writeln('00');
    buffer.write('[$fingerprint/$derivationPath]$extendedKey');

    if (label != null && label.trim().isNotEmpty) {
      buffer.write('\n${label.trim()}');
    }

    return buffer.toString();
  }

  /// keystone, jade 결과를 signer BSMS 형식으로 변환
  static String signerBsmsFromUrResult(Map<dynamic, dynamic> map) {
    Map<String, dynamic> jsonCompatibleMap = _convertKeysToString(map);

    final accounts = jsonCompatibleMap['2'];
    if (accounts == null || accounts is! List) {
      throw const FormatException('UR result does not contain key "2" (accounts list)');
    }

    final coin = NetworkType.currentNetworkType == NetworkType.mainnet ? 0 : 1;
    final targetPath1 = <dynamic>[48, true, coin, true, 0, true, 2, true];
    final targetPath2 = <dynamic>[48, 21, coin, 21, 0, 21, 2, 21];
    Map<String, dynamic>? targetEntry;
    for (final item in accounts) {
      if (item is! Map) continue;
      final m = _convertKeysToString(item);
      final origin = m['6'];
      if (origin == null || origin is! Map) continue;
      // final originMap = _convertKeysToString(origin);
      final pathList = origin['1'];
      if (pathList == null || pathList is! List) continue;

      if (pathList.length == targetPath1.length && pathList[2].value != targetPath1[2]) {
        throw NetworkMismatchException();
      }
      if (_listEquals(pathList, targetPath1) || _listEquals(pathList, targetPath2)) {
        targetEntry = m;
        break;
      }
    }

    if (targetEntry == null) {
      throw const FormatException('Required derivation path not found in UR result');
    }

    final origin = _convertKeysToString(targetEntry['6']);
    final rawPathList = origin['1'];
    if (rawPathList == null || rawPathList is! List) {
      throw const FormatException('Origin path ["6"]["1"] is missing or invalid');
    }
    final derivationPath = _derivationPathFromComponents(rawPathList);

    final mfpDec = origin['2'].value;
    if (mfpDec == null || mfpDec is! int) {
      throw const FormatException('Master fingerprint ["6"]["2"] is missing or invalid');
    }

    final mfp = Codec.decodeHex(Converter.decToHex(mfpDec));
    final pubKey = Uint8List.fromList(targetEntry['3'].bytes);
    final chainCode = Uint8List.fromList(targetEntry['4'].bytes);
    HDWallet wallet = HDWallet.fromPublicKey(pubKey, chainCode);
    wallet.depth = 3; //
    int version =
        NetworkType.currentNetworkType == NetworkType.mainnet
            ? AddressType.p2wsh.versionForMainnet
            : AddressType.p2wsh.versionForTestnet;
    final extendedPublicKey = ExtendedPublicKey.fromHdWallet(wallet, version, mfp);

    return _buildSignerBsms(
      fingerprint: mfpDec.toRadixString(16).padLeft(8, '0').toUpperCase(),
      derivationPath: derivationPath,
      extendedKey: extendedPublicKey.serialize(),
    );
  }

  static bool _listEquals(List<dynamic> a, List<dynamic> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].value != b[i]) return false;
    }
    return true;
  }

  static String _derivationPathFromComponents(List<dynamic> components) {
    if (components.length.isOdd) {
      throw FormatException('Unexpected derivation path format: $components');
    }

    final segments = <String>[];

    for (var i = 0; i < components.length; i += 2) {
      final value = components[i];
      final hardened = components[i + 1];

      if (value.value is! int ||
          hardened.value is bool && hardened.value == false ||
          hardened.value is int && hardened.value != 21) {
        throw FormatException('Invalid derivation path component at [$i,$i+1]: $components');
      }

      segments.add(hardened.value ? "$value'" : '$value');
    }

    // 여기서는 "48'/1'/0'/2'" 형태로만 반환 (m/ 붙이는건 상위 로직에서)
    return segments.join('/');
  }

  static Map<String, dynamic> _convertKeysToString(Map<dynamic, dynamic> map) {
    return map.map((key, value) {
      String newKey = key.toString();
      dynamic newValue;
      if (value is Map) {
        newValue = _convertKeysToString(value);
      } else if (value is List) {
        newValue =
            value.map((item) {
              if (item is Map) {
                return _convertKeysToString(item);
              } else {
                return item;
              }
            }).toList();
      } else {
        newValue = value;
      }
      return MapEntry(newKey, newValue);
    });
  }

  static String signerBsmsFromBbQr(dynamic keyInfo) {
    final xpub = keyInfo['p2wsh'];
    final descriptor = keyInfo['p2wsh_desc'];
    final match = RegExp(r'\[[0-9a-fA-F]{8}/[^\]]+\]').firstMatch(descriptor);
    if (match == null) {
      throw const FormatException('Descriptor does not contain a valid [mfp/path] block');
    }
    final bracketContent = match.group(0)!; // [a0f6ba00/48'/1'/0'/2']
    final cleanedBracketContent = bracketContent.substring(1, bracketContent.length - 1);
    final fingerprint = _normalizeFingerprint(cleanedBracketContent.split('/')[0]);
    final derivationPath = _normalizeHardenedPath(cleanedBracketContent.split('/').sublist(1).join('/'));

    return _buildSignerBsms(fingerprint: fingerprint, derivationPath: derivationPath, extendedKey: xpub);
  }

  static String signerBsmsFromKeyInfo(String keyInfo) {
    final matches = RegExp(r'\[([^\]]+)\]([A-Za-z0-9]+)').allMatches(keyInfo);
    if (matches.isEmpty) {
      throw const FormatException('No matches found in text result');
    }
    final bracketContent = matches.first.group(1)!;
    final fingerprint = bracketContent.split('/')[0];
    final derivationPath = bracketContent.split('/').sublist(1).join('/');
    final xpub = matches.first.group(2)!;

    return _buildSignerBsms(
      fingerprint: _normalizeFingerprint(fingerprint),
      derivationPath: _normalizeHardenedPath(derivationPath),
      extendedKey: xpub,
    );
  }

  /// derivation path 표기 차이를 흡수하기 위한 정규화 함수
  /// 예) m/48h/1h/0h/2h/0/1, m/48'/1'/0'/2'/0/1, m/48H/1H/... 등을 동일하게 취급
  static String normalizeDerivationPath(String path) {
    var p = path.trim();
    if (p.isEmpty) return p;

    p = p.replaceAll("'", 'h');
    p = p.replaceAll('H', 'h');

    p = p.replaceAll(RegExp(r'\s+'), '');
    p = p.replaceAll(RegExp(r'/+'), '/');

    if (!p.startsWith('m/')) {
      if (p.startsWith('/')) {
        p = 'm$p';
      } else {
        p = 'm/$p';
      }
    }
    return p;
  }
}
