import 'dart:convert';

import 'package:cbor/simple.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/utils/descriptor_util.dart';
import 'package:coconut_wallet/utils/file_logger.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/type_converter_utils.dart';
import 'package:ur/ur.dart';

/// 스캔된 지갑 정보의 스크립트 타입이
/// Native SegWit(bip84)이 아닌 경우 발생
class UnsupportedWalletTypeException implements Exception {
  final String derivation;
  UnsupportedWalletTypeException(this.derivation);

  @override
  String toString() => 'UnsupportedWalletTypeException: unsupported derivation path ($derivation)';
}

class WalletAddService {
  static const String masterFingerprintPlaceholder = '00000000';

  WatchOnlyWallet createBbQrWallet({
    required Map<String, dynamic> json,
    required String name,
    required WalletImportSource walletImportSource,
  }) {
    return createWalletFromJson(json: json, name: name, walletImportSource: walletImportSource);
  }

  WatchOnlyWallet createExtendedPublicKeyWallet(
    String extendedPublicKey,
    String name,
    String? masterFingerPrint, {
    WalletImportSource walletImportSource = WalletImportSource.extendedPublicKey,
  }) {
    final singleSigWallet = SingleSignatureWallet.fromExtendedPublicKey(
      AddressType.p2wpkh,
      extendedPublicKey,
      masterFingerPrint ?? masterFingerprintPlaceholder,
    );
    return WatchOnlyWallet(name, 0, 0, singleSigWallet.descriptor, null, null, walletImportSource.name);
  }

  WatchOnlyWallet createWalletFromDescriptor({
    required String descriptor,
    required String name,
    WalletImportSource walletImportSource = WalletImportSource.descriptor,
  }) {
    final singleSigWallet = SingleSignatureWallet.fromDescriptor(
      descriptor,
      ignoreChecksum: !DescriptorUtil.hasDescriptorChecksum(descriptor),
    );
    return WatchOnlyWallet(name, 0, 0, singleSigWallet.descriptor, null, null, walletImportSource.name);
  }

  WatchOnlyWallet createWalletFromUrCryptoAccount({
    required UR ur,
    required String name,
    required WalletImportSource walletImportSource,
  }) {
    const className = 'WalletAddService';
    const methodName = 'createWalletFromUrCryptoAccount';

    try {
      final cborBytes = ur.cbor;
      final decodedCbor = cbor.decode(cborBytes); // TODO: cborBytes == decodedCbor (?)
      FileLogger.log(className, methodName, 'cbor.decode completed');
      Map<dynamic, dynamic> cborMap = decodedCbor as Map<dynamic, dynamic>;
      FileLogger.log(className, methodName, 'decodedCbor converted to cborMap');
      Map<String, dynamic> jsonCompatibleMap = convertKeysToString(cborMap);
      FileLogger.log(className, methodName, 'convertKeysToString completed $jsonCompatibleMap');
      final singleSigWallet = SingleSignatureWallet.fromCryptoAccountPayload(jsonCompatibleMap);
      FileLogger.log(className, methodName, 'SingleSignatureWallet.fromCryptoAccountPayload');
      return WatchOnlyWallet(name, 0, 0, singleSigWallet.descriptor, null, null, walletImportSource.name);
    } catch (e, stackTrace) {
      FileLogger.error(className, methodName, 'failed: $e', stackTrace);
      rethrow;
    }
  }

