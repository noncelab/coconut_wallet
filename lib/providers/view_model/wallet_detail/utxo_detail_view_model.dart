import 'dart:async';

import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/screens/common/tag_apply_bottom_sheet.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/material.dart';

class UtxoDetailViewModel extends ChangeNotifier {
  static const int kInputMaxCount = 3;
  static const int kOutputMaxCount = 2;

  late final int _walletId;
  late final String _utxoId;
  late UtxoState _utxo;
  late final UtxoTagProvider _tagProvider;
  late final TransactionProvider _txProvider;
  late final WalletProvider _walletProvider;
  late final BlockExplorerProvider _blockExplorerProvider;
  final Stream<WalletUpdateInfo> _syncWalletStateStream;
  StreamSubscription<WalletUpdateInfo>? _syncWalletStateSubscription;

  List<UtxoTag> _utxoTagList = [];
  List<UtxoTag> _appliedUtxoTagList = [];
  late final List<String> _dateString;
  late final TransactionRecord? _transaction;

  int _utxoInputMaxCount = 0;
  int _utxoOutputMaxCount = 0;

  String get mempoolHost => _blockExplorerProvider.blockExplorerUrl;

  UtxoDetailViewModel(
    this._walletId,
    this._utxo,
    this._tagProvider,
    this._txProvider,
    this._walletProvider,
    this._syncWalletStateStream,
    this._blockExplorerProvider,
  ) {
    _utxoId = _utxo.utxoId;
    _utxoTagList = _tagProvider.getUtxoTagList(_walletId);
    _appliedUtxoTagList = _tagProvider.getUtxoTagsByUtxoId(_walletId, _utxoId);

    _transaction = _txProvider.getTransaction(_walletId, _utxo.transactionHash);
    _dateString = _transaction != null ? DateTimeUtil.formatTimestamp(_transaction.timestamp) : ['-', '-'];

    _initUtxoInOutputList();
    _syncWalletStateSubscription = _syncWalletStateStream.listen(_onWalletUpdate);
  }

  void _onWalletUpdate(WalletUpdateInfo info) {
    final updatedUtxo = _walletProvider.getUtxoState(_walletId, _utxoId);
    if (updatedUtxo != null) {
      _utxo = updatedUtxo;
      notifyListeners();
    }
  }

  UtxoStatus _setUtxoStateToggled() {
    if (_utxo.status == UtxoStatus.locked) {
      return UtxoStatus.unspent;
    } else if (_utxo.status == UtxoStatus.unspent) {
      return UtxoStatus.locked;
    }
    return _utxo.status;
  }

  Future<bool> toggleUtxoLockStatus() async {
    try {
      await _walletProvider.toggleUtxoLockStatus(_walletId, _utxo.utxoId);
    } catch (e) {
      Logger.error('❌ toggleUtxoLockStatus error: $e');
      return false;
    }

    _utxo.status = _setUtxoStateToggled();
    notifyListeners();
    return true;
  }

  List<String> get dateString => _dateString;
  List<UtxoTag> get appliedUtxoTagList => _appliedUtxoTagList;
  UtxoTagProvider? get tagProvider => _tagProvider;

  TransactionRecord? get transaction => _transaction;
  int get utxoInputMaxCount => _utxoInputMaxCount;
  int get utxoOutputMaxCount => _utxoOutputMaxCount;
  List<UtxoTag> get utxoTagList => _utxoTagList;
  UtxoStatus get utxoStatus => _utxo.status;

  String getInputAddress(int index) => TransactionUtil.getInputAddress(_transaction, index);
  int getInputAmount(int index) => TransactionUtil.getInputAmount(_transaction, index);
  String getOutputAddress(int index) => TransactionUtil.getOutputAddress(_transaction, index);
  int getOutputAmount(int index) => TransactionUtil.getOutputAmount(_transaction, index);

  void updateUtxoTags(
    String utxoId,
    List<String> tagNamesToApply,
    List<UtxoTag> updatedTagList,
    UtxoTagApplyEditMode editMode,
  ) {
    final addedTags =
        updatedTagList
            .where((updatedTag) => !_utxoTagList.any((currentTag) => currentTag.name == updatedTag.name))
            .toList();
    final removedTags =
        _utxoTagList
            .where((currentTag) => !updatedTagList.any((updatedTag) => updatedTag.name == currentTag.name))
            .toList();

    switch (editMode) {
      case UtxoTagApplyEditMode.add:
        if (addedTags.isNotEmpty) {
          for (int i = 0; i < addedTags.length; i++) {
            _tagProvider.addUtxoTag(_walletId, addedTags[i]);
          }
        }
        break;
      case UtxoTagApplyEditMode.delete:
        if (removedTags.isNotEmpty) {
          for (int i = 0; i < removedTags.length; i++) {
            _tagProvider.deleteUtxoTag(_walletId, removedTags[i]);
          }
        }
        break;
      case UtxoTagApplyEditMode.changeAppliedTags:
        _tagProvider.updateUtxoTagIdList(walletId: _walletId, utxoId: utxoId, tagNamesToApply: tagNamesToApply);
        break;
      case UtxoTagApplyEditMode.update:
        final List<UtxoTag> modifiedTags = [];
        final currentTagsById = {for (var tag in _utxoTagList) tag.id: tag};
        final updatedTagsById = {for (var tag in updatedTagList) tag.id: tag};

        for (String id in currentTagsById.keys) {
          if (updatedTagsById.containsKey(id)) {
            final currentTag = currentTagsById[id]!;
            final updatedTag = updatedTagsById[id]!;

            if (currentTag.name != updatedTag.name || currentTag.colorIndex != updatedTag.colorIndex) {
              modifiedTags.add(updatedTag);
            }
          }
        }
        if (modifiedTags.isNotEmpty) {
          for (var modifiedTag in modifiedTags) {
            _tagProvider.updateUtxoTag(_walletId, modifiedTag);
          }
        }
    }

    _utxoTagList = _tagProvider.getUtxoTagList(_walletId);
    _appliedUtxoTagList = _tagProvider.getUtxoTagsByUtxoId(_walletId, utxoId);
    notifyListeners();
  }

  void _initUtxoInOutputList() {
    if (_transaction == null) return;

    final inputCount = _transaction.inputAddressList.length;
    final outputCount = _transaction.outputAddressList.length;

    _utxoInputMaxCount = inputCount <= kInputMaxCount ? inputCount : kInputMaxCount;
    _utxoOutputMaxCount = outputCount <= kOutputMaxCount ? outputCount : kOutputMaxCount;
  }

  List<UtxoTag> refreshTagList() {
    _utxoTagList = _tagProvider.getUtxoTagList(_walletId);
    return _utxoTagList;
  }

  @override
  void dispose() {
    _syncWalletStateSubscription?.cancel();
    super.dispose();
  }
}
