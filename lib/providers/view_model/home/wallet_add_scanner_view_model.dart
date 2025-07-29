import 'dart:math';

import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/third_party_util.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/bb_qr_scan_data_handler.dart';
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
  final PreferenceProvider _preferenceProvider;
  late final IQrScanDataHandler _qrDataHandler;

  WalletAddScannerViewModel(
      this._walletImportSource, this._walletProvider, this._preferenceProvider) {
    switch (_walletImportSource) {
      case WalletImportSource.coconutVault:
        _qrDataHandler = CoconutQrScanDataHandler();
        break;
      case WalletImportSource.keystone:
      case WalletImportSource.jade:
        _qrDataHandler = BcUrQrScanDataHandler();
        break;
      case WalletImportSource.seedSigner:
        _qrDataHandler = DescriptorQrScanDataHandler();
        break;
      case WalletImportSource.coldCard:
        _qrDataHandler = BbQrScanDataHandler();
        break;
      case WalletImportSource.extendedPublicKey:
        throw 'No Support extendedPublicKey';
      default:
        throw 'wrong wallet import source: $_walletImportSource';
    }
  }

  IQrScanDataHandler get qrDataHandler => _qrDataHandler;
  int? get fakeBalanceTotalAmount => _preferenceProvider.fakeBalanceTotalAmount;

  Future<ResultOfSyncFromVault> addWallet(dynamic additionInfo) async {
    switch (_walletImportSource) {
      case WalletImportSource.coconutVault:
        return addCoconutVaultWallet(additionInfo as WatchOnlyWallet);
      case WalletImportSource.keystone:
        return addKeystoneWallet(additionInfo as UR);
      case WalletImportSource.jade:
        return addJadeWallet(additionInfo as UR);
      case WalletImportSource.seedSigner:
        return addSeedSignerWallet(additionInfo as String);
      case WalletImportSource.coldCard:
        return addColdCardWallet(additionInfo as Map<String, dynamic>);
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

  Future<ResultOfSyncFromVault> addJadeWallet(UR ur) async {
    final name = getNextThirdPartyWalletName(
        WalletImportSource.jade, _walletProvider.walletItemList.map((e) => e.name).toList());
    final wallet = _walletAddService.createJadeWallet(ur, name);
    return await _walletProvider.syncFromThirdParty(wallet);
  }

  Future<ResultOfSyncFromVault> addSeedSignerWallet(String descriptor) async {
    final name = getNextThirdPartyWalletName(
        WalletImportSource.seedSigner, _walletProvider.walletItemList.map((e) => e.name).toList());
    final wallet = _walletAddService.createSeedSignerWallet(descriptor, name);
    return await _walletProvider.syncFromThirdParty(wallet);
  }

  Future<ResultOfSyncFromVault> addColdCardWallet(Map<String, dynamic> json) async {
    final name = getNextThirdPartyWalletName(
        WalletImportSource.coldCard, _walletProvider.walletItemList.map((e) => e.name).toList());
    final wallet = _walletAddService.createColdCardWallet(json, name);
    return await _walletProvider.syncFromThirdParty(wallet);
  }

  String getWalletName(int walletId) {
    return _walletProvider.getWalletById(walletId).name;
  }

  Future<void> setFakeBalanceIfEnabled(int? walletId) async {
    if (fakeBalanceTotalAmount == null || walletId == null) return;

    // 가짜 잔액이 설정되어 있는 경우 FakeBalanceTotalAmount 이하의 값 랜덤 배정
    final randomFakeBalance = (Random().nextDouble() * fakeBalanceTotalAmount! + 1).toInt();

    await _preferenceProvider.setFakeBalance(walletId, randomFakeBalance);
  }
}
