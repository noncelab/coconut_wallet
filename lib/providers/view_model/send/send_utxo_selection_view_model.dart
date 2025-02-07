import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/fee_selection_screen.dart';
import 'package:coconut_wallet/screens/send/send_utxo_selection_screen.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/recommended_fee_util.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';
import 'package:flutter/material.dart';

enum ErrorState {
  insufficientBalance('잔액이 부족하여 수수료를 낼 수 없어요'),
  failedToFetchRecommendedFee(
      '추천 수수료를 조회하지 못했어요.\n\'변경\'버튼을 눌러서 수수료를 직접 입력해 주세요.'),
  insufficientUtxo('UTXO 합계가 모자라요');

  final String displayMessage;

  const ErrorState(this.displayMessage);
}

class SendUtxoSelectionViewModel extends ChangeNotifier {
  late final WalletProvider _walletProvider;
  late final UtxoTagProvider _tagProvider;
  late final SendInfoProvider _sendInfoProvider;
  late final ConnectivityProvider _connectivityProvider;
  late int? _bitcoinPriceKrw;
  late int _sendAmount;
  late String _recipientAddress;
  late WalletBase _walletBase;
  late bool _isMaxMode;
  late Transaction _transaction;
  late int? _requiredSignature;
  late int? _totalSigner;
  late WalletListItemBase _walletBaseItem;

  List<UTXO> _confirmedUtxoList = [];
  List<UTXO> _selectedUtxoList = [];
  RecommendedFeeFetchStatus _recommendedFeeFetchStatus =
      RecommendedFeeFetchStatus.fetching;
  TransactionFeeLevel? _selectedLevel = TransactionFeeLevel.halfhour;

  RecommendedFee? _recommendedFees;

  FeeInfo? _customFeeInfo;
  int _confirmedBalance = 0;
  int? _estimatedFee = 0;

