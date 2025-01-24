import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/app/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:flutter/cupertino.dart';

class WalletMultisigInfoViewModel extends ChangeNotifier {
  final int _walletId;
  final AuthProvider _authModel;
  final WalletProvider _walletModel;
  final SharedPrefs _sharedPrefs = SharedPrefs();

  late MultisigWalletListItem _wallet;
  late List<KeyStore> _keystoreList;

  WalletMultisigInfoViewModel(
      this._walletId, this._authModel, this._walletModel) {
    final walletBaseItem = _walletModel.getWalletById(_walletId);
    _wallet = walletBaseItem as MultisigWalletListItem;

    final multisigWallet = _wallet.walletBase as MultisignatureWallet;
    _keystoreList = multisigWallet.keyStoreList;
  }

  MultisigWalletListItem get wallet => _wallet;
  List<KeyStore> get keystoreList => _keystoreList;

  WalletInitState get walletInitState => _walletModel.walletInitState;
  bool get isSetPin => _authModel.isSetPin;

  Future<void> deleteWallet() async {
    await _sharedPrefs.removeFaucetHistory(_walletId);
    await _walletModel.deleteWallet(_walletId);
  }
}
