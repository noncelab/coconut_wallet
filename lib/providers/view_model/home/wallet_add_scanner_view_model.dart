import 'package:cbor/simple.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/descriptor_util.dart';
import 'package:coconut_wallet/utils/third_party_util.dart';
import 'package:coconut_wallet/utils/type_converter_utils.dart';
import 'package:coconut_wallet/widgets/animated_qr/bc_ur_qr_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/coconut_qr_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/descriptor_qr_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/i_coconut_qr_data_handler.dart';
import 'package:flutter/material.dart';
import 'package:ur/ur.dart';

class WalletAddScannerViewModel extends ChangeNotifier {
  final WalletImportSource _walletImportSource;
  final WalletProvider _walletProvider;
  late final ICoconutQrDataHandler _qrDataHandler;

  WalletAddScannerViewModel(this._walletImportSource, this._walletProvider) {
    switch (_walletImportSource) {
      case WalletImportSource.coconutVault:
        _qrDataHandler = CoconutQRDataHandler();
        break;
      case WalletImportSource.keystone:
        _qrDataHandler = BcUrQrDataHandler();
        break;
      case WalletImportSource.seedSigner:
        _qrDataHandler = DescriptorQRDataHandler();
        break;
      case WalletImportSource.extendedPublicKey:
        throw 'No Support extendedPublicKey';
      default:
        throw 'wrong wallet import source: $_walletImportSource';
    }
  }

  ICoconutQrDataHandler get qrDataHandler => _qrDataHandler;

  Future<ResultOfSyncFromVault> addWallet(dynamic additionInfo) async {
    switch (_walletImportSource) {
      case WalletImportSource.coconutVault:
        return addCoconutVaultWallet(additionInfo as WatchOnlyWallet);
      case WalletImportSource.keystone:
        return addKeystoneWallet(additionInfo as UR);
      case WalletImportSource.seedSigner:
        return addSeedSignerWallet(additionInfo as String);
      case WalletImportSource.extendedPublicKey:
        throw 'No Support extendedPublicKey';
      default:
        throw 'wrong wallet import source: $_walletImportSource';
    }
  }

  Future<ResultOfSyncFromVault> addCoconutVaultWallet(WatchOnlyWallet watchOnlyWallet) async {
    return await _walletProvider.syncFromVault(watchOnlyWallet);
  }

  Future<ResultOfSyncFromVault> addKeystoneWallet(UR ur) async {
    final cborBytes = ur.cbor;
    final decodedCbor = cbor.decode(cborBytes); // TODO: cborBytes랑 decodedCbor 값이 같은 것으로 보임
    Map<dynamic, dynamic> cborMap = decodedCbor as Map<dynamic, dynamic>;
    Map<String, dynamic> jsonCompatibleMap = convertKeysToString(cborMap);
    final singleSigWallet = SingleSignatureWallet.fromCryptoAccountPayload(jsonCompatibleMap);
    // TODO: icon, color, name
    final watchOnlyWallet = WatchOnlyWallet(
        getNextThirdPartyWalletName(WalletImportSource.keystone,
            _walletProvider.walletItemList.map((e) => e.name).toList()),
        9,
        9,
        singleSigWallet.descriptor,
        null,
        null);
    return await _walletProvider.syncFromThirdparty(WalletImportSource.keystone, watchOnlyWallet);
  }

  Future<ResultOfSyncFromVault> addSeedSignerWallet(String descriptor) async {
    final singleSigWallet = SingleSignatureWallet.fromDescriptor(descriptor,
        ignoreChecksum: !DescriptorUtil.hasDescriptorChecksum(descriptor));
    // TODO: icon, color, name
    final watchOnlyWallet = WatchOnlyWallet(
        getNextThirdPartyWalletName(WalletImportSource.seedSigner,
            _walletProvider.walletItemList.map((e) => e.name).toList()),
        9,
        9,
        singleSigWallet.descriptor,
        null,
        null);
    return await _walletProvider.syncFromThirdparty(WalletImportSource.seedSigner, watchOnlyWallet);
  }

  String getWalletName(int walletId) {
    return _walletProvider.getWalletById(walletId).name;
  }
}
