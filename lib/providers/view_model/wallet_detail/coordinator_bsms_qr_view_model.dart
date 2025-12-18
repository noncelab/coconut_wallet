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

    // Import Detail JSON 생성 (지갑 동기화용)
    Map<String, String> namesMap = {};

    // 파싱된 Fingerprint와 기존 signers 리스트의 이름을 매핑
    // (순서가 보장되지 않을 수 있으므로, 기존 로직이 Fingerprint를 알 수 없다면
    //  단순히 인덱스 기반으로 매칭하거나 이름을 생략합니다.
    //  여기서는 Fingerprint를 키로 사용해야 하므로, parsedSigners를 기준으로 합니다.)

    // 만약 MultisigSigner 모델 안에 fingerprint 정보가 전혀 없다면 이름 매칭이 어렵지만,
    // 보통 지갑 생성 순서대로 signers 리스트가 유지된다고 가정하고 인덱스로 매칭 시도합니다.
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

    // 7. 데이터 맵 할당
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

  // --- [핵심] Descriptor 파싱 로직 ---

  // Descriptor 문자열에서 [fingerprint/path]xpub 정보를 정규식으로 추출
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

        // Path 변환:
        // 1. h -> ' 로 변경 (Display용)
        // 2. m 접두사 확인
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
    // 이미 BSMS 헤더가 있는지 확인
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

    String safeName = wallet.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-');
    if (safeName.isEmpty) safeName = "Multisig";
    buffer.writeln("Name: $safeName");
    buffer.writeln("Policy: ${wallet.requiredSignatureCount} of ${signers.length}");

    // 첫 번째 서명자의 경로 사용 (없으면 기본값)
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
    String safeName = wallet.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    if (safeName.isEmpty) safeName = "Multisig";
    if (safeName.length > 20) safeName = safeName.substring(0, 20);
    buffer.writeln("Name: $safeName");

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

// 추출된 서명자 정보를 담을 간단한 내부 클래스
class _ParsedSignerInfo {
  final String fingerprint;
  final String path;
  final String xpub;

  _ParsedSignerInfo({required this.fingerprint, required this.path, required this.xpub});
}
