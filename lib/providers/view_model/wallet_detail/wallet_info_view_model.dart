import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/app/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/app/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:flutter/cupertino.dart';

class WalletInfoViewModel extends ChangeNotifier {
  final int _walletId;
  final AuthProvider _authProvider;
  final WalletProvider _walletProvider;
  final SharedPrefs _sharedPrefs = SharedPrefs();

  late SinglesigWalletListItem _singlesigItem;
  late SingleSignatureWallet _singlesigWallet;

  late MultisigWalletListItem _multisigItem;
  late List<KeyStore> _keystoreList;

  WalletInfoViewModel(this._walletId, this._authProvider, this._walletProvider,
      bool isMultisig) {
    final walletBaseItem = _walletProvider.getWalletById(_walletId);
    if (isMultisig) {
      _multisigItem = walletBaseItem as MultisigWalletListItem;
      final multisigWallet = _multisigItem.walletBase as MultisignatureWallet;
      _keystoreList = multisigWallet.keyStoreList;
    } else {
      _singlesigItem = walletBaseItem as SinglesigWalletListItem;
      _singlesigWallet = _singlesigItem.walletBase as SingleSignatureWallet;
    }
  }

  SinglesigWalletListItem get singlesigItem => _singlesigItem;
  SingleSignatureWallet get singlesigWallet => _singlesigWallet;

  MultisigWalletListItem get multisigItem => _multisigItem;
  List<KeyStore> get keystoreList => _keystoreList;

  WalletInitState get walletInitState => _walletProvider.walletInitState;
  bool get isSetPin => _authProvider.isSetPin;

  Future<void> deleteWallet() async {
    await _sharedPrefs.removeFaucetHistory(_walletId);
    await _walletProvider.deleteWallet(_walletId);
  }
}