  List<FeeInfoWithLevel> feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];

  String selectedUtxoTagName = '전체'; // 선택된 태그
  final Map<String, List<UtxoTag>> _utxoTagMap = {};
  int? _cachedSelectedUtxoAmountSum; // 계산식 수행 반복을 방지하기 위해 추가

  SendUtxoSelectionViewModel(
      this._walletProvider,
      this._tagProvider,
      this._sendInfoProvider,
      this._connectivityProvider,
      this._bitcoinPriceKrw,
      UtxoOrderEnum initialUtxoOrder) {
    _walletBaseItem =
        _walletProvider.getWalletById(_sendInfoProvider.walletId!);
    _requiredSignature = _walletBaseItem.walletType == WalletType.multiSignature
        ? (_walletBaseItem as MultisigWalletListItem).requiredSignatureCount
        : null;
    _totalSigner = _walletBaseItem.walletType == WalletType.multiSignature
        ? (_walletBaseItem as MultisigWalletListItem).signers.length
        : null;

    _confirmedUtxoList =
        _getAllConfirmedUtxoList(_walletBaseItem.walletFeature);
    _sortConfirmedUtxoList(initialUtxoOrder);
    _initUtxoTagMap();

    _walletBase = _walletBaseItem.walletBase;
    _confirmedBalance = _walletBaseItem.walletFeature.getBalance();
    _recipientAddress = _sendInfoProvider.recipientAddress!;
    _isMaxMode = _confirmedBalance ==
        UnitUtil.bitcoinToSatoshi(_sendInfoProvider.amount!);
    _setAmount();

    _transaction = _createTransaction(_isMaxMode, 1, _walletBase);
    _syncSelectedUtxosWithTransaction();

    _setRecommendedFees().then((bool result) async {
      if (result) {
        _updateFeeRateOfTransaction(satsPerVb!);
        _setAmount();
      }
      notifyListeners();
    });
  }

  int? get change {
    if (_recommendedFeeFetchStatus == RecommendedFeeFetchStatus.fetching) {
      return null;
    }

    if (_recommendedFeeFetchStatus == RecommendedFeeFetchStatus.failed &&
        _customFeeInfo == null) {
      return null;
    }

    var change = _transaction.getChangeAmount(_walletBase.addressBook);
    if (change != 0) return change;
    if (_estimatedFee == null) return null;
    // utxo가 모자랄 때도 change = 0으로 반환되기 때문에 진짜 잔돈이 0인지 아닌지 확인이 필요
    if (_confirmedBalance < needAmount) {
      return _confirmedBalance - needAmount;
    }

    return _isSelectedUtxoEnough() ? change : null;
  }

  int get confirmedBalance => _confirmedBalance;
  List<UTXO> get confirmedUtxoList => _confirmedUtxoList;
  FeeInfo? get customFeeInfo => _customFeeInfo;
  bool get customFeeSelected => _selectedLevel == null;
  ErrorState? get errorState {
    if (_estimatedFee == null) {
      return null;
    }

    if (_confirmedBalance < needAmount) {
      return ErrorState.insufficientBalance;
    }

    if (_recommendedFeeFetchStatus == RecommendedFeeFetchStatus.failed &&
        _customFeeInfo == null) {
      return ErrorState.failedToFetchRecommendedFee;
    }

    if (selectedUtxoAmountSum < needAmount) {
      return ErrorState.insufficientUtxo;
    }

    return null;
  }

  int? get bitcoinPriceKrw => _bitcoinPriceKrw;
  int? get estimatedFee => _estimatedFee;
  bool get isMaxMode => _isMaxMode;
  bool get isUtxoTagListEmpty => _tagProvider.tagList.isEmpty;
  int get needAmount => _sendAmount + (_estimatedFee ?? 0);
  RecommendedFeeFetchStatus get recommendedFeeFetchStatus =>
      _recommendedFeeFetchStatus;
  RecommendedFee? get recommendedFees => _recommendedFees;
  int? get satsPerVb {
    if (_selectedLevel == null) {
      return _customFeeInfo?.satsPerVb;
    }

    return feeInfos
        .firstWhere((feeInfo) => feeInfo.level == _selectedLevel)
        .satsPerVb;
  }

  TransactionFeeLevel? get selectedLevel => _selectedLevel;
  int get selectedUtxoAmountSum {
    _cachedSelectedUtxoAmountSum ??=
        _calculateTotalAmountOfUtxoList(_selectedUtxoList);
    return _cachedSelectedUtxoAmountSum!;
  }

  List<UTXO> get selectedUtxoList => _selectedUtxoList;

  int get sendAmount => _sendAmount;

  List<UtxoTag> get utxoTagList => _tagProvider.tagList;

  Map<String, List<UtxoTag>> get utxoTagMap => _utxoTagMap;

  void addSelectedUtxoList(UTXO utxo) {
    _selectedUtxoList.add(utxo);
    _cachedSelectedUtxoAmountSum = null;
    notifyListeners();
  }

  void changeUtxoOrder(UtxoOrderEnum orderEnum) async {
    _sortConfirmedUtxoList(orderEnum);
    notifyListeners();
  }

  // TODO: 추후 반환 타입 변경
  void checkGoingNextAvailable() {
    if (_connectivityProvider.isNetworkOn != true) {
      throw ErrorCodes.networkError.message;
    }

    _updateSendInfoProvider();
  }

  void deselectAllUtxo() {
    _clearUtxoList();
    if (!_isMaxMode) {
      _transaction = Transaction.fromUtxoList(
          [], _recipientAddress, _sendAmount, satsPerVb ?? 1, _walletBase);
    }
  }

  int estimateFee(int feeRate) {
    return _transaction.estimateFee(feeRate, _walletBase.addressType,
        requiredSignature: _requiredSignature, totalSinger: _totalSigner);
  }

  Future<Result<int, CoconutError>?> getMinimumFeeRateFromNetwork() async {
    return await _walletProvider.getMinimumNetworkFeeRate();
  }

  bool hasTaggedUtxo() {
    return _selectedUtxoList
        .any((utxo) => _utxoTagMap[utxo.utxoId]?.isNotEmpty == true);
  }

  bool isSelectedUtxoEnough() => _isSelectedUtxoEnough();

  void onFeeRateChanged(Map<String, dynamic> feeSelectionResult) {
    _estimatedFee =
        (feeSelectionResult[FeeSelectionScreen.feeInfoField] as FeeInfo)
            .estimatedFee;
    _selectedLevel = feeSelectionResult[FeeSelectionScreen.selectedOptionField];
    _setAmount();
    notifyListeners();

    _customFeeInfo =
        feeSelectionResult[FeeSelectionScreen.selectedOptionField] == null
            ? (feeSelectionResult[FeeSelectionScreen.feeInfoField] as FeeInfo)
            : null;

    var satsPerVb = _customFeeInfo?.satsPerVb! ??
        feeInfos
            .firstWhere((feeInfo) => feeInfo.level == _selectedLevel)
            .satsPerVb!;
    _updateFeeRateOfTransaction(satsPerVb);
  }

  void _setAmount() {
    _sendAmount = _isMaxMode
        ? UnitUtil.bitcoinToSatoshi(
              _sendInfoProvider.amount!,
            ) -
            (_estimatedFee ?? 0)
        : UnitUtil.bitcoinToSatoshi(
            _sendInfoProvider.amount!,
          );
  }

  void saveUsedUtxoIdsWhenTagged({required bool isTagsMoveAllowed}) {
    _tagProvider.cacheUsedUtxoIds(
        _selectedUtxoList.map((utxo) => utxo.utxoId).toList(),
        isTagsMoveAllowed: isTagsMoveAllowed);
  }

  void selectAllUtxo() {
    setSelectedUtxoList(List.from(confirmedUtxoList));

    if (!isMaxMode) {
      _transaction = Transaction.fromUtxoList(selectedUtxoList,
          _recipientAddress, _sendAmount, satsPerVb ?? 1, _walletBase);

      if (estimatedFee != null && isSelectedUtxoEnough()) {
        setEstimatedFee(estimateFee(satsPerVb ?? 1));
      }
    }
  }

  void setEstimatedFee(int value) {
    _estimatedFee = value;
    notifyListeners();
  }

  void setSelectedUtxoList(List<UTXO> utxoList) {
    _selectedUtxoList = utxoList;
    _cachedSelectedUtxoAmountSum = null;
    notifyListeners();
  }

  void setSelectedUtxoTagName(String value) {
    selectedUtxoTagName = value;
    notifyListeners();
  }

  void toggleUtxoSelection(UTXO utxo) {
    _cachedSelectedUtxoAmountSum = null;
    if (selectedUtxoList.contains(utxo)) {
      if (!_isMaxMode) {
        _transaction.removeInputWithUtxo(utxo, satsPerVb ?? 1, _walletBase,
            requiredSignature: _requiredSignature, totalSinger: _totalSigner);
      }

      selectedUtxoList.remove(utxo);
      if (estimatedFee != null && _isSelectedUtxoEnough()) {
        setEstimatedFee(estimateFee(satsPerVb!));
      }
    } else {
      if (!_isMaxMode) {
        _transaction.addInputWithUtxo(utxo, satsPerVb ?? 1, _walletBase,
            requiredSignature: _requiredSignature, totalSinger: _totalSigner);
        setEstimatedFee(estimateFee(satsPerVb ?? 1));
      }
      selectedUtxoList.add(utxo);
    }
    notifyListeners();
  }

  int _calculateTotalAmountOfUtxoList(List<UTXO> utxos) {
    return utxos.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);
  }

  void _clearUtxoList() {
    _selectedUtxoList = [];
    _cachedSelectedUtxoAmountSum = 0;
    notifyListeners();
  }

  Transaction _createTransaction(
      bool isMaxMode, int feeRate, WalletBase walletBase) {
    if (isMaxMode) {
      return Transaction.forSweep(
          _sendInfoProvider.recipientAddress!, feeRate, walletBase);
    }

    try {
      return Transaction.forPayment(
          _sendInfoProvider.recipientAddress!,
          UnitUtil.bitcoinToSatoshi(_sendInfoProvider.amount!),
          feeRate,
          walletBase);
    } catch (e) {
      if (e.toString().contains('Not enough amount for sending. (Fee')) {
        return Transaction.forSweep(
            _sendInfoProvider.recipientAddress!, feeRate, walletBase);
      }

      rethrow;
    }
  }

  List<UTXO> _getAllConfirmedUtxoList(WalletFeature wallet) {
    return wallet.walletStatus!.utxoList
        .where((utxo) => utxo.blockHeight != 0)
        .toList();
  }

  void _initFeeInfo(FeeInfo feeInfo, int estimatedFee) {
    feeInfo.estimatedFee = estimatedFee;
    feeInfo.fiatValue = _bitcoinPriceKrw != null
        ? FiatUtil.calculateFiatAmount(estimatedFee, _bitcoinPriceKrw!)
        : null;

    if (feeInfo is FeeInfoWithLevel && feeInfo.level == _selectedLevel) {
      _estimatedFee = estimatedFee;
      return;
    }
  }

  void _initUtxoTagMap() {
    for (var (element) in _confirmedUtxoList) {
      final tags = _tagProvider.loadSelectedUtxoTagList(
          _sendInfoProvider.walletId!, element.utxoId);
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

  Future<bool> _setRecommendedFees() async {
    var recommendedFees = await fetchRecommendedFees(
        () => _walletProvider.getMinimumNetworkFeeRate());

    if (recommendedFees == null) {
      _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.failed;
      return false;
    }

    feeInfos[0].satsPerVb = recommendedFees.fastestFee;
    feeInfos[1].satsPerVb = recommendedFees.halfHourFee;
    feeInfos[2].satsPerVb = recommendedFees.hourFee;

    var result = _updateFeeInfoEstimateFee();
    if (result) {
      _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.succeed;
    } else {
      _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.failed;
    }
    return result;
  }

  void _syncSelectedUtxosWithTransaction() {
    var inputs = _transaction.inputs;
    List<UTXO> result = [];
    for (int i = 0; i < inputs.length; i++) {
      result.add(_confirmedUtxoList.firstWhere((utxo) =>
          utxo.transactionHash == inputs[i].transactionHash &&
          utxo.index == inputs[i].index));
    }
    _selectedUtxoList = result;
    notifyListeners();
  }

  bool _updateFeeInfoEstimateFee() {
    for (var feeInfo in feeInfos) {
      try {
        int estimatedFee = estimateFee(feeInfo.satsPerVb!);
        _initFeeInfo(feeInfo, estimatedFee);
        //notifyListeners();
      } catch (e) {
        Logger.error(e);
        return false;
      }
    }
    return true;
  }

  void _updateFeeRateOfTransaction(int satsPerVb) {
    _transaction.updateFeeRate(satsPerVb, _walletBase,
        requiredSignature: _requiredSignature, totalSinger: _totalSigner);
  }

  void _updateSendInfoProvider() {
    _sendInfoProvider.setEstimatedFee(_estimatedFee!);
    _sendInfoProvider.setFeeRate(satsPerVb!);
    _sendInfoProvider.setIsMaxMode(isMaxMode);
    _sendInfoProvider.setIsMultisig(_requiredSignature != null);
    _sendInfoProvider.setTransaction(_transaction);
  }

  void updateBitcoinPriceKrw(int btcPriceInKrw) {
    _bitcoinPriceKrw = btcPriceInKrw;
    notifyListeners();
  }

  void _sortConfirmedUtxoList(UtxoOrderEnum basis) {
    if (basis == UtxoOrderEnum.byAmountDesc) {
      _confirmedUtxoList.sort((a, b) {
        if (b.amount != a.amount) {
          return b.amount.compareTo(a.amount);
        }

        return a.timestamp.compareTo(b.timestamp);
      });
    } else {
      UTXO.sortUTXO(_confirmedUtxoList, basis);
    }
  }
}
