import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/fee_selection_screen.dart';
import 'package:coconut_wallet/screens/send/send_utxo_selection_screen.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/material.dart';

enum ErrorState {
  insufficientBalance,
  failedToFetchRecommendedFee,
  insufficientUtxo;

  String get displayMessage {
    switch (this) {
      case ErrorState.insufficientBalance:
        return t.errors.fee_selection_error.insufficient_balance;
      case ErrorState.failedToFetchRecommendedFee:
        return t.errors.fee_selection_error.recommended_fee_unavailable;
      case ErrorState.insufficientUtxo:
        return t.errors.fee_selection_error.insufficient_utxo;
    }
  }
}

class SendUtxoSelectionViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;
  final UtxoTagProvider _tagProvider;
  final SendInfoProvider _sendInfoProvider;
  final NodeProvider _nodeProvider;
  final PriceProvider _priceProvider;
  late int _sendAmount;
  late String _changeAddressDerivationPath;
  late bool _isMaxMode;
  late bool? _isNetworkOn;
  late Transaction? _transaction;
  late int? _requiredSignature;
  late WalletListItemBase _walletBaseItem;
  late int _confirmedBalance;
  late TransactionBuilder _txBuilder;

  late final int _walletId;

  final List<UtxoState> _confirmedUtxoList = [];
  List<UtxoState> _selectedUtxoList = [];
  RecommendedFeeFetchStatus _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.fetching;
  TransactionFeeLevel? _selectedLevel = TransactionFeeLevel.halfhour;

  RecommendedFee? _recommendedFees;

  FeeInfo? _customFeeInfo;
  int? _estimatedFee = 0;

  List<FeeInfoWithLevel> feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];

  List<UtxoTag> _utxoTagList = [];
  String selectedUtxoTagName = t.all; // 선택된 태그, default: 전체
  final Map<String, List<UtxoTag>> _utxoTagMap = {};

  int? _cachedSelectedUtxoAmountSum; // 계산식 수행 반복을 방지하기 위해 추가

  SendUtxoSelectionViewModel(this._walletProvider, this._tagProvider, this._sendInfoProvider,
      this._nodeProvider, this._priceProvider, this._isNetworkOn, UtxoOrder initialUtxoOrder) {
    _walletId = _sendInfoProvider.walletId!;
    _walletBaseItem = _walletProvider.getWalletById(_walletId);
    _requiredSignature = _walletBaseItem.walletType == WalletType.multiSignature
        ? (_walletBaseItem as MultisigWalletListItem).requiredSignatureCount
        : null;

    _confirmedBalance =
        _walletProvider.getUtxoList(_sendInfoProvider.walletId!).fold<int>(0, (sum, utxo) {
      if (utxo.status == UtxoStatus.unspent || utxo.status == UtxoStatus.locked) {
        _confirmedUtxoList.add(utxo);
      }
      return utxo.status == UtxoStatus.unspent ? sum + utxo.amount : sum;
    });

    _sortConfirmedUtxoList(initialUtxoOrder);
    _initUtxoTagMap();

    _changeAddressDerivationPath = _walletProvider.getChangeAddress(_walletId).derivationPath;
    _isMaxMode = _confirmedBalance == UnitUtil.convertBitcoinToSatoshi(_sendInfoProvider.amount!);
    _setAmount();

    _txBuilder = TransactionBuilder(
        availableUtxos: [],
        recipients: _sendInfoProvider.getRecipientMap()!,
        feeRate: 1,
        changeDerivationPath: _changeAddressDerivationPath,
        walletListItemBase: _walletBaseItem,
        isFeeSubtractedFromAmount: _isMaxMode,
        isUtxoFixed: true);

    final buildResult = _txBuilder.build();
    if (buildResult.isSuccess) {
      _transaction = buildResult.transaction!;
      _estimatedFee = buildResult.estimatedFee!;
    } else {
      var a = 1;
    }

    _utxoTagList = _tagProvider.getUtxoTagList(_walletId);

    _setRecommendedFees().then((bool result) async {
      if (result) {
        _updateFeeRate(satsPerVb!);
        _setAmount();
      }
      notifyListeners();
    });
  }

  int? get change {
    if (_sendInfoProvider.walletId == null) {
      // 이미 보내기 과정 완료 후 호출 될 때를 대비
      return null;
    }

    if (_recommendedFeeFetchStatus == RecommendedFeeFetchStatus.fetching) {
      return null;
    }

    if (_recommendedFeeFetchStatus == RecommendedFeeFetchStatus.failed && _customFeeInfo == null) {
      return null;
    }

    if (_transaction == null) {
      return null;
    }
    // 트랜잭션 출력 주소 중 change 주소를 모두 조회
    final changeAddresses = _walletProvider.filterChangeAddressesFromList(
        _sendInfoProvider.walletId!,
        _transaction!.outputs.map((e) => e.scriptPubKey.getAddress()).toList());

    int changeAmount;

    if (changeAddresses.isEmpty) {
      changeAmount = 0;
    } else {
      // 가장 마지막 change 주소에 해당하는 금액을 change 금액으로 간주함
      changeAmount = _transaction!.outputs
          .where((output) => output.getAddress() == changeAddresses.last.address)
          .first
          .amount;
    }

    if (changeAmount != 0) return changeAmount;
    if (_estimatedFee == null) return null;
    // utxo가 모자랄 때도 change = 0으로 반환되기 때문에 진짜 잔돈이 0인지 아닌지 확인이 필요
    if (_confirmedBalance < needAmount) {
      return _confirmedBalance - needAmount;
    }

    return _isSelectedUtxoEnough() ? changeAmount : null;
  }

  List<UtxoState> get confirmedUtxoList => _confirmedUtxoList;
  FeeInfo? get customFeeInfo => _customFeeInfo;
  bool get customFeeSelected => _selectedLevel == null;
  ErrorState? get errorState {
    if (_estimatedFee == null) {
      return null;
    }

    if (_confirmedBalance < needAmount) {
      return ErrorState.insufficientBalance;
    }

    if (_recommendedFeeFetchStatus == RecommendedFeeFetchStatus.failed && _customFeeInfo == null) {
      return ErrorState.failedToFetchRecommendedFee;
    }

    if (selectedUtxoAmountSum < needAmount) {
      return ErrorState.insufficientUtxo;
    }

    return null;
  }

  int? get estimatedFee => _estimatedFee;

  bool get isMaxMode => _isMaxMode;
  bool get isUtxoTagListEmpty => _utxoTagList.isEmpty;
  bool get isNetworkOn => _isNetworkOn == true;
  int get needAmount => _sendAmount + (_estimatedFee ?? 0);

  RecommendedFeeFetchStatus get recommendedFeeFetchStatus => _recommendedFeeFetchStatus;
  RecommendedFee? get recommendedFees => _recommendedFees;
  double? get satsPerVb {
    if (_selectedLevel == null) {
      return _customFeeInfo?.satsPerVb;
    }

    return feeInfos.firstWhere((feeInfo) => feeInfo.level == _selectedLevel).satsPerVb;
  }

  TransactionFeeLevel? get selectedLevel => _selectedLevel;

  int get selectedUtxoAmountSum {
    _cachedSelectedUtxoAmountSum ??= _calculateTotalAmountOfUtxoList(_selectedUtxoList);
    return _cachedSelectedUtxoAmountSum!;
  }

  List<UtxoState> get selectedUtxoList => _selectedUtxoList;

  int get sendAmount => _sendAmount;

  List<UtxoTag> get utxoTagList => _utxoTagList;
  Map<String, List<UtxoTag>> get utxoTagMap => _utxoTagMap;
  TransactionBuilder get txBuilder => _txBuilder;

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
    _selectedUtxoList = [];
    _cachedSelectedUtxoAmountSum = 0;
    notifyListeners();
    if (!_isMaxMode) {
      _updateUtxoList(_selectedUtxoList);
    }
  }

  Future<Result<int>?> getMinimumFeeRateFromNetwork() async {
    return await _nodeProvider.getNetworkMinimumFeeRate();
  }

  bool hasTaggedUtxo() {
    return _selectedUtxoList.any((utxo) => _utxoTagMap[utxo.utxoId]?.isNotEmpty == true);
  }

  void onFeeRateChanged(Map<String, dynamic> feeSelectionResult) {
    _estimatedFee = (feeSelectionResult[FeeSelectionScreen.feeInfoField] as FeeInfo).estimatedFee;
    _selectedLevel = feeSelectionResult[FeeSelectionScreen.selectedOptionField];
    if (feeSelectionResult[FeeSelectionScreen.updatedTxBuilderField] != null) {
      _txBuilder =
          feeSelectionResult[FeeSelectionScreen.updatedTxBuilderField] as TransactionBuilder;
    }
    _setAmount();
    notifyListeners();

    _customFeeInfo = feeSelectionResult[FeeSelectionScreen.selectedOptionField] == null
        ? (feeSelectionResult[FeeSelectionScreen.feeInfoField] as FeeInfo)
        : null;

    var satsPerVb = _customFeeInfo?.satsPerVb! ??
        feeInfos.firstWhere((feeInfo) => feeInfo.level == _selectedLevel).satsPerVb!;
    _updateFeeRate(satsPerVb);
  }

  void cacheSpentUtxoIdsWithTag({required bool isTagsMoveAllowed}) {
    _tagProvider.cacheUsedUtxoIds(_selectedUtxoList.map((utxo) => utxo.utxoId).toList(),
        isTagsMoveAllowed: isTagsMoveAllowed);
  }

  void selectAllUtxo() {
    setSelectedUtxoList(confirmedUtxoList.where((e) => e.status != UtxoStatus.locked).toList());
    _updateUtxoList(_selectedUtxoList);
  }

  void _updateUtxoList(List<UtxoState> utxoList) {
    _txBuilder = _txBuilder.copyWith(
      availableUtxos: utxoList,
    );
    final result = _txBuilder.build();
    _transaction = result.transaction;
    _estimatedFee = result.estimatedFee;
    _updateFeeInfoEstimateFee();
    _setAmount();
    notifyListeners();
  }

  void _updateFeeRate(double feeRate) {
    _txBuilder = _txBuilder.copyWith(
      feeRate: feeRate,
    );
    final result = _txBuilder.build();
    _transaction = result.transaction;
    _estimatedFee = result.estimatedFee;
    _setAmount();
    notifyListeners();
  }

  void setEstimatedFee(int value) {
    _estimatedFee = value;
    notifyListeners();
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
    if (selectedUtxoList.contains(utxo)) {
      selectedUtxoList.remove(utxo);
    } else {
      selectedUtxoList.add(utxo);
    }
    if (!_isMaxMode) {
      _updateUtxoList(selectedUtxoList);
    }
    notifyListeners();
  }

  int _calculateTotalAmountOfUtxoList(List<Utxo> utxos) {
    return utxos.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);
  }

  void _initFeeInfo(FeeInfo feeInfo, int estimatedFee) {
    feeInfo.estimatedFee = estimatedFee;
    feeInfo.fiatValue = _priceProvider.getFiatAmount(estimatedFee);

    if (feeInfo is FeeInfoWithLevel && feeInfo.level == _selectedLevel) {
      _estimatedFee = estimatedFee;
      return;
    }
  }

  void _initUtxoTagMap() {
    for (var (element) in _confirmedUtxoList) {
      final tags = _tagProvider.getUtxoTagsByUtxoId(_sendInfoProvider.walletId!, element.utxoId);
      _utxoTagMap[element.utxoId] = tags;
    }
  }

  bool _isSelectedUtxoEnough() {
    if (_selectedUtxoList.isEmpty) return false;

    if (_isMaxMode) {
      return selectedUtxoAmountSum == _confirmedBalance;
    }

    if (_estimatedFee == null) {
      throw StateError("EstimatedFee has not been calculated yet");
    }
    return selectedUtxoAmountSum >= needAmount;
  }

  void _setAmount() {
    _sendAmount = _isMaxMode
        ? UnitUtil.convertBitcoinToSatoshi(
              _sendInfoProvider.amount!,
            ) -
            (_estimatedFee ?? 0)
        : UnitUtil.convertBitcoinToSatoshi(
            _sendInfoProvider.amount!,
          );
  }

  Future<bool> _setRecommendedFees() async {
    final recommendedFeesResult = await _nodeProvider.getRecommendedFees();

    if (recommendedFeesResult.isFailure) {
      _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.failed;
      return false;
    }

    final recommendedFees = recommendedFeesResult.value;

    feeInfos[0].satsPerVb = recommendedFees.fastestFee.toDouble();
    feeInfos[1].satsPerVb = recommendedFees.halfHourFee.toDouble();
    feeInfos[2].satsPerVb = recommendedFees.hourFee.toDouble();

    final updateFeeInfoResult = _updateFeeInfoEstimateFee();
    if (updateFeeInfoResult) {
      _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.succeed;
    } else {
      _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.failed;
    }
    return updateFeeInfoResult;
  }

  void _sortConfirmedUtxoList(UtxoOrder basis) {
    UtxoState.sortUtxo(_confirmedUtxoList, basis);
  }

  bool _updateFeeInfoEstimateFee() {
    for (var feeInfo in feeInfos) {
      try {
        var txBuildResult = _txBuilder.copyWith(feeRate: feeInfo.satsPerVb!).build();
        _initFeeInfo(feeInfo, txBuildResult.estimatedFee!);
      } catch (e) {
        Logger.error(e);
        return false;
      }
    }
    return true;
  }

  void saveSendInfo() {
    double finalAmount = _isMaxMode
        ? UnitUtil.convertSatoshiToBitcoin(_confirmedBalance - _estimatedFee!)
        : _sendInfoProvider.amount!;
    _sendInfoProvider.setAmount(finalAmount);
    _sendInfoProvider.setEstimatedFee(_estimatedFee!);
    _sendInfoProvider.setIsMaxMode(isMaxMode);
    _sendInfoProvider.setIsMultisig(_requiredSignature != null);
    _sendInfoProvider.setTransaction(_txBuilder.build().transaction!);
    _sendInfoProvider.setFeeBumpfingType(null);
    _sendInfoProvider.setWalletImportSource(_walletBaseItem.walletImportSource);
  }
}
