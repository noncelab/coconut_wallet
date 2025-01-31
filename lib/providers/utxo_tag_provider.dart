import 'package:coconut_wallet/model/app/utxo/utxo_tag.dart';
import 'package:coconut_wallet/repository/wallet_data_manager.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';

class UtxoTagProvider extends ChangeNotifier {
  final WalletDataManager _walletDataManager = WalletDataManager();

  List<UtxoTag> _tagList = [];
  List<UtxoTag> _selectedTagList = [];
  UtxoTag? _selectedUtxoTag;

  String? _updatedTagName;
  bool _isUpdatedTagList = false;

  List<String> _usedUtxoIdListWhenSend = [];
  bool _isTagsMoveAllowed = false;

  bool get isUpdatedTagList => _isUpdatedTagList;

  UtxoTag? get selectedUtxoTag => _selectedUtxoTag;
  String? get updatedTagName => _updatedTagName;

  List<UtxoTag> get tagList => _tagList;
  List<UtxoTag> get selectedTagList => _selectedTagList;

  List<String> get usedUtxoIdListWhenSend => _usedUtxoIdListWhenSend;
  bool get isTagsMoveAllowed => _isTagsMoveAllowed;

  void initTagList(int walletId, {String? utxoId}) {
    _isUpdatedTagList = false;
    _tagList = _loadUtxoTagList(walletId);
    if (utxoId != null) {
      _selectedTagList = loadSelectedUtxoTagList(walletId, utxoId);
    }
  }

  void setSelectedUtxoTag(UtxoTag? utxo) {
    _selectedUtxoTag = utxo;
    notifyListeners();
  }

  bool addUtxoTag(int walletId, UtxoTag utxoTag) {
    final newUtxoTag = utxoTag.copyWith(walletId: walletId);
    final id = const Uuid().v4();
    final result = _walletDataManager.addUtxoTag(
        id, newUtxoTag.walletId, newUtxoTag.name, newUtxoTag.colorIndex);
    if (result.isSuccess) {
      _tagList = _loadUtxoTagList(walletId);
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

  bool deleteUtxoTag(int walletId) {
    if (_selectedUtxoTag != null) {
      final result = _walletDataManager.deleteUtxoTag(_selectedUtxoTag!.id);
      if (result.isSuccess) {
        _tagList = _loadUtxoTagList(walletId);
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

  bool updateUtxoTag(int walletId, UtxoTag utxoTag) {
    if (_selectedUtxoTag?.name.isNotEmpty == true) {
      final result = _walletDataManager.updateUtxoTag(
          utxoTag.id, utxoTag.name, utxoTag.colorIndex);
      if (result.isSuccess) {
        _tagList = _loadUtxoTagList(walletId);
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

  void updateUtxoTagList({
    required int walletId,
    required String utxoId,
    required List<UtxoTag> addTags,
    required List<String> selectedNames,
  }) {
    final updateUtxoTagListResult = _walletDataManager.updateUtxoTagList(
        walletId, utxoId, addTags, selectedNames);

    if (updateUtxoTagListResult.isError) {
      Logger.log('-----------------------------------------------------------');
      Logger.log('updateUtxoTagList('
          'walletId: $walletId,'
          'txHashIndex: $utxoId,'
          'addTags: $addTags,'
          'selectedNames: $selectedNames,'
          ')');
      Logger.log(updateUtxoTagListResult.error);
    }

    _tagList = _loadUtxoTagList(walletId);
    _selectedTagList = loadSelectedUtxoTagList(walletId, utxoId);
    _isUpdatedTagList = true;
    notifyListeners();
  }

  Future updateTagsOfUsedUtxos(
      int walletId, String signedTx, List<int> outputIndexes) async {
    List<String> newUtxoIds = _isTagsMoveAllowed
        ? outputIndexes.map((index) => makeUtxoId(signedTx, index)).toList()
        : [];

    final result = await _walletDataManager.updateTagsOfUsedUtxos(
        walletId, _usedUtxoIdListWhenSend, newUtxoIds);
    if (result.isError) {
      Logger.error(result.error);
    }
    _usedUtxoIdListWhenSend = [];
    _isTagsMoveAllowed = false;
  }

  void recordUsedUtxoIdListWhenSend(
      List<String> utxoIdList, bool isTagsMoveAllowed) {
    _usedUtxoIdListWhenSend = utxoIdList;
    _isTagsMoveAllowed = isTagsMoveAllowed;
  }

  List<UtxoTag> loadSelectedUtxoTagList(int walletId, String utxoId) {
    final result = _walletDataManager.loadUtxoTagListByUtxoId(walletId, utxoId);
    if (result.isError) {
      Logger.log('-----------------------------------------------------------');
      Logger.log(
          'loadSelectedUtxoTagList(walletId: $walletId, txHashIndex: $utxoId)');
      Logger.log(result.error);
    }
    return result.data ?? [];
  }

  List<UtxoTag> _loadUtxoTagList(int walletId) {
    final result = _walletDataManager.loadUtxoTagList(walletId);
    if (result.isError) {
      Logger.log('-----------------------------------------------------------');
      Logger.log('loadUtxoTagList(walletId: $walletId)');
      Logger.log(result.error);
    }
    return result.data ?? [];
  }

  void resetData() {
    _isUpdatedTagList = false;
    _selectedUtxoTag = null;
    _updatedTagName = null;
    _tagList.clear();
    _selectedTagList.clear();
  }
}
