import 'dart:math';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/descriptor_util.dart';
import 'package:coconut_wallet/utils/third_party_util.dart';
import 'package:flutter/material.dart';

class WalletAddInputViewModel extends ChangeNotifier {
  final WalletImportSource importSource = WalletImportSource.extendedPublicKey;
  final WalletProvider _walletProvider;
  final WalletAddService _walletAddService = WalletAddService();
  final PreferenceProvider _preferenceProvider;
  String? validExtendedPublicKey;
  String? validDescriptor;
  String? errorMessage;
  String? masterFingerPrint;

  WalletAddInputViewModel(this._walletProvider, this._preferenceProvider);
  int? get fakeBalanceTotalAmount => _preferenceProvider.fakeBalanceTotalAmount;
  bool isExtendedPublicKey(String xpub) {
    try {
      _validateXpubPrefixSupport(xpub);
      SingleSignatureWallet.fromExtendedPublicKey(
          AddressType.p2wpkh, xpub, WalletAddService.masterFingerprintPlaceholder);
      validExtendedPublicKey = xpub;
      validDescriptor = null;
      return true;
    } catch (e) {
      validExtendedPublicKey = validDescriptor = null;
      _setErrorMessageByError(e);
      return false;
    }
  }

  bool normalizeDescriptor(String descriptor) {
    try {
      validDescriptor = DescriptorUtil.normalizeDescriptor(descriptor);
      validExtendedPublicKey = null;
      return true;
    } catch (e) {
      validExtendedPublicKey = validDescriptor = null;
      _setErrorMessageByError(e);
      return false;
    }
  }

  bool isValidCharacters(String text) {
    bool isValid = RegExp(r"^[a-zA-Z0-9#*();<>/'`\[\]]+$").hasMatch(text);
    if (!isValid) {
      errorMessage = t.wallet_add_input_screen.invalid_character_error_text;
      notifyListeners();
    }
    return isValid;
  }

  void _validateXpubPrefixSupport(String xpub) {
    final allowedPrefixes = ["vpub", "tpub", "xpub", "zpub"];
    final prefix = xpub.substring(0, 4).toLowerCase();

    if (!allowedPrefixes.contains(prefix)) {
      throw Exception("[${NetworkType.currentNetworkType}] '$prefix' is not supported.");
    }
  }

  void _setErrorMessageByError(e) {
    if (e.toString().contains("network type")) {
      errorMessage = NetworkType.currentNetworkType == NetworkType.mainnet
          ? t.wallet_add_input_screen.mainnet_wallet_error_text
          : t.wallet_add_input_screen.testnet_wallet_error_text;
    } else if (e.toString().contains("not supported")) {
      errorMessage = t.wallet_add_input_screen.unsupported_wallet_error_text;
    } else {
      errorMessage = "${t.wallet_add_input_screen.format_error_text}\n${e.toString()}";
    }
    notifyListeners();
  }

  Future<void> setFakeBalanceIfEnabled(int? walletId) async {
    if (fakeBalanceTotalAmount == null || walletId == null) return;

    // 가짜 잔액이 설정되어 있는 경우 FakeBalanceTotalAmount 이하의 값 랜덤 배정
    final randomFakeBalance = (Random().nextDouble() * fakeBalanceTotalAmount! + 1).toInt();

    await _preferenceProvider.setFakeBalance(walletId, randomFakeBalance);
  }

  Future<ResultOfSyncFromVault> addWallet() async {
    assert(validExtendedPublicKey != null || validDescriptor != null);
    if (validExtendedPublicKey != null) {
      return await addWalletFromExtendedPublicKey(validExtendedPublicKey!);
    }

    return await addWalletFromDescriptor(validDescriptor!);
  }

  Future<ResultOfSyncFromVault> addWalletFromExtendedPublicKey(String extendedPublicKey) async {
    final name = getNextThirdPartyWalletName(
        importSource, _walletProvider.walletItemList.map((e) => e.name).toList());
    final wallet =
        _walletAddService.createExtendedPublicKeyWallet(extendedPublicKey, name, masterFingerPrint);
    return await _walletProvider.syncFromThirdParty(wallet);
  }

  Future<ResultOfSyncFromVault> addWalletFromDescriptor(String descriptor) async {
    final name = getNextThirdPartyWalletName(
        importSource, _walletProvider.walletItemList.map((e) => e.name).toList());
    final wallet = _walletAddService.createWalletFromDescriptor(
        descriptor: descriptor, name: name, walletImportSource: importSource);
    return await _walletProvider.syncFromThirdParty(wallet);
  }

  String getWalletName(int walletId) {
    return _walletProvider.getWalletById(walletId).name;
  }
}
