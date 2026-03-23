import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

class UtxoSelectionViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;
  final UtxoTagProvider _tagProvider;
  final PriceProvider _priceProvider;
  final PreferenceProvider _preferenceProvider;
  late int? _bitcoinPriceKrw;
  late bool? _isNetworkOn;
  late final int _walletId;
  bool _isInitialized = false;

  final List<UtxoState> _confirmedUtxoList = [];
  List<UtxoState> _selectedUtxoList = [];
  final Set<String> _selectedUtxoIdSet = {};
  FeeInfo? _customFeeInfo;
  final List<UtxoState> _filteredUtxoList = [];

  List<FeeInfoWithLevel> feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];

  List<UtxoTag> _utxoTagList = [];
  String selectedUtxoTagName = t.all; // 선택된 태그, default: 전체
  final Map<String, List<UtxoTag>> _utxoTagMap = {};

  int? _cachedSelectedUtxoAmountSum; // 계산식 수행 반복을 방지하기 위해 추가

  final List<UtxoState> _initialSelectedUtxoList = []; // 초기 선택 상태 저장

  UtxoOrder get utxoOrder => _preferenceProvider.utxoSortOrder;

  UtxoSelectionViewModel(
    this._walletProvider,
    this._tagProvider,
    this._priceProvider,
    this._preferenceProvider,
    this._isNetworkOn,
    this._walletId,
  ) {
    _bitcoinPriceKrw = _priceProvider.bitcoinPriceKrw;
    _priceProvider.addListener(_updateBitcoinPriceKrw);
  }

  void initialize(List<UtxoState> selectedUtxoList) {
    if (_isInitialized) return;

    try {
      _confirmedUtxoList.clear();
      _filteredUtxoList.clear();
      _utxoTagMap.clear();
      _utxoTagList = [];
      _selectedUtxoList = [];
      _selectedUtxoIdSet.clear();
      _initialSelectedUtxoList.clear();

      _walletProvider.getUtxoList(_walletId).fold<int>(0, (sum, utxo) {
        if (utxo.status == UtxoStatus.unspent || utxo.status == UtxoStatus.locked) {
          _confirmedUtxoList.add(utxo);
        }
        return utxo.status == UtxoStatus.unspent ? sum + utxo.amount : sum;
      });
      _sortConfirmedUtxoList(utxoOrder);
      _initUtxoTagMap();
      _updateFilteredUtxoList();

      _utxoTagList = _tagProvider.getUtxoTagList(_walletId);

      _selectedUtxoList = List.from(selectedUtxoList);
      _selectedUtxoIdSet.addAll(selectedUtxoList.map((utxo) => utxo.utxoId));
      _initialSelectedUtxoList.addAll(selectedUtxoList);
      _cachedSelectedUtxoAmountSum = null;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      Logger.error(e);
    }
  }

  int? get bitcoinPriceKrw => _bitcoinPriceKrw;
  List<UtxoState> get confirmedUtxoList => _confirmedUtxoList;
  FeeInfo? get customFeeInfo => _customFeeInfo;
  bool get isInitialized => _isInitialized;
  bool get isUtxoTagListEmpty => _utxoTagList.isEmpty;
  bool get isNetworkOn => _isNetworkOn == true;
  List<UtxoState> get filteredUtxoList => _filteredUtxoList;

  int get selectedUtxoAmountSum {
    _cachedSelectedUtxoAmountSum ??= _calculateTotalAmountOfUtxoList(_selectedUtxoList);
    return _cachedSelectedUtxoAmountSum!;
  }

  List<UtxoState> get selectedUtxoList => _selectedUtxoList;
  Set<String> get selectedUtxoIdSet => _selectedUtxoIdSet;
  List<UtxoTag> get utxoTagList => _utxoTagList;
  Map<String, List<UtxoTag>> get utxoTagMap => _utxoTagMap;

  void addSelectedUtxoList(UtxoState utxo) {
    _selectedUtxoList.add(utxo);
    _selectedUtxoIdSet.add(utxo.utxoId);
    _cachedSelectedUtxoAmountSum = null;
    notifyListeners();
  }

  void changeUtxoOrder(UtxoOrder orderEnum) async {
    _sortConfirmedUtxoList(orderEnum);
    _preferenceProvider.setLastUtxoOrder(orderEnum);
    notifyListeners();
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  bool hasTaggedUtxo() {
    return _selectedUtxoList.any((utxo) => _utxoTagMap[utxo.utxoId]?.isNotEmpty == true);
  }

  void cacheSpentUtxoIdsWithTag({required bool isTagsMoveAllowed}) {
    _tagProvider.cacheUsedUtxoIds(
      _selectedUtxoList.map((utxo) => utxo.utxoId).toList(),
      isTagsMoveAllowed: isTagsMoveAllowed,
    );
  }

  void selectAllUtxo() {
    // locked 상태가 아닌 UTXO만 선택
    setSelectedUtxoList(confirmedUtxoList.where((e) => e.status != UtxoStatus.locked).toList());
  }

  void deselectAllUtxo() {
    _clearUtxoList();
  }

  void selectTaggedUtxo(String selectedTagName) {
    setSelectedUtxoList(filteredUtxoList.where((e) => e.status != UtxoStatus.locked).toList());
  }

  void deselectTaggedUtxo() {
    _clearUtxoList();
  }

  void setSelectedUtxoList(List<UtxoState> utxoList) {
    _selectedUtxoList = utxoList;
    _selectedUtxoIdSet
      ..clear()
      ..addAll(utxoList.map((utxo) => utxo.utxoId));
    _cachedSelectedUtxoAmountSum = null;
    notifyListeners();
  }

  void setSelectedUtxoTagName(String value) {
    selectedUtxoTagName = value;
    _updateFilteredUtxoList();
    notifyListeners();
  }

  void _updateFilteredUtxoList() {
    filteredUtxoList.clear();

    // '전체' 또는 공백이면 모든 UTXO 포함
    if (selectedUtxoTagName == t.all) {
      filteredUtxoList.addAll(confirmedUtxoList);
      return;
    }

    // 선택된 태그 이름과 일치하는 UTXO만 필터링
    for (final utxo in confirmedUtxoList) {
      final tags = _utxoTagMap[utxo.utxoId];
      if (tags != null && tags.any((tag) => tag.name == selectedUtxoTagName)) {
        filteredUtxoList.add(utxo);
      }
    }
  }

  void toggleUtxoSelection(UtxoState utxo) {
    _cachedSelectedUtxoAmountSum = null;
    if (_selectedUtxoIdSet.contains(utxo.utxoId)) {
      _selectedUtxoList.remove(utxo);
      _selectedUtxoIdSet.remove(utxo.utxoId);
    } else {
      _selectedUtxoList.add(utxo);
      _selectedUtxoIdSet.add(utxo.utxoId);
    }
    notifyListeners();
  }

  void _updateBitcoinPriceKrw() {
    _bitcoinPriceKrw = _priceProvider.bitcoinPriceKrw;
    notifyListeners();
  }

  int _calculateTotalAmountOfUtxoList(List<Utxo> utxos) {
    return utxos.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);
  }

  void _clearUtxoList() {
    _selectedUtxoList = [];
    _selectedUtxoIdSet.clear();
    _cachedSelectedUtxoAmountSum = 0;
    notifyListeners();
  }

  void _initUtxoTagMap() {
    for (var (element) in _confirmedUtxoList) {
      final tags = _tagProvider.getUtxoTagsByUtxoId(_walletId, element.utxoId);
      _utxoTagMap[element.utxoId] = tags;
    }
  }

  void _sortConfirmedUtxoList(UtxoOrder basis) {
    // 먼저 status에 따라 분리 (unlock된 것 먼저, locked는 뒤에)
    _confirmedUtxoList.sort((a, b) {
      // locked 상태 우선순위: unspent가 먼저, locked가 나중에
      if (a.status != b.status) {
        if (a.status == UtxoStatus.unspent && b.status == UtxoStatus.locked) {
          return -1; // a가 먼저
        } else if (a.status == UtxoStatus.locked && b.status == UtxoStatus.unspent) {
          return 1; // b가 먼저
        }
      }

      // 같은 status 내에서는 기존 정렬 기준 적용
      return 0;
    });

    // unlock된 UTXO들만 따로 정렬
    final unlockedUtxos = _confirmedUtxoList.where((utxo) => utxo.status == UtxoStatus.unspent).toList();
    final lockedUtxos = _confirmedUtxoList.where((utxo) => utxo.status == UtxoStatus.locked).toList();

    // 각각 별도로 정렬
    UtxoState.sortUtxo(unlockedUtxos, basis);
    UtxoState.sortUtxo(lockedUtxos, basis);

    // 다시 합치기 (unlock 먼저, lock 나중에)
    _confirmedUtxoList.clear();
    _confirmedUtxoList.addAll(unlockedUtxos);
    _confirmedUtxoList.addAll(lockedUtxos);
  }

  /// 선택 상태가 초기 상태와 다른지 확인
  bool get hasSelectionChanged {
    // 선택된 UTXO가 하나도 없으면 비활성화
    if (_selectedUtxoList.isEmpty) {
      return false;
    }

    if (_selectedUtxoList.length != _initialSelectedUtxoList.length) {
      return true;
    }

    // 같은 UTXO들이 선택되어 있는지 확인 (순서는 상관없음)
    for (final utxo in _selectedUtxoList) {
      if (!_initialSelectedUtxoList.any((initial) => initial.utxoId == utxo.utxoId)) {
        return true;
      }
    }

    return false;
  }

  @override
  void dispose() {
    _priceProvider.removeListener(_updateBitcoinPriceKrw);
    super.dispose();
  }
}
