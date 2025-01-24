import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/app/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:flutter/cupertino.dart';

class WalletSinglesigInfoViewModel extends ChangeNotifier {
  final int _walletId;
  final AuthProvider _authModel;
  final WalletProvider _walletModel;
  final SharedPrefs _sharedPrefs = SharedPrefs();

  late SinglesigWalletListItem _wallet;
  late SingleSignatureWallet _singlesigWallet;

  WalletSinglesigInfoViewModel(
      this._walletId, this._authModel, this._walletModel) {
    final walletBaseItem = _walletModel.getWalletById(_walletId);
    _wallet = walletBaseItem as SinglesigWalletListItem;
    _singlesigWallet = _wallet.walletBase as SingleSignatureWallet;
  }

  SinglesigWalletListItem get wallet => _wallet;
  SingleSignatureWallet get singlesigWallet => _singlesigWallet;

  WalletInitState get walletInitState => _walletModel.walletInitState;
  bool get isSetPin => _authModel.isSetPin;

  Future<void> deleteWallet() async {
    await _sharedPrefs.removeFaucetHistory(_walletId);
    await _walletModel.deleteWallet(_walletId);
  }
}