  /// 패스포트는 지갑 정보(JSON)를 UR bytes 타입으로 인코딩하여 전달한다.
  WatchOnlyWallet createWalletFromUrBytes({
    required UR ur,
    required String name,
    required WalletImportSource walletImportSource,
  }) {
    const className = 'WalletAddService';
    const methodName = 'createWalletFromUrBytes';

    try {
      final decodedCbor = cbor.decode(ur.cbor);
      if (decodedCbor is! List<int>) {
        throw 'Unexpected UR bytes payload type: ${decodedCbor.runtimeType}';
      }
      FileLogger.log(className, methodName, 'cbor.decode completed');
      final decodedText = utf8.decode(decodedCbor);
      final json = jsonDecode(decodedText);
      if (json is! Map<String, dynamic>) {
        throw 'Unexpected UR bytes json type: ${json.runtimeType}';
      }
      FileLogger.log(className, methodName, 'jsonDecode completed, keys: ${json.keys.toList()}');
      FileLogger.log(className, methodName, 'raw json: ${jsonEncode(json)}');
      return createWalletFromJson(json: json, name: name, walletImportSource: walletImportSource);
    } catch (e, stackTrace) {
      FileLogger.error(className, methodName, 'failed: $e', stackTrace);
      rethrow;
    }
  }

  WatchOnlyWallet createWalletFromJson({
    required Map<String, dynamic> json,
    required String name,
    required WalletImportSource walletImportSource,
  }) {
    // BBQR 또는 Electrum 포맷 스캔 결과에서 xpub과 fingerprint 추출
    String? xpub;
    String? fingerprint;
    String? descriptor;

    // Coldcard/Sparrow 스타일 BBQR 포맷: {"bip84": {"xpub": ..., "xfp": ..., "desc": ...}}
    if (json['bip84'] != null) {
      final bip84 = json['bip84'];
      xpub = bip84['xpub'];
      final bip84Fingerprint = bip84['xfp'];
      final topLevelFingerprint = json['xfp'];
      if (topLevelFingerprint is String && topLevelFingerprint.isNotEmpty) {
        fingerprint = topLevelFingerprint;
      } else {
        fingerprint = bip84Fingerprint;
      }

      if (bip84['desc'] != null) {
        descriptor = bip84['desc'];
      }
    } else if (json['keystore'] is Map) {
      // Electrum 지갑 파일 포맷 (Passport 등): {"keystore": {"xpub": ..., "derivation": "m/84'/.../...", "ckcc_xfp": ...}}
      final keystore = json['keystore'] as Map;
      final derivation = keystore['derivation'];
      final ckccXfp = keystore['ckcc_xfp'];
      // Native SegWit만 지원하므로 파생 경로가 bip84가 아니면 지원 대상이 아님
      if (derivation is String && derivation.contains("84'")) {
        xpub = keystore['xpub'];
        if (ckccXfp is int) {
          fingerprint = _ckccXfpToFingerprint(ckccXfp);
        }
      } else {
        Logger.error('Unsupported derivation in keystore: $derivation');
        throw UnsupportedWalletTypeException('$derivation');
      }
    }

    if (xpub == null) {
      Logger.error('No bip84 xpub found. Available top-level keys: ${json.keys.toList()}');
      throw Exception('No valid xpub found in BBQR data');
    }

    try {
      if (descriptor != null) {
        final singleSigWallet = SingleSignatureWallet.fromDescriptor(descriptor);
        return WatchOnlyWallet(name, 0, 0, singleSigWallet.descriptor, null, null, walletImportSource.name);
      }
    } catch (e) {
      // descriptor 파싱 실패 시 xpub으로 지갑 생성
      Logger.error('Descriptor parsing failed, using xpub: $e');
    }

    // xpub으로 지갑 생성 (fallback)
    final wallet = createExtendedPublicKeyWallet(xpub, name, fingerprint, walletImportSource: walletImportSource);
    return wallet;
  }

  /// keystore.ckcc_xfp = 마스터 핑거프린트 리틀엔디언
  /// 바이트 순서를 뒤집어 hex 문자열로 변환한다.
  String _ckccXfpToFingerprint(int ckccXfp) {
    final bigEndianHex = ckccXfp.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    final bytes = [
      bigEndianHex.substring(0, 2),
      bigEndianHex.substring(2, 4),
      bigEndianHex.substring(4, 6),
      bigEndianHex.substring(6, 8),
    ];
    return bytes.reversed.join();
  }
}
