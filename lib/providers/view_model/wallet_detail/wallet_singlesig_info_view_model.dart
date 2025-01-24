import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/app/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:flutter/cupertino.dart';

class WalletSinglesigInfoViewModel extends ChangeNotifier {
  final int _walletId;
  final AuthProvider _authProvider;
  final WalletProvider _walletProvider;
  final SharedPrefs _sharedPrefs = SharedPrefs();

  late SinglesigWalletListItem _wallet;
  late SingleSignatureWallet _singlesigWallet;

  WalletSinglesigInfoViewModel(
      this._walletId, this._authProvider, this._walletProvider) {
    final walletBaseItem = _walletProvider.getWalletById(_walletId);
    _wallet = walletBaseItem as SinglesigWalletListItem;
    _singlesigWallet = _wallet.walletBase as SingleSignatureWallet;
  }

  bool get isSetPin => _authProvider.isSetPin;
  SingleSignatureWallet get singlesigWallet => _singlesigWallet;

  SinglesigWalletListItem get wallet => _wallet;
  WalletInitState get walletInitState => _walletProvider.walletInitState;

  Future<void> deleteWallet() async {
    await _sharedPrefs.removeFaucetHistory(_walletId);
    await _walletProvider.deleteWallet(_walletId);
  }
}
