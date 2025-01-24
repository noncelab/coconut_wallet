import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/app/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:flutter/cupertino.dart';

class WalletMultisigInfoViewModel extends ChangeNotifier {
  final int _walletId;
  final AuthProvider _authProvider;
  final WalletProvider _walletProvider;
  final SharedPrefs _sharedPrefs = SharedPrefs();

  late MultisigWalletListItem _wallet;
  late List<KeyStore> _keystoreList;

  WalletMultisigInfoViewModel(
      this._walletId, this._authProvider, this._walletProvider) {
    final walletBaseItem = _walletProvider.getWalletById(_walletId);
    _wallet = walletBaseItem as MultisigWalletListItem;

    final multisigWallet = _wallet.walletBase as MultisignatureWallet;
    _keystoreList = multisigWallet.keyStoreList;
  }

  bool get isSetPin => _authProvider.isSetPin;
  List<KeyStore> get keystoreList => _keystoreList;

  MultisigWalletListItem get wallet => _wallet;
  WalletInitState get walletInitState => _walletProvider.walletInitState;

  Future<void> deleteWallet() async {
    await _sharedPrefs.removeFaucetHistory(_walletId);
    await _walletProvider.deleteWallet(_walletId);
  }
}
