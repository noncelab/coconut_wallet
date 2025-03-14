import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/cupertino.dart';

class WalletInfoViewModel extends ChangeNotifier {
  final int _walletId;
  final AuthProvider _authProvider;
  final WalletProvider _walletProvider;
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();

  late String _walletName;
  late WalletListItemBase _walletItemBase;
  late String _extendedPublicKey;
  late int _multisigTotalSignerCount;
  late int _multisigRequiredSignerCount;

  WalletInfoViewModel(this._walletId, this._authProvider, this._walletProvider,
      bool _isMultisig) {
    final walletItemBase = _walletProvider.getWalletById(_walletId);
    _walletItemBase = walletItemBase;
    _walletName = walletItemBase.name;

    if (_isMultisig) {
      final multisigItem = walletItemBase as MultisigWalletListItem;
      _multisigTotalSignerCount = multisigItem.signers.length;
      _multisigRequiredSignerCount = multisigItem.requiredSignatureCount;
    } else {
      final singlesigItem = walletItemBase as SinglesigWalletListItem;
      _extendedPublicKey = (singlesigItem.walletBase as SingleSignatureWallet)
          .keyStore
          .extendedPublicKey
          .serialize();
    }
  }

  bool get isDbSyncing => _walletProvider.isSyncing;
  bool get isSetPin => _authProvider.isSetPin;

  String get walletName => _walletName;
  WalletListItemBase get walletItemBase => _walletItemBase;
  int get multisigTotalSignerCount => _multisigTotalSignerCount;
  int get multisigRequiredSignerCount => _multisigRequiredSignerCount;
  String get extendedPublicKey => _extendedPublicKey;

  Future<void> deleteWallet() async {
    await _sharedPrefs.removeFaucetHistory(_walletId);
    await _walletProvider.deleteWallet(_walletId);
    _walletProvider.notifyListeners();
  }

  MultisigSigner getSigner(int index) {
    return (_walletItemBase as MultisigWalletListItem).signers[index];
  }

  String getSignerMasterFingerprint(int index) {
    final multisigWallet = walletItemBase.walletBase as MultisignatureWallet;
    return multisigWallet.keyStoreList[index].masterFingerprint;
  }
}
