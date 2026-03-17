import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/bip/129/signer_bsms.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:flutter/cupertino.dart';

class WalletInfoViewModel extends ChangeNotifier {
  final int _walletId;
  final AuthProvider _authProvider;
  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();

  StreamSubscription<WalletUpdateInfo>? _syncWalletStateSubscription;

  late String _walletName;
  late String _extendedPublicKey;
  late int _multisigTotalSignerCount;
  late int _multisigRequiredSignerCount;
  late WalletListItemBase _walletItemBase;
  late WalletUpdateInfo _prevWalletUpdateInfo;

  final bool _isMultisig;

  WalletInfoViewModel(this._walletId, this._authProvider, this._walletProvider, this._nodeProvider, this._isMultisig) {
    _loadWalletData();
    _walletProvider.addListener(_onWalletProviderChanged);
  }

  void _onWalletProviderChanged() {
    if (!_walletProvider.walletItemList.any((w) => w.id == _walletId)) {
      return;
    }
    _loadWalletData();
    notifyListeners();
  }

  void _loadWalletData() {
    final walletItemBase = _walletProvider.getWalletById(_walletId);
    _walletItemBase = walletItemBase;
    _walletName = walletItemBase.name;

    if (_isMultisig) {
      final multisigItem = walletItemBase as MultisigWalletListItem;
      _multisigTotalSignerCount = multisigItem.signers.length;
      _multisigRequiredSignerCount = multisigItem.requiredSignatureCount;
    } else {
      _extendedPublicKey = (walletItemBase.walletBase as SingleSignatureWallet).keyStore.extendedPublicKey.serialize();
    }

    _prevWalletUpdateInfo = WalletUpdateInfo(_walletId);
    _syncWalletStateSubscription = _nodeProvider.getWalletStateStream(_walletId).listen(_onWalletUpdateInfoChanged);
  }

  void _onWalletUpdateInfoChanged(WalletUpdateInfo newInfo) {
    final prev = _prevWalletUpdateInfo;
    _prevWalletUpdateInfo = newInfo;

    final balanceCompleted = prev.balance != WalletSyncState.completed && newInfo.balance == WalletSyncState.completed;
    final txCompleted =
        prev.transaction != WalletSyncState.completed && newInfo.transaction == WalletSyncState.completed;
    final utxoCompleted = prev.utxo != WalletSyncState.completed && newInfo.utxo == WalletSyncState.completed;

    if (balanceCompleted || txCompleted || utxoCompleted) {
      notifyListeners();
    }
  }

  bool get isSetPin => _authProvider.isSetPin;

  String get walletName => _walletName;
  WalletListItemBase get walletItemBase => _walletItemBase;
  int get multisigTotalSignerCount => _multisigTotalSignerCount;
  int get multisigRequiredSignerCount => _multisigRequiredSignerCount;
  String get extendedPublicKey => _extendedPublicKey;
  bool get isMfpPlaceholder =>
      _walletItemBase is SinglesigWalletListItem &&
      (_walletItemBase.walletBase as SingleSignatureWallet).keyStore.masterFingerprint ==
          WalletAddService.masterFingerprintPlaceholder;

  int get transactionCount => _walletProvider.getTransactionRecordList(_walletId).length;
  int get utxoCount => _walletProvider.getUtxoList(_walletId).length;
  Balance get walletBalance => _walletProvider.getWalletBalance(_walletId);

  /// 지갑별 목표 수량 (sats). null이면 미설정
  int? get targetSats => _sharedPrefs.getWalletTargetSats(_walletId);

  Future<void> setTargetSats(int targetSats) async {
    await _sharedPrefs.setWalletTargetSats(_walletId, targetSats);
    notifyListeners();
  }

  Future<void> deleteWallet() async {
    await _sharedPrefs.removeFaucetHistory(_walletId);
    await _sharedPrefs.removeWalletTargetSats(_walletId);

    await _walletProvider.deleteWallet(_walletId);
    _nodeProvider.reconnect();
    _walletProvider.notifyListeners();
  }

  MultisigSigner getSigner(int index) {
    return (_walletItemBase as MultisigWalletListItem).signers[index];
  }

  String getSignerMasterFingerprint(int index) {
    final multisigWallet = walletItemBase.walletBase as MultisignatureWallet;
    return multisigWallet.keyStoreList[index].masterFingerprint;
  }

  SignerBsms getSignerBsms(int index) {
    final multisigWallet = walletItemBase as MultisigWalletListItem;
    return multisigWallet.signerBsmsList[index];
  }

  void updateWalletName(String updatedName) {
    _walletName = updatedName;
    notifyListeners();
  }

  @override
  void dispose() {
    _syncWalletStateSubscription?.cancel();
    _walletProvider.removeListener(_onWalletProviderChanged);

    super.dispose();
  }
}
