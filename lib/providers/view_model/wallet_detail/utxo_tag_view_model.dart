import 'package:coconut_wallet/model/app/utxo/utxo_tag.dart';
import 'package:coconut_wallet/repository/wallet_data_manager.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class UtxoTagViewModel extends ChangeNotifier {
  final int _walletId;
  final WalletDataManager _walletDataManager;

  List<UtxoTag> _utxoTagList = [];
  UtxoTag? _selectedUtxoTag;

  String? _updatedTagName;
  bool _isUpdatedTagList = false;

  UtxoTagViewModel(this._walletId, this._walletDataManager) {
    _utxoTagList = _loadUtxoTagList();
    notifyListeners();
  }
  bool get isUpdatedTagList => _isUpdatedTagList;

  UtxoTag? get selectedUtxoTag => _selectedUtxoTag;
  String? get updatedTagName => _updatedTagName;

  List<UtxoTag> get utxoTagList => _utxoTagList;

  bool addUtxoTag(UtxoTag utxoTag) {
    final newUtxoTag = utxoTag.copyWith(walletId: _walletId);
    final id = const Uuid().v4();
    final result = _walletDataManager.addUtxoTag(
        id, newUtxoTag.walletId, newUtxoTag.name, newUtxoTag.colorIndex);
    if (result.isSuccess) {
      _utxoTagList = _loadUtxoTagList();
      notifyListeners();
      _isUpdatedTagList = true;
      return true;
    } else {
      Logger.log('-----------------------------------------------------------');
      Logger.log('addUtxoTag(utxoTag: $newUtxoTag)');
      Logger.error(result.error);
    }
    return false;
  }

  bool deleteUtxoTag() {
    if (_selectedUtxoTag != null) {
      final result = _walletDataManager.deleteUtxoTag(_selectedUtxoTag!.id);
      if (result.isSuccess) {
        _utxoTagList = _loadUtxoTagList();
        _selectedUtxoTag = null;
        _isUpdatedTagList = true;
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

  String getDeleteMessage() {
    return '#${_selectedUtxoTag?.name}를 정말로 삭제하시겠어요?'
        '\n${_selectedUtxoTag?.utxoIdList?.isNotEmpty == true ? '${_selectedUtxoTag?.utxoIdList?.length}개 UTXO에 적용되어 있어요.' : ''}';
  }

  void setSelectedUtxoTag(UtxoTag? utxo) {
    _selectedUtxoTag = utxo;
    notifyListeners();
  }

  bool updateUtxoTag(UtxoTag utxoTag) {
    if (_selectedUtxoTag?.name.isNotEmpty == true) {
      final result = _walletDataManager.updateUtxoTag(
          utxoTag.id, utxoTag.name, utxoTag.colorIndex);
      if (result.isSuccess) {
        _utxoTagList = _loadUtxoTagList();
        _updatedTagName = utxoTag.name;
        _selectedUtxoTag = _selectedUtxoTag?.copyWith(
          name: utxoTag.name,
          colorIndex: utxoTag.colorIndex,
          utxoIdList: utxoTag.utxoIdList ?? [],
        );
        _isUpdatedTagList = true;
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

  List<UtxoTag> _loadUtxoTagList() {
    final result = _walletDataManager.loadUtxoTagList(_walletId);
    if (result.isError) {
      Logger.log('-----------------------------------------------------------');
      Logger.log('loadUtxoTagList(walletId: $_walletId)');
      Logger.log(result.error);
    }
    return result.data ?? [];
  }
}
