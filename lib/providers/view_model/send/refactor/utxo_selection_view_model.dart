import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';

class UtxoSelectionViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;
  final UtxoTagProvider _tagProvider;
  final PriceProvider _priceProvider;
  late int? _bitcoinPriceKrw;
  late bool? _isNetworkOn;
  late final int _walletId;

  final List<UtxoState> _confirmedUtxoList = [];
  List<UtxoState> _selectedUtxoList = [];
  FeeInfo? _customFeeInfo;

  List<FeeInfoWithLevel> feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];

  List<UtxoTag> _utxoTagList = [];
  String selectedUtxoTagName = t.all; // 선택된 태그, default: 전체
  final Map<String, List<UtxoTag>> _utxoTagMap = {};

  int? _cachedSelectedUtxoAmountSum; // 계산식 수행 반복을 방지하기 위해 추가

  UtxoSelectionViewModel(
      this._walletProvider,
      this._tagProvider,
      this._priceProvider,
      this._isNetworkOn,
      this._walletId,
      List<UtxoState> selectedUtxoList,
      UtxoOrder initialUtxoOrder) {
    try {
      _walletProvider.getUtxoList(_walletId).fold<int>(0, (sum, utxo) {
        if (utxo.status == UtxoStatus.unspent) {
          _confirmedUtxoList.add(utxo);
        }
        return utxo.status == UtxoStatus.unspent ? sum + utxo.amount : sum;
      });
      _sortConfirmedUtxoList(initialUtxoOrder);
      _initUtxoTagMap();

      _confirmedUtxoList.where((utxo) => utxo.status != UtxoStatus.locked).toList();
      _utxoTagList = _tagProvider.getUtxoTagList(_walletId);

      _selectedUtxoList = selectedUtxoList;
      _bitcoinPriceKrw = _priceProvider.bitcoinPriceKrw;
      _priceProvider.addListener(_updateBitcoinPriceKrw);
    } catch (e) {
      print(e);
    }
  }

  int? get bitcoinPriceKrw => _bitcoinPriceKrw;
  List<UtxoState> get confirmedUtxoList => _confirmedUtxoList;
  FeeInfo? get customFeeInfo => _customFeeInfo;
  bool get isUtxoTagListEmpty => _utxoTagList.isEmpty;
  bool get isNetworkOn => _isNetworkOn == true;

  int get selectedUtxoAmountSum {
    _cachedSelectedUtxoAmountSum ??= _calculateTotalAmountOfUtxoList(_selectedUtxoList);
    return _cachedSelectedUtxoAmountSum!;
  }

  List<UtxoState> get selectedUtxoList => _selectedUtxoList;
  List<UtxoTag> get utxoTagList => _utxoTagList;
  Map<String, List<UtxoTag>> get utxoTagMap => _utxoTagMap;

  void addSelectedUtxoList(UtxoState utxo) {
    _selectedUtxoList.add(utxo);
    _cachedSelectedUtxoAmountSum = null;
    notifyListeners();
  }

  void changeUtxoOrder(UtxoOrder orderEnum) async {
    _sortConfirmedUtxoList(orderEnum);
    notifyListeners();
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  void deselectAllUtxo() {
    _clearUtxoList();
  }

  bool hasTaggedUtxo() {
    return _selectedUtxoList.any((utxo) => _utxoTagMap[utxo.utxoId]?.isNotEmpty == true);
  }

  void cacheSpentUtxoIdsWithTag({required bool isTagsMoveAllowed}) {
    _tagProvider.cacheUsedUtxoIds(_selectedUtxoList.map((utxo) => utxo.utxoId).toList(),
        isTagsMoveAllowed: isTagsMoveAllowed);
  }

  void selectAllUtxo() {
    setSelectedUtxoList(confirmedUtxoList.where((e) => e.status != UtxoStatus.locked).toList());
  }

  void setSelectedUtxoList(List<UtxoState> utxoList) {
    _selectedUtxoList = utxoList;
    _cachedSelectedUtxoAmountSum = null;
    notifyListeners();
  }

  void setSelectedUtxoTagName(String value) {
    selectedUtxoTagName = value;
    notifyListeners();
  }

  void toggleUtxoSelection(UtxoState utxo) {
    _cachedSelectedUtxoAmountSum = null;
    if (_selectedUtxoList.contains(utxo)) {
      _selectedUtxoList.remove(utxo);
    } else {
      _selectedUtxoList.add(utxo);
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
    UtxoState.sortUtxo(_confirmedUtxoList, basis);
  }

  @override
  void dispose() {
    _priceProvider.removeListener(_updateBitcoinPriceKrw);
    super.dispose();
  }
}
