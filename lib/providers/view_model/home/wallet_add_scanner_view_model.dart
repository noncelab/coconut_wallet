import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/file_logger.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/third_party_util.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/bb_qr_scan_data_handler.dart';
import 'package:flutter/material.dart';
import 'package:ur/ur.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/bc_ur_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/coconut_wallet_add_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/descriptor_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';

const kMaxStarLenght = 5;
const String className = 'WalletAddScannerViewModel';

class WalletAddScannerViewModel extends ChangeNotifier {
  final WalletImportSource _walletImportSource;
  final WalletProvider _walletProvider;
  final WalletAddService _walletAddService = WalletAddService();
  final PreferenceProvider _preferenceProvider;
  late final IQrScanDataHandler _qrDataHandler;

  WalletAddScannerViewModel(
      this._walletImportSource, this._walletProvider, this._preferenceProvider) {
    const methodName = 'constructor';
    FileLogger.log(
        className, methodName, 'WalletAddScannerViewModel created for ${_walletImportSource.name}');

    switch (_walletImportSource) {
      case WalletImportSource.coconutVault:
        _qrDataHandler = CoconutQrScanDataHandler();
        break;
      case WalletImportSource.keystone:
      case WalletImportSource.jade:
        _qrDataHandler =
            BcUrQrScanDataHandler(expectedUrType: [UrType.cryptoAccount, UrType.accountDescriptor]);
        break;
      case WalletImportSource.seedSigner:
      case WalletImportSource.krux:
        _qrDataHandler = DescriptorQrScanDataHandler();
        break;
      case WalletImportSource.coldCard:
        _qrDataHandler = BbQrScanDataHandler();
        break;
      case WalletImportSource.extendedPublicKey:
        throw 'No Support extendedPublicKey';
      default:
        FileLogger.error(className, methodName, 'No Support extendedPublicKey');
        throw 'wrong wallet import source: $_walletImportSource';
    }
  }

  IQrScanDataHandler get qrDataHandler => _qrDataHandler;
  int? get fakeBalanceTotalAmount => _preferenceProvider.fakeBalanceTotalAmount;

  Future<ResultOfSyncFromVault> addWallet(dynamic additionInfo) async {
    const methodName = 'addWallet';

    FileLogger.log(className, methodName,
        'addWallet called with ${_walletImportSource.name} additionInfo type: ${additionInfo.runtimeType}');

    try {
      switch (_walletImportSource) {
        case WalletImportSource.coconutVault:
          return addCoconutVaultWallet(additionInfo as WatchOnlyWallet);
        case WalletImportSource.keystone:
        case WalletImportSource.jade:
          return _addBcUrWallet(_walletImportSource, additionInfo as UR);
        case WalletImportSource.seedSigner:
        case WalletImportSource.krux:
          return _addDescriptorWallet(_walletImportSource, additionInfo as String);
        case WalletImportSource.coldCard:
          return _addBbQrWallet(_walletImportSource, additionInfo as Map<String, dynamic>);
        case WalletImportSource.extendedPublicKey:
          throw 'No Support extendedPublicKey';
        default:
          FileLogger.error(
              className, methodName, 'wrong wallet import source: $_walletImportSource');
          throw 'wrong wallet import source: $_walletImportSource';
      }
    } catch (e, stackTrace) {
      FileLogger.error(className, methodName, 'addWallet failed: $e', stackTrace);
      rethrow;
    }
  }

  Future<ResultOfSyncFromVault> addCoconutVaultWallet(WatchOnlyWallet watchOnlyWallet) async {
    return await _walletProvider.syncFromCoconutVault(watchOnlyWallet);
  }

  Future<ResultOfSyncFromVault> addKeystoneWallet(UR ur) async {
    const methodName = 'addKeystoneWallet';
    FileLogger.log(className, methodName,
        'addKeystoneWallet called UR type: ${ur.type} cbor length: ${ur.cbor.length}');
    Logger.log('--> ${ur.type} ${ur.cbor.length}');
    Logger.logLongString(ur.cbor.toString());

    try {
      final name = getNextThirdPartyWalletName(
          WalletImportSource.keystone, _walletProvider.walletItemList.map((e) => e.name).toList());
      final wallet = _walletAddService.createKeystoneWallet(ur, name);
      FileLogger.log(className, methodName, 'createKeystoneWallet completed: $name');

      final result = await _walletProvider.syncFromThirdParty(wallet);
      FileLogger.log(className, methodName,
          'syncFromThirdParty completed: ${result.result.name} named: $name');
      return result;
    } catch (e, stackTrace) {
      FileLogger.error(className, methodName, 'addKeystoneWallet failed: $e', stackTrace);
      rethrow;
    }
  }

  Future<ResultOfSyncFromVault> _addBcUrWallet(WalletImportSource walletImportSource, UR ur) async {
    final name = getNextThirdPartyWalletName(
        walletImportSource, _walletProvider.walletItemList.map((e) => e.name).toList());
    final wallet = _walletAddService.createWalletFromUR(
        walletImportSource: walletImportSource, ur: ur, name: name);
    return await _walletProvider.syncFromThirdParty(wallet);
  }

  Future<ResultOfSyncFromVault> _addDescriptorWallet(
      WalletImportSource walletImportSource, String descriptor) async {
    final name = getNextThirdPartyWalletName(
        walletImportSource, _walletProvider.walletItemList.map((e) => e.name).toList());
    final wallet = _walletAddService.createWalletFromDescriptor(
        walletImportSource: walletImportSource, descriptor: descriptor, name: name);
    return await _walletProvider.syncFromThirdParty(wallet);
  }

  Future<ResultOfSyncFromVault> _addBbQrWallet(
      WalletImportSource walletImportSource, Map<String, dynamic> json) async {
    final name = getNextThirdPartyWalletName(
        walletImportSource, _walletProvider.walletItemList.map((e) => e.name).toList());
    final wallet = _walletAddService.createBbQrWallet(
        walletImportSource: walletImportSource, json: json, name: name);
    return await _walletProvider.syncFromThirdParty(wallet);
  }

  String getWalletName(int walletId) {
    return _walletProvider.getWalletById(walletId).name;
  }
}
