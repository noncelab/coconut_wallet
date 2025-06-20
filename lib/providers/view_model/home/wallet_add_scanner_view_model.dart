import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/third_party_util.dart';
import 'package:flutter/material.dart';
import 'package:ur/ur.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/bc_ur_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/coconut_wallet_add_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/descriptor_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';

class WalletAddScannerViewModel extends ChangeNotifier {
  final WalletImportSource _walletImportSource;
  final WalletProvider _walletProvider;
  final WalletAddService _walletAddService = WalletAddService();
  final NodeProvider _nodeProvider;
  late final IQrScanDataHandler _qrDataHandler;

  WalletAddScannerViewModel(this._walletImportSource, this._walletProvider, this._nodeProvider) {
    switch (_walletImportSource) {
      case WalletImportSource.coconutVault:
        _qrDataHandler = CoconutQrScanDataHandler();
        break;
      case WalletImportSource.keystone:
        _qrDataHandler = BcUrQrScanDataHandler();
        break;
      case WalletImportSource.seedSigner:
        _qrDataHandler = DescriptorQrScanDataHandler();
        break;
      case WalletImportSource.extendedPublicKey:
        throw 'No Support extendedPublicKey';
      default:
        throw 'wrong wallet import source: $_walletImportSource';
    }
  }

  IQrScanDataHandler get qrDataHandler => _qrDataHandler;

  Future<ResultOfSyncFromVault> addWallet(dynamic additionInfo) async {
    ResultOfSyncFromVault result;
    switch (_walletImportSource) {
      case WalletImportSource.coconutVault:
        result = await addCoconutVaultWallet(additionInfo as WatchOnlyWallet);
      case WalletImportSource.keystone:
        result = await addKeystoneWallet(additionInfo as UR);
      case WalletImportSource.seedSigner:
        result = await addSeedSignerWallet(additionInfo as String);
      case WalletImportSource.extendedPublicKey:
        throw 'No Support extendedPublicKey';
      default:
        throw 'wrong wallet import source: $_walletImportSource';
    }

    if (result.result == WalletSyncResult.newWalletAdded) {
      final wallet =
          _walletProvider.walletItemList.firstWhere((element) => element.id == result.walletId);
      _nodeProvider.subscribeWallet(wallet);
    }
    return result;
  }

  Future<ResultOfSyncFromVault> addCoconutVaultWallet(WatchOnlyWallet watchOnlyWallet) async {
    return await _walletProvider.syncFromCoconutVault(watchOnlyWallet);
  }

  Future<ResultOfSyncFromVault> addKeystoneWallet(UR ur) async {
    final name = getNextThirdPartyWalletName(
        WalletImportSource.keystone, _walletProvider.walletItemList.map((e) => e.name).toList());
    final wallet = _walletAddService.createKeystoneWallet(ur, name);
    return await _walletProvider.syncFromThirdParty(wallet);
  }

  Future<ResultOfSyncFromVault> addSeedSignerWallet(String descriptor) async {
    final name = getNextThirdPartyWalletName(
        WalletImportSource.seedSigner, _walletProvider.walletItemList.map((e) => e.name).toList());
    final wallet = _walletAddService.createSeedSignerWallet(descriptor, name);
    return await _walletProvider.syncFromThirdParty(wallet);
  }

  String getWalletName(int walletId) {
    return _walletProvider.getWalletById(walletId).name;
  }
}
