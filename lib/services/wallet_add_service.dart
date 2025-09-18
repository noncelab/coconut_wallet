import 'package:cbor/simple.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/utils/descriptor_util.dart';
import 'package:coconut_wallet/utils/file_logger.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/type_converter_utils.dart';
import 'package:ur/ur.dart';

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
      String extendedPublicKey, String name, String? masterFingerPrint) {
    final singleSigWallet = SingleSignatureWallet.fromExtendedPublicKey(
        AddressType.p2wpkh, extendedPublicKey, masterFingerPrint ?? masterFingerprintPlaceholder);
    return WatchOnlyWallet(name, 0, 0, singleSigWallet.descriptor, null, null,
        WalletImportSource.extendedPublicKey.name);
  }

  WatchOnlyWallet createWalletFromDescriptor(
      {required String descriptor,
      required String name,
      required WalletImportSource walletImportSource}) {
    final singleSigWallet = SingleSignatureWallet.fromDescriptor(descriptor,
        ignoreChecksum: !DescriptorUtil.hasDescriptorChecksum(descriptor));
    return WatchOnlyWallet(
        name, 0, 0, singleSigWallet.descriptor, null, null, walletImportSource.name);
  }

  WatchOnlyWallet createWalletFromUR(
      {required UR ur, required String name, required WalletImportSource walletImportSource}) {
    const className = 'WalletAddService';
    const methodName = 'createWalletFromUR';

    try {
      final cborBytes = ur.cbor;
      for (int i = 0; i < cborBytes.length; i++) {
        Logger.logLongString('cborBytes[$i]: ${cborBytes[i]}');
      }
      final decodedCbor = cbor.decode(cborBytes); // TODO: cborBytes == decodedCbor (?)
      FileLogger.log(className, methodName, 'cbor.decode completed');
      Map<dynamic, dynamic> cborMap = decodedCbor as Map<dynamic, dynamic>;
      FileLogger.log(className, methodName, 'decodedCbor converted to cborMap');
      Logger.log('------------- cborMap -------------');
      Logger.logMapRecursive(cborMap);
      Logger.log('------------- jsonCompatibleMap -------------');
      Map<String, dynamic> jsonCompatibleMap = convertKeysToString(cborMap);
      FileLogger.log(className, methodName, 'convertKeysToString completed $jsonCompatibleMap');
      final singleSigWallet = SingleSignatureWallet.fromCryptoAccountPayload(jsonCompatibleMap);
      FileLogger.log(className, methodName, 'SingleSignatureWallet.fromCryptoAccountPayload');
      return WatchOnlyWallet(
          name, 0, 0, singleSigWallet.descriptor, null, null, walletImportSource.name);
    } catch (e, stackTrace) {
      FileLogger.error(className, methodName, 'failed: $e', stackTrace);
      rethrow;
    }
  }

  WatchOnlyWallet createWalletFromJson(
      {required Map<String, dynamic> json,
      required String name,
      required WalletImportSource walletImportSource}) {
    // BBQR 스캔 결과에서 xpub과 fingerprint 추출
    String? xpub;
    String? fingerprint;
    String? descriptor;

    // bip84 (native segwit)
    if (json['bip84'] != null) {
      xpub = json['bip84']['xpub'];
      fingerprint = json['bip84']['xfp'];

      if (json['bip84']['desc'] != null) {
        descriptor = json['bip84']['desc'];
      }
    }

    if (xpub == null) {
      throw Exception('No valid xpub found in BBQR data');
    }

    try {
      if (descriptor != null) {
        final singleSigWallet = SingleSignatureWallet.fromDescriptor(descriptor);
        return WatchOnlyWallet(
          name,
          0,
          0,
          singleSigWallet.descriptor,
          null,
          null,
          walletImportSource.name,
        );
      }
    } catch (e) {
      // descriptor 파싱 실패 시 xpub으로 지갑 생성
      Logger.error('Descriptor parsing failed, using xpub: $e');
    }

    // xpub으로 지갑 생성 (fallback)
    return createExtendedPublicKeyWallet(xpub, name, fingerprint);
  }
}
