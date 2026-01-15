import 'dart:convert';
import 'dart:typed_data';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/packages/bc-ur-dart/lib/cbor_lite.dart';
import 'package:ur/ur.dart';
import 'package:coconut_wallet/packages/bc-ur-dart/lib/ur_encoder.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/bb_qr/bb_qr_encoder.dart';
import 'package:flutter/material.dart';

class CoordinatorBsmsQrViewModel extends ChangeNotifier {
  late String qrData;
  late Map<String, String> walletQrDataMap;
  late Map<String, String> walletTextDataMap;

  CoordinatorBsmsQrViewModel(WalletProvider walletProvider, int id) {
    _init(walletProvider, id);
  }

  void _init(WalletProvider walletProvider, int id) {
    final walletListItem = walletProvider.getWalletById(id) as MultisigWalletListItem;

    String descriptor = walletListItem.descriptor;

    String bsmsText = _generateBsmsTextFormat(descriptor);
    List<_ParsedSignerInfo> parsedSigners = _parseSignersFromDescriptor(descriptor);

    // 각 하드웨어 월렛 포맷 텍스트 생성
    String coldcardText = _generateColdcardTextFormat(walletListItem, parsedSigners);
    String keystoneText = _generateKeystoneTextFormat(walletListItem, parsedSigners);
    String blueWalletText = _generateBlueWalletFormat(walletListItem, parsedSigners);
    String specterText = _generateSpecterFormat(walletListItem, descriptor);

    // QR 인코딩
    String bsmsUr = _encodeToUrBytes(bsmsText);
    String keystoneUr = _encodeToUrBytes(keystoneText);
    String coldcardQr = _encodeColdcardQr(coldcardText);

    Map<String, String> namesMap = {};

    for (int i = 0; i < parsedSigners.length; i++) {
      if (i < walletListItem.signers.length) {
        final signerName = walletListItem.signers[i].name;
        if (signerName != null && signerName.isNotEmpty) {
          namesMap[parsedSigners[i].fingerprint] = signerName;
        }
      }
    }

    Map<String, dynamic> importDetailMap = {
      'name': walletListItem.name,
      'colorIndex': walletListItem.colorIndex,
      'iconIndex': walletListItem.iconIndex,
      'namesMap': namesMap,
      'coordinatorBsms': bsmsText,
    };
    qrData = jsonEncode(importDetailMap);

    walletQrDataMap = {
      'BSMS': bsmsUr,
      'BlueWallet Vault Multisig': blueWalletText,
      'Coldcard Multisig': coldcardQr,
      'Keystone Multisig': keystoneUr,
      'Output Descriptor': descriptor,
      'Specter Desktop': specterText,
    };

    walletTextDataMap = {
      'BSMS': bsmsText,
      'BlueWallet Vault Multisig': blueWalletText,
      'Coldcard Multisig': coldcardText,
      'Keystone Multisig': keystoneText,
      'Output Descriptor': descriptor,
      'Specter Desktop': specterText,
    };

    notifyListeners();
  }

  // --- Descriptor 파싱 로직 ---

  List<_ParsedSignerInfo> _parseSignersFromDescriptor(String descriptor) {
    List<_ParsedSignerInfo> results = [];

    // Regex 패턴 설명:
    // \[             : '[' 시작
    // ([0-9a-fA-F]{8}) : 그룹1 - Fingerprint (8자리 16진수)
    // ([^\]]+)       : 그룹2 - Derivation Path (']' 전까지의 문자열, 예: /48h/0h/0h/2h)
    // \]             : ']' 끝
    // ([a-zA-Z0-9]+) : 그룹3 - Xpub (알파벳+숫자)
    final RegExp regex = RegExp(r'\[([0-9a-fA-F]{8})([^\]]+)\]([a-zA-Z0-9]+)');

    final matches = regex.allMatches(descriptor);

    for (final match in matches) {
      if (match.groupCount >= 3) {
        String fingerprint = match.group(1) ?? "";
        String rawPath = match.group(2) ?? "";
        String xpub = match.group(3) ?? "";

        String normalizedPath = rawPath.replaceAll('h', "'");
        if (!normalizedPath.startsWith('/') && !normalizedPath.startsWith('m')) {
          normalizedPath = "/$normalizedPath";
        }

        String fullPath = normalizedPath.startsWith('m') ? normalizedPath : "m$normalizedPath";

        results.add(_ParsedSignerInfo(fingerprint: fingerprint.toUpperCase(), path: fullPath, xpub: xpub));
      }
    }
    return results;
  }

