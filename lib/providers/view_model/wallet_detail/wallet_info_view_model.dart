import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/bip/129/signer_bsms.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/widgets/card/taproot_participant_card.dart';
import 'package:collection/collection.dart';
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

  final WalletType _walletType;

  WalletInfoViewModel(this._walletId, this._authProvider, this._walletProvider, this._nodeProvider, this._walletType) {
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

    switch (_walletType) {
      case WalletType.multiSignature:
        final multisigItem = walletItemBase as MultisigWalletListItem;
        _multisigTotalSignerCount = multisigItem.signers.length;
        _multisigRequiredSignerCount = multisigItem.requiredSignatureCount;
        break;
      case WalletType.singleSignature:
        _extendedPublicKey =
            (walletItemBase.walletBase as SingleSignatureWallet).keyStore.extendedPublicKey.serialize();
        break;
      case WalletType.taproot:
        break;
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

  bool get hasTaprootKeyPath =>
      _walletItemBase is TaprootWalletListItem && (_walletItemBase as TaprootWalletListItem).canSpendViaKeyPath;

  bool get hasTaprootScriptPath =>
      _walletItemBase is TaprootWalletListItem && (_walletItemBase as TaprootWalletListItem).canSpendViaScriptPath;

  bool get canSpendBothPaths =>
      _walletItemBase is TaprootWalletListItem && (_walletItemBase as TaprootWalletListItem).canSpendBothPaths;

  bool get hasSingleTaprootParent {
    if (_walletItemBase is! TaprootWalletListItem) return false;

    final taprootWallet = _walletItemBase.walletBase;
    if (taprootWallet is! TaprootWallet) return false;

    return taprootWallet.keyStoreList.length == 1;
  }

  List<TaprootParticipantCard> getTaprootParticipants(int currentSegmentIndex) {
    final item = _walletItemBase;
    if (item is! TaprootWalletListItem) return [];

    final descriptor = item.descriptor;

    final trStart = descriptor.indexOf('tr(');
    if (trStart == -1) return [];

    final keyPathEndIndex = _findKeyPathEndIndex(descriptor, trStart);

    final matches = RegExp(r'\[([0-9a-fA-F]{8})([^\]]+)\]([a-zA-Z0-9]+)').allMatches(descriptor);
    if (matches.isEmpty) return [];

    final parentCount = matches.where((m) => m.start < keyPathEndIndex).length;
    int parentIndex = 0;

    return matches.map((match) {
      final mfp = match.group(1)!.toUpperCase();
      final path = match.group(2)!.replaceAll('h', "'");
      final xpub = match.group(3)!;

      final isParent = match.start < keyPathEndIndex;
      final role = isParent ? TaprootParticipantRole.parent : TaprootParticipantRole.child;
      final isPathSelected = (currentSegmentIndex == 0) == isParent;

      final isMine =
          isPathSelected &&
          (isParent
              ? item.keyPathSeedInfos.any((key) => key.contains(xpub) || xpub.contains(key))
              : item.scriptPathSeedInfos.any(
                (s) => s.extendedPublicKeys.any((key) => key.contains(xpub) || xpub.contains(key)),
              ));

      int? locktime;
      if (!isParent) {
        locktime = item.policies?.whereType<InheritancePolicy>().firstOrNull?.locktime;

        if (locktime == null) {
          final locktimeMatch = RegExp(r'(older|after)\s*\(\s*(\d+)\s*\)', caseSensitive: false).firstMatch(descriptor);
          locktime = int.tryParse(locktimeMatch?.group(2) ?? '');
        }
      }

      final walletName =
          isParent
              ? (parentCount > 1 ? '${t.taproot.parent} ${String.fromCharCode(65 + parentIndex++)}' : t.taproot.parent)
              : (isMine ? item.name : null);

      return TaprootParticipantCard(
        role: role,
        isMine: isMine,
        hasBackgroundColor: isMine && isPathSelected,
        mfp: mfp,
        derivationPath: "m$path",
        locktime: locktime,
        walletName: walletName,
        hasSingleParent: isParent && parentCount == 1,
      );
    }).toList();
  }

  int _findKeyPathEndIndex(String descriptor, int trStart) {
    String trContent = descriptor.substring(trStart + 3);
    int depth = 0;
    for (int i = 0; i < trContent.length; i++) {
      if (trContent[i] == '(') {
        depth++;
      } else if (trContent[i] == ')') {
        if (depth == 0) break;
        depth--;
      } else if (trContent[i] == ',' && depth == 0) {
        return trStart + 3 + i;
      }
    }
    return descriptor.lastIndexOf(')');
  }

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

  int get taprootSpendTypeIndex {
    if (_walletItemBase is! TaprootWalletListItem) return 0;
    final item = _walletItemBase as TaprootWalletListItem;
    return item.defaultSpendType == TaprootSpendType.keyPath ? 0 : 1;
  }

  Future<void> updateTaprootSpendType(int index) async {
    final type = index == 0 ? TaprootSpendType.keyPath : TaprootSpendType.scriptPath;
    await _walletProvider.updateTaprootSpendType(_walletId, type);
  }

  @override
  void dispose() {
    _syncWalletStateSubscription?.cancel();
    _walletProvider.removeListener(_onWalletProviderChanged);

    super.dispose();
  }
}
