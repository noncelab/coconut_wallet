import 'package:cbor/simple.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/utils/descriptor_util.dart';
import 'package:coconut_wallet/utils/type_converter_utils.dart';
import 'package:ur/ur.dart';

class WalletAddService {
  WatchOnlyWallet createSeedSignerWallet(String descriptor, String name) {
    return createWalletFromDescriptor(
        descriptor: descriptor, name: name, walletImportSource: WalletImportSource.seedSigner);
  }

  WatchOnlyWallet createKeystoneWallet(UR ur, String name) {
    return createWalletFromUR(ur: ur, name: name, walletImportSource: WalletImportSource.keystone);
  }

  WatchOnlyWallet createExtendedPublicKeyWallet(String extendedPublicKey, String name) {
    final singleSigWallet =
        SingleSignatureWallet.fromExtendedPublicKey(AddressType.p2wpkh, extendedPublicKey, '-');
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
}
