import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/app/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/app/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/app/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:flutter/cupertino.dart';

class WalletInfoViewModel extends ChangeNotifier {
  final int _walletId;
  final bool _isMultisig;
  final AuthProvider _authProvider;
  final WalletProvider _walletProvider;
  final SharedPrefs _sharedPrefs = SharedPrefs();

  late SinglesigWalletListItem _singlesigWalletListItem;
  late SingleSignatureWallet _singlesigWallet;

  late MultisigWalletListItem _multisigWalletListItem;
  late List<KeyStore> _keystoreList;

  WalletInfoViewModel(this._walletId, this._isMultisig, this._authProvider,
      this._walletProvider) {
    final walletBaseItem = _walletProvider.getWalletById(_walletId);
    if (_isMultisig) {
      _multisigWalletListItem = walletBaseItem as MultisigWalletListItem;
      final multisigWallet =
          _multisigWalletListItem.walletBase as MultisignatureWallet;
      _keystoreList = multisigWallet.keyStoreList;
    } else {
      _singlesigWalletListItem = walletBaseItem as SinglesigWalletListItem;
      _singlesigWallet =
          _singlesigWalletListItem.walletBase as SingleSignatureWallet;
    }
  }

  WalletInitState get walletInitState => _walletProvider.walletInitState;
  bool get isSetPin => _authProvider.isSetPin;

  Future<void> deleteWallet() async {
    await _sharedPrefs.removeFaucetHistory(_walletId);
    await _walletProvider.deleteWallet(_walletId);
  }

  WalletListItemBase getWalletItem() {
    return _isMultisig ? _multisigWalletListItem : _singlesigWalletListItem;
  }

  MultisigSigner getMultisigSigner(int index) {
    return _multisigWalletListItem.signers[index];
  }

  int getMultisigSignersLength() {
    return _multisigWalletListItem.signers.length;
  }

  String getExtendedPublicKey() {
    return _singlesigWallet.keyStore.extendedPublicKey.serialize();
  }

  String getMasterFingerprint(int index) {
    return _keystoreList[index].masterFingerprint;
  }

  String getTitleText() {
    return '${_isMultisig ? _multisigWalletListItem.name : _singlesigWalletListItem.name} 정보';
  }

  String getTooltipText() {
    return _isMultisig
        ? '${_multisigWalletListItem.signers.length}개의 키 중 ${_multisigWalletListItem.requiredSignatureCount}개로 서명해야 하는\n다중 서명 지갑이에요.'
        : '지갑의 고유 값이에요.\n마스터 핑거프린트(MFP)라고도 해요.';
  }
}
