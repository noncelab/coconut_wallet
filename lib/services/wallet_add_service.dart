import 'package:cbor/simple.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/utils/descriptor_util.dart';
import 'package:coconut_wallet/utils/type_converter_utils.dart';
import 'package:ur/ur.dart';

class WalletAddService {
  static const String masterFingerprintPlaceholder = '00000000';
  WatchOnlyWallet createSeedSignerWallet(String descriptor, String name) {
    return createWalletFromDescriptor(
        descriptor: descriptor, name: name, walletImportSource: WalletImportSource.seedSigner);
  }

  WatchOnlyWallet createKeystoneWallet(UR ur, String name) {
    return createWalletFromUR(ur: ur, name: name, walletImportSource: WalletImportSource.keystone);
  }

  WatchOnlyWallet createJadeWallet(UR ur, String name) {
    return createWalletFromUR(ur: ur, name: name, walletImportSource: WalletImportSource.jade);
  }

  WatchOnlyWallet createColdCardWallet(Map<String, dynamic> json, String name) {
    return createWalletFromJson(
        json: json, name: name, walletImportSource: WalletImportSource.coldCard);
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
    final cborBytes = ur.cbor;
    final decodedCbor = cbor.decode(cborBytes); // TODO: cborBytes == decodedCbor (?)
    Map<dynamic, dynamic> cborMap = decodedCbor as Map<dynamic, dynamic>;
    Map<String, dynamic> jsonCompatibleMap = convertKeysToString(cborMap);
    final singleSigWallet = SingleSignatureWallet.fromCryptoAccountPayload(jsonCompatibleMap);
    return WatchOnlyWallet(
        name, 0, 0, singleSigWallet.descriptor, null, null, walletImportSource.name);
  }

  WatchOnlyWallet createWalletFromJson(
      {required Map<String, dynamic> json,
      required String name,
      required WalletImportSource walletImportSource}) {
    // BBQR 스캔 결과에서 xpub과 fingerprint 추출
    String? xpub;
    String? fingerprint;

    // bip84 (native segwit) 우선 사용
    if (json['bip84'] != null) {
      xpub = json['bip84']['xpub'];
      fingerprint = json['bip84']['xfp'];
    }
    // bip49 (segwit)  사용
    else if (json['bip49'] != null) {
      xpub = json['bip49']['xpub'];
      fingerprint = json['bip49']['xfp'];
    }
    // bip49가 없으면 bip44 사용
    else if (json['bip44'] != null) {
      xpub = json['bip44']['xpub'];
      fingerprint = json['bip44']['xfp'];
    }
    // bip84 (native segwit) 사용
    if (json['bip84'] != null) {
      xpub = json['bip84']['xpub'];
      fingerprint = json['bip84']['xfp'];
    }

    if (xpub == null) {
      throw Exception('No valid xpub found in BBQR data');
    }

    try {
      // descriptor로 지갑 생성 시도
      String? descriptor;
      if (json['bip84'] != null && json['bip84']['desc'] != null) {
        descriptor = json['bip84']['desc'];
      } else if (json['bip49'] != null && json['bip49']['desc'] != null) {
        descriptor = json['bip49']['desc'];
      } else if (json['bip44'] != null && json['bip44']['desc'] != null) {
        descriptor = json['bip44']['desc'];
      }

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
      print('Descriptor parsing failed, using xpub: $e');
    }

    // xpub으로 지갑 생성 (fallback)
    return createExtendedPublicKeyWallet(xpub, name, fingerprint);
  }
}
