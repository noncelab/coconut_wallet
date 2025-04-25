import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/third_party_util.dart';
import 'package:flutter/material.dart';
import 'package:ur/ur.dart';
import 'package:coconut_wallet/widgets/animated_qr/bc_ur_qr_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/coconut_qr_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/descriptor_qr_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/i_coconut_qr_data_handler.dart';

class WalletAddScannerViewModel extends ChangeNotifier {
  final WalletImportSource _walletImportSource;
  final WalletProvider _walletProvider;
  final WalletAddService _walletAddService = WalletAddService();
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
