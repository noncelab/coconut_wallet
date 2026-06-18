import 'dart:convert';

import 'package:coconut_wallet/model/wallet/taproot_wallet_list_item.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';

class TaprootWalletBackupViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;
  final int _walletId;

  TaprootWalletBackupViewModel(this._walletProvider, this._walletId);

  Map<String, String> get walletQrDataMap {
    final wallet = _walletProvider.getWalletById(_walletId);
    if (wallet is! TaprootWalletListItem) return {};

    final Map<String, dynamic> backupMap = {
      'name': wallet.name,
      'descriptor': wallet.descriptor,
      'colorIndex': wallet.colorIndex,
      'iconIndex': wallet.iconIndex,
      'keyPathSeedInfos': wallet.keyPathSeedInfos,
      'scriptPathSeedInfos': wallet.scriptPathSeedInfos.map((e) => e.toJson()).toList(),
      'createdAt': wallet.createdAtInVault?.toIso8601String(),
    };

    return {'Wallet Info': jsonEncode(backupMap)};
  }

  Map<String, String> get walletTextDataMap => walletQrDataMap;
}
