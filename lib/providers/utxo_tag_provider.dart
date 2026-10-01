import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/common/tag_apply_bottom_sheet.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';

class UtxoTagProvider extends ChangeNotifier {
  final UtxoRepository _utxoRepository;

  bool _isUpdatedTagList = false;
  bool get isUpdatedTagList => _isUpdatedTagList;

  UtxoTagProvider(this._utxoRepository);

  bool addUtxoTag(int walletId, UtxoTag utxoTag) {
    final newUtxoTag = utxoTag.copyWith(walletId: walletId);
    final id = const Uuid().v4();
    final result = _utxoRepository.createUtxoTag(id, newUtxoTag.walletId, newUtxoTag.name, newUtxoTag.colorIndex);
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

  void notifyTagsChanged() {
    _isUpdatedTagList = true;
    notifyListeners();
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
    final updateUtxoTagListResult = _utxoRepository.createTagAndUpdateTagsOfUtxo(
      walletId,
      utxoId,
      newTags,
      selectedTagNames,
    );

    if (updateUtxoTagListResult.isFailure) {
      Logger.log('-----------------------------------------------------------');
      Logger.log(
        'updateUtxoTagList('
        'walletId: $walletId,'
        'txHashIndex: $utxoId,'
        'newTags: $newTags,'
        'selectedTagNames: $selectedTagNames,'
        ')',
      );
      Logger.log(updateUtxoTagListResult.error);
    }

    _isUpdatedTagList = true;
    notifyListeners();
  }

  void updateUtxoTagIdList({required int walletId, required String utxoId, required List<String> tagNamesToApply}) {
    final updateUtxoTagListResult = _utxoRepository.updateUtxoTagList(walletId, utxoId, tagNamesToApply);
    if (updateUtxoTagListResult.isFailure) {
      Logger.log('-----------------------------------------------------------');
      Logger.log(
        'updateUtxoTagIdList('
        'walletId: $walletId,'
        'txHashIndex: $utxoId,'
        'tagNamesToApply: $tagNamesToApply,'
        ')',
      );
      Logger.log(updateUtxoTagListResult.error);
    }

    _isUpdatedTagList = true;
    notifyListeners();
  }

  List<String> calculateUpdatedTags({
    required List<String> currentTagNames,
    required Map<String, TagApplyState> tagStates,
  }) {
    final Set<String> updatedTagsSet = currentTagNames.toSet();

    tagStates.forEach((tagName, state) {
      if (state == TagApplyState.checked) {
        updatedTagsSet.add(tagName);
      } else if (state == TagApplyState.unchecked) {
        updatedTagsSet.remove(tagName);
      }
    });

    return updatedTagsSet.toList();
  }

  Future<void> applyTagsToUtxos({
    required int walletId,
    required List<String> selectedUtxoIds,
    required Map<String, TagApplyState> tagStates,
    required List<String> Function(String utxoId) getCurrentTagsCallback,
  }) async {
    for (final utxoId in selectedUtxoIds) {
      final currentTagNames = getCurrentTagsCallback(utxoId);

      final finalTags = calculateUpdatedTags(currentTagNames: currentTagNames, tagStates: tagStates);

      updateUtxoTagIdList(walletId: walletId, utxoId: utxoId, tagNamesToApply: finalTags);
    }
  }
}
