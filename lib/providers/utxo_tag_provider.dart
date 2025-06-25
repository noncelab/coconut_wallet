import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';

class UtxoTagProvider extends ChangeNotifier {
  final UtxoRepository _utxoRepository;

  List<String> _spentUtxoIds = [];
  bool _isTagsMoveAllowed = false;

  bool _isUpdatedTagList = false;
  bool get isUpdatedTagList => _isUpdatedTagList;

  UtxoTagProvider(this._utxoRepository);

  bool addUtxoTag(int walletId, UtxoTag utxoTag) {
    final newUtxoTag = utxoTag.copyWith(walletId: walletId);
    final id = const Uuid().v4();
    final result = _utxoRepository.createUtxoTag(
        id, newUtxoTag.walletId, newUtxoTag.name, newUtxoTag.colorIndex);
    if (result.isSuccess) {
      _isUpdatedTagList = true;
      notifyListeners();
      return true;
    } else {
      Logger.log('-----------------------------------------------------------');
      Logger.log('addUtxoTag(utxoTag: $newUtxoTag)');
      Logger.error(result.error);
    }
    return false;
  }

  // [utxo tag 승계 유무에 따라 Utxo 태그 적용]
  // broadcasting_view_model.dart / updateTagsOfUsedUtxos에서 호출
  Future applyTagsToNewUtxos(int walletId, String signedTx, List<int> outputIndexes) async {
    List<String> newUtxoIds =
        _isTagsMoveAllowed ? outputIndexes.map((index) => getUtxoId(signedTx, index)).toList() : [];

    final result =
        await _utxoRepository.updateTagsOfSpentUtxos(walletId, _spentUtxoIds, newUtxoIds);
    if (result.isFailure) {
      Logger.error(result.error);
    }
    _spentUtxoIds = [];
    _isTagsMoveAllowed = false;
  }

  // [utxo tag 승계 유무 정보 저장]
  // send_utxo_selection_view_model.dart / cacheSpentUtxoIdsWithTag에서 호출
  // 사용한 utxo 중, 태그된 것이 하나라도 있는 경우, 사용한 utxo id 목록을 저장
  void cacheUsedUtxoIds(List<String> utxoIdList, {required bool isTagsMoveAllowed}) {
    _spentUtxoIds = utxoIdList;
    _isTagsMoveAllowed = isTagsMoveAllowed;
  }

  bool deleteUtxoTag(int walletId, UtxoTag utxoTag) {
    final result = _utxoRepository.deleteUtxoTag(utxoTag.id);
    if (result.isSuccess) {
      _isUpdatedTagList = true;
      notifyListeners();
      return true;
    } else {
      Logger.log('---------------------------------------------------------');
      Logger.log('deleteUtxoTag(utxoTag: $utxoTag})');
      Logger.log(result.error);
    }

    return false;
  }

  List<UtxoTag> getUtxoTagList(int walletId) {
    final result = _utxoRepository.getUtxoTags(walletId);
    if (result.isFailure) {
      Logger.log('-----------------------------------------------------------');
      Logger.log('fetchUtxoTags(walletId: $walletId)');
      Logger.log(result.error);
      return [];
    }
    return result.value;
  }

  List<UtxoTag> getUtxoTagsByUtxoId(int walletId, String utxoId) {
    final result = _utxoRepository.getUtxoTagsByTxHash(walletId, utxoId);
    if (result.isFailure) {
      Logger.log('-----------------------------------------------------------');
      Logger.log('getUtxoTagsByUtxoId(walletId: $walletId, txHashIndex: $utxoId)');
      Logger.log(result.error);
      return [];
    }
    return result.value;
  }

  void reset() {
    _isUpdatedTagList = false;
    _spentUtxoIds = [];
    _isTagsMoveAllowed = false;
  }

  void resetUtxoTagsUpdateState() {
    _isUpdatedTagList = false;
  }

  bool updateUtxoTag(int walletId, UtxoTag utxoTag) {
    final result = _utxoRepository.updateUtxoTag(utxoTag.id, utxoTag.name, utxoTag.colorIndex);
    if (result.isSuccess) {
      _isUpdatedTagList = true;
      notifyListeners();
      return true;
    } else {
      Logger.log('---------------------------------------------------------');
      Logger.log('updateUtxoTag(utxoTag: $utxoTag)');
      Logger.log(result.error);
    }
    return false;
  }

  void updateUtxoTagList({
    required int walletId,
    required String utxoId,
    required List<UtxoTag> newTags,
    required List<String> selectedTagNames,
  }) async {
    final updateUtxoTagListResult =
        _utxoRepository.createTagAndUpdateTagsOfUtxo(walletId, utxoId, newTags, selectedTagNames);

    if (updateUtxoTagListResult.isFailure) {
      Logger.log('-----------------------------------------------------------');
      Logger.log('updateUtxoTagList('
          'walletId: $walletId,'
          'txHashIndex: $utxoId,'
          'newTags: $newTags,'
          'selectedTagNames: $selectedTagNames,'
          ')');
      Logger.log(updateUtxoTagListResult.error);
    }

    _isUpdatedTagList = true;
    notifyListeners();
  }
}
