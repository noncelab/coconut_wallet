import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';

class WalletAddInputViewModel extends ChangeNotifier {
  late final WalletProvider _walletProvider;

  WalletAddInputViewModel(this._walletProvider);

  bool isExtendedPublicKey(String xpub) {
    try {
      ExtendedPublicKey.parse(xpub);
      return true;
    } catch (_) {
      return false;
    }
  }
}
