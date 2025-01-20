import 'package:coconut_wallet/model/app/utxo/utxo_tag.dart';
import 'package:coconut_wallet/repository/wallet_data_manager.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class UtxoTagViewModel extends ChangeNotifier {
  final int _walletId;
  final WalletDataManager _walletDataManager;

  List<UtxoTag> _utxoTagList = [];
  List<UtxoTag> get utxoTagList => _utxoTagList;

  UtxoTag? _selectedUtxoTag;
  UtxoTag? get selectedUtxoTag => _selectedUtxoTag;

  String? _updatedTagName;
  String? get updatedTagName => _updatedTagName;

  UtxoTagViewModel(this._walletId, this._walletDataManager) {
    _utxoTagList = loadUtxoTagList();
    notifyListeners();
  }

  void setSelectedUtxoTag(UtxoTag? utxo) {
    _selectedUtxoTag = utxo;
    notifyListeners();
  }

  String getDeleteMessage() {
    return '#${_selectedUtxoTag?.name}를 정말로 삭제하시겠어요?'
        '\n${_selectedUtxoTag?.utxoIdList?.isNotEmpty == true ? '${_selectedUtxoTag?.utxoIdList?.length}개 UTXO에 적용되어 있어요.' : ''}';
  }

  bool getEditButtonVisible() {
    return utxoTagList.isNotEmpty && selectedUtxoTag != null;
  }

  List<UtxoTag> loadUtxoTagList() {
    final result = _walletDataManager.loadUtxoTagList(_walletId);
    if (result.isError) {
      Logger.log('-----------------------------------------------------------');
      Logger.log('loadUtxoTagList(walletId: $_walletId)');
      Logger.log(result.error);
    }
    return result.data ?? [];
  }

  bool addUtxoTag(UtxoTag utxoTag) {
    final newUtxoTag = utxoTag.copyWith(walletId: _walletId);
    final id = const Uuid().v4();
    final result = _walletDataManager.addUtxoTag(
        id, newUtxoTag.walletId, newUtxoTag.name, newUtxoTag.colorIndex);
    if (result.isSuccess) {
      _utxoTagList = loadUtxoTagList();
      notifyListeners();
      return true;
    } else {
      Logger.log('-----------------------------------------------------------');
      Logger.log('addUtxoTag(utxoTag: $newUtxoTag)');
      Logger.error(result.error);
    }
    return false;
  }

  bool updateUtxoTag(UtxoTag utxoTag) {
    if (_selectedUtxoTag?.name.isNotEmpty == true) {
      final result = _walletDataManager.updateUtxoTag(
          utxoTag.id, utxoTag.name, utxoTag.colorIndex);
      if (result.isSuccess) {
        _utxoTagList = loadUtxoTagList();
        _updatedTagName = utxoTag.name;
        _selectedUtxoTag = _selectedUtxoTag?.copyWith(
          name: utxoTag.name,
          colorIndex: utxoTag.colorIndex,
          utxoIdList: utxoTag.utxoIdList ?? [],
        );
        notifyListeners();
        return true;
      } else {
        Logger.log('---------------------------------------------------------');
        Logger.log('updateUtxoTag(utxoTag: $utxoTag)');
        Logger.log(result.error);
      }
    }
    return false;
  }

  bool deleteUtxoTag() {
    if (_selectedUtxoTag != null) {
      final result = _walletDataManager.deleteUtxoTag(_selectedUtxoTag!.id);
      if (result.isSuccess) {
        _utxoTagList = loadUtxoTagList();
        _selectedUtxoTag = null;
        notifyListeners();
        return true;
      } else {
        Logger.log('---------------------------------------------------------');
        Logger.log('deleteUtxoTag(utxoTag: $_selectedUtxoTag)');
        Logger.log(result.error);
      }
    }
    return false;
  }
}
