import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/app/utxo/utxo_tag.dart';
import 'package:coconut_wallet/repository/converter/transaction.dart';
import 'package:coconut_wallet/repository/wallet_data_manager.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/model/app/utxo/utxo.dart' as model;

class UtxoDetailViewModel extends ChangeNotifier {
  final int _walletId;
  final model.UTXO _utxo;
  final WalletDataManager _walletDataManager;

  Transfer? _transaction;
  Transfer? get transaction => _transaction;

  List<UtxoTag> _utxoTagList = [];
  List<UtxoTag> get utxoTagList => _utxoTagList;

  List<UtxoTag> _selectedUtxoTagList = [];
  List<UtxoTag> get selectedUtxoTagList => _selectedUtxoTagList;

  List<String> _dateString = [];
  List<String> get dateString => _dateString;

  bool _isUtxoTooltipVisible = false;
  bool get isUtxoTooltipVisible => _isUtxoTooltipVisible;

  int _initialInputMaxCount = 3;
  int get initialInputMaxCount => _initialInputMaxCount;

  int _initialOutputMaxCount = 2;
  int get initialOutputMaxCount => _initialOutputMaxCount;

  UtxoDetailViewModel(this._walletId, this._utxo, this._walletDataManager) {
    _utxoTagList = _loadUtxoTagList();
    _selectedUtxoTagList = _loadSelectedUtxoTagList();
    _dateString = DateTimeUtil.formatDatetime(_utxo.timestamp).split('|');
    _initTransaction();
    notifyListeners();
  }

  void _initTransaction() {
    _transaction ??= _loadTransaction();

    if (_transaction == null) return;

    _initialInputMaxCount = _transaction!.inputAddressList.length <= 3
        ? _transaction!.inputAddressList.length
        : 3;
    _initialOutputMaxCount = _transaction!.outputAddressList.length <= 2
        ? _transaction!.outputAddressList.length
        : 2;
    if (_transaction!.inputAddressList.length <= initialInputMaxCount) {
      _initialInputMaxCount = _transaction!.inputAddressList.length;
    }
    if (_transaction!.outputAddressList.length <= initialOutputMaxCount) {
      _initialOutputMaxCount = _transaction!.outputAddressList.length;
    }

    if (_transaction!.outputAddressList.isNotEmpty) {
      _transaction!.outputAddressList.sort((a, b) {
        if (a.address == _utxo.to) return -1;
        if (b.address == _utxo.to) return 1;
        return 0;
      });
    }
  }

  void removeUtxoTooltip() {
    _isUtxoTooltipVisible = false;
    notifyListeners();
  }

  void toggleUtxoTooltip() {
    _isUtxoTooltipVisible = !_isUtxoTooltipVisible;
    notifyListeners();
  }

  TransferDTO? _loadTransaction() {
    final result = _walletDataManager.loadTransaction(_walletId, _utxo.txHash);
    if (result.isError) {
      Logger.log('-----------------------------------------------------------');
      Logger.log('loadTransaction(id: $_walletId, _utxoId: ${_utxo.utxoId})');
      Logger.log(result.error);
    }
    return result.data;
  }

  List<UtxoTag> _loadUtxoTagList() {
    final result = _walletDataManager.loadUtxoTagList(_walletId);
    if (result.isError) {
      Logger.log('-----------------------------------------------------------');
      Logger.log('loadUtxoTagList(walletId: $_walletId)');
      Logger.log(result.error);
    }
    return result.data ?? [];
  }

  List<UtxoTag> _loadSelectedUtxoTagList() {
    final result =
        _walletDataManager.loadUtxoTagListByUtxoId(_walletId, _utxo.utxoId);
    if (result.isError) {
      Logger.log(
          '-------------------------------------------------------------');
      Logger.log(
          'loadSelectedUtxoTagList(walletId: $_walletId, txHashIndex: ${_utxo.utxoId})');
      Logger.log(result.error);
    }
    return result.data ?? [];
  }

  void updateUtxoTagList({
    required List<UtxoTag> addTags,
    required List<String> selectedNames,
  }) {
    final updateUtxoTagListResult = _walletDataManager.updateUtxoTagList(
        _walletId, _utxo.utxoId, addTags, selectedNames);

    if (updateUtxoTagListResult.isError) {
      Logger.log(
          '-------------------------------------------------------------');
      Logger.log('updateUtxoTagList('
          'walletId: $_walletId,'
          'txHashIndex: ${_utxo.utxoId},'
          'addTags: $addTags,'
          'selectedNames: $selectedNames,'
          ')');
      Logger.log(updateUtxoTagListResult.error);
    }

    _utxoTagList = _loadUtxoTagList();
    _selectedUtxoTagList = _loadSelectedUtxoTagList();
    notifyListeners();
  }
}