  // --- Encoders ---

  String _encodeToUrBytes(String text) {
    try {
      Uint8List utf8Data = Uint8List.fromList(utf8.encode(text));
      final cborEncoder = CBOREncoder();
      cborEncoder.encodeBytes(utf8Data);
      final ur = UR('bytes', cborEncoder.getBytes());
      final urEncoder = UREncoder(ur, 2000);
      return urEncoder.nextPart();
    } catch (e) {
      return "Error encoding UR: $e";
    }
  }

  String _encodeColdcardQr(String text) {
    try {
      return BbQrEncoder.encode(data: text, encodingType: 'Z').first;
    } catch (e) {
      return "Error: $e";
    }
  }

  // --- Generators ---

  String _generateBsmsTextFormat(String descriptor) {
    if (descriptor.trim().startsWith("BSMS")) return descriptor;

    StringBuffer buffer = StringBuffer();
    buffer.writeln("BSMS 1.0");
    buffer.writeln(descriptor);
    return buffer.toString();
  }

  String _generateKeystoneTextFormat(MultisigWalletListItem wallet, List<_ParsedSignerInfo> signers) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln("# Keystone Multisig setup file (created by Coconut Vault)");
    buffer.writeln("#\n");
    buffer.writeln("Name: coconut wallet");
    buffer.writeln("Policy: ${wallet.requiredSignatureCount} of ${signers.length}");

    String derivation = signers.isNotEmpty ? signers.first.path : "m/48'/0'/0'/2'";
    buffer.writeln("Derivation: $derivation");
    buffer.writeln("Format: P2WSH\n");

    for (var signer in signers) {
      buffer.writeln("${signer.fingerprint}: ${signer.xpub}");
    }

    return buffer.toString();
  }

  String _generateColdcardTextFormat(MultisigWalletListItem wallet, List<_ParsedSignerInfo> signers) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln("Name: coconut wallet");
    buffer.writeln("Policy: ${wallet.requiredSignatureCount} of ${signers.length}");
    buffer.writeln("Format: P2WSH");

    String derivation = signers.isNotEmpty ? signers.first.path : "m/48'/0'/0'/2'";
    buffer.writeln("Derivation: $derivation");

    for (var signer in signers) {
      buffer.writeln("${signer.fingerprint}: ${signer.xpub}");
    }

    return buffer.toString().trim();
  }

  String _generateBlueWalletFormat(MultisigWalletListItem wallet, List<_ParsedSignerInfo> signers) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln("# Blue Wallet Vault Multisig setup file (created by Coconut Vault)\n#");
    buffer.writeln("Name: ${wallet.name}");
    buffer.writeln("Policy: ${wallet.requiredSignatureCount} of ${signers.length}");

    String derivation = signers.isNotEmpty ? signers.first.path : "m/48'/0'/0'/2'";
    buffer.writeln("Derivation: $derivation");

    buffer.writeln("Format: P2WSH\n");
    for (var signer in signers) {
      buffer.writeln("${signer.fingerprint}: ${signer.xpub}");
    }
    return buffer.toString();
  }

  String _generateSpecterFormat(MultisigWalletListItem wallet, String descriptor) {
    final Map<String, dynamic> data = {"label": wallet.name, "blockheight": 0, "descriptor": descriptor};
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }
}

class _ParsedSignerInfo {
  final String fingerprint;
  final String path;
  final String xpub;

  _ParsedSignerInfo({required this.fingerprint, required this.path, required this.xpub});
}
