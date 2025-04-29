import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/descriptor_util.dart';
import 'package:coconut_wallet/utils/third_party_util.dart';
import 'package:flutter/material.dart';

class WalletAddInputViewModel extends ChangeNotifier {
  final WalletImportSource importSource = WalletImportSource.extendedPublicKey;
  final WalletProvider _walletProvider;
  final WalletAddService _walletAddService = WalletAddService();
  String? validExtendedPublicKey;
  String? validDescriptor;

  WalletAddInputViewModel(this._walletProvider);

  bool isExtendedPublicKey(String xpub) {
    try {
      ExtendedPublicKey.parse(xpub);
      validExtendedPublicKey = xpub;
      validDescriptor = null;
      return true;
    } catch (_) {
      validExtendedPublicKey = validDescriptor = null;
      return false;
    }
  }

  bool normalizeDescriptor(String descriptor) {
    try {
      validDescriptor = DescriptorUtil.normalizeDescriptor(descriptor);
      validExtendedPublicKey = null;
      return true;
    } catch (_) {
      validExtendedPublicKey = validDescriptor = null;
      return false;
    }
  }

  bool isValidCharacters(String text) {
    return RegExp(r"^[a-zA-Z0-9#*();<>/'`\[\]]+$").hasMatch(text);
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
    final wallet = _walletAddService.createExtendedPublicKeyWallet(extendedPublicKey, name);
    return await _walletProvider.syncFromThirdparty(importSource, wallet);
  }

  Future<ResultOfSyncFromVault> addWalletFromDescriptor(String descriptor) async {
    final name = getNextThirdPartyWalletName(
        importSource, _walletProvider.walletItemList.map((e) => e.name).toList());
    final wallet = _walletAddService.createWalletFromDescriptor(
        descriptor: descriptor, name: name, walletImportSource: importSource);
    return await _walletProvider.syncFromThirdparty(importSource, wallet);
  }

  String getWalletName(int walletId) {
    return _walletProvider.getWalletById(walletId).name;
  }
}
