import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/app/send/fee_info.dart';
import 'package:coconut_wallet/model/app/send/send_info.dart';
import 'package:coconut_wallet/model/app/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/app/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/app/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/screens/send/fee_selection_screen.dart';
import 'package:coconut_wallet/screens/send/send_utxo_selection_screen.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/recommended_fee_util.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';
import 'package:flutter/material.dart';

class SendUtxoSelectionViewModel extends ChangeNotifier {
  /// Common variables ---------------------------------------------------------
  final AppStateModel _appStateModel;
  UpbitConnectModel _upbitConnectModel;
  AppStateModel get appStateModel => _appStateModel;
  UpbitConnectModel get upbitConnectModel => _upbitConnectModel;

  /// Wallet variables ---------------------------------------------------------
  int id;
  SendInfo sendInfo;
  WalletBase? _walletBase;
  Transaction? transaction;
  WalletListItemBase? _walletBaseItem;

  WalletBase? get walletBase => _walletBase;
  WalletListItemBase? get walletBaseItem => _walletBaseItem;

  /// View variables ---------------------------------------------------------
  List<UTXO> _confirmedUtxoList = [];
  List<UTXO> _selectedUtxoList = [];
  RecommendedFeeFetchStatus _recommendedFeeFetchStatus =
      RecommendedFeeFetchStatus.fetching;
  TransactionFeeLevel? _selectedLevel = TransactionFeeLevel.halfhour;
  RecommendedFee? _recommendedFees;
  UtxoOrderEnum _selectedUtxoOrder = UtxoOrderEnum.byTimestampDesc; // 초기 정렬 방식
  FeeInfo? _customFeeInfo;
  bool _isMaxMode = false;
  bool _isErrorInUpdateFeeInfoEstimateFee = false;
  String _errorString = '';
  int _confirmedBalance = 0;
  int? _estimatedFee = 0;
  int? _requiredSignature;
  int? _totalSigner;

  RecommendedFeeFetchStatus get recommendedFeeFetchStatus =>
      _recommendedFeeFetchStatus;
  TransactionFeeLevel? get selectedLevel => _selectedLevel;
  RecommendedFee? get recommendedFees => _recommendedFees;
  UtxoOrderEnum get selectedUtxoOrder => _selectedUtxoOrder;
  FeeInfo? get customFeeInfo => _customFeeInfo;
  List<UTXO> get confirmedUtxoList => _confirmedUtxoList;
  List<UTXO> get selectedUtxoList => _selectedUtxoList;
  String get errorString => _errorString;
  bool get isErrorInUpdateFeeInfoEstimateFee =>
      _isErrorInUpdateFeeInfoEstimateFee;
  bool get isMaxMode => _isMaxMode;
  int? get estimatedFee => _estimatedFee;
  int? get requiredSignature => _requiredSignature;
  int? get totalSigner => _totalSigner;
  int get confirmedBalance => _confirmedBalance;

  List<FeeInfoWithLevel> feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];

  void setSelectedUtxoList(List<UTXO> utxoList) {
    _selectedUtxoList = utxoList;
    notifyListeners();
  }

  void addSelectedUtxoList(UTXO utxo) {
    _selectedUtxoList.add(utxo);
    notifyListeners();
  }

  void setEstimatedFee(int value) {
    _estimatedFee = value;
    notifyListeners();
  }

  void setSelectedUtxoOrder(UtxoOrderEnum value) {
    _selectedUtxoOrder = value;
    notifyListeners();
  }

  void setSelectedUtxoTagName(String value) {
    selectedUtxoTagName = value;
    notifyListeners();
  }

  /// Tag variables ---------------------------------------------------------
  String selectedUtxoTagName = '전체'; // 선택된 태그

  final Map<String, List<UtxoTag>> _utxoTagMap = {};
  Map<String, List<UtxoTag>> get utxoTagMap => _utxoTagMap;

  SendUtxoSelectionViewModel(
    this._appStateModel,
    this._upbitConnectModel,
    this.id,
    this.sendInfo,
  ) {
    _initialize(id);
  }

  /// 초기화
  void _initialize(int id) {
    _walletBaseItem = _appStateModel.getWalletById(id);
    _requiredSignature =
        _walletBaseItem!.walletType == WalletType.multiSignature
            ? (_walletBaseItem as MultisigWalletListItem).requiredSignatureCount
            : null;
    _totalSigner = _walletBaseItem!.walletType == WalletType.multiSignature
        ? (_walletBaseItem as MultisigWalletListItem).signers.length
        : null;

    if (_appStateModel.walletInitState == WalletInitState.finished) {
      _confirmedUtxoList =
          _getAllConfirmedUtxoList(_walletBaseItem!.walletFeature);
      UTXO.sortUTXO(_confirmedUtxoList, selectedUtxoOrder);
      addDisplayUtxoList();
    } else {
      _confirmedUtxoList = _selectedUtxoList = [];
    }

    if (_walletBaseItem!.walletType == WalletType.multiSignature) {
      _walletBase = (_walletBaseItem! as MultisigWalletListItem).walletBase;
      _confirmedBalance = (_walletBase as MultisignatureWallet).getBalance();
    } else {
      _walletBase = (_walletBaseItem as SinglesigWalletListItem).walletBase;
      _confirmedBalance = (_walletBase as SingleSignatureWallet).getBalance();
    }

    _isMaxMode =
        _confirmedBalance == UnitUtil.bitcoinToSatoshi(sendInfo.amount);
    transaction = _createTransaction(_isMaxMode, 1, _walletBase!);
    _syncSelectedUtxosWithTransaction();
    notifyListeners();
  }

  void updateUpbitConnectModel(UpbitConnectModel model) {
    _upbitConnectModel = model;
    notifyListeners();
  }

  List<UTXO> _getAllConfirmedUtxoList(WalletFeature wallet) {
    return wallet.walletStatus!.utxoList
        .where((utxo) => utxo.blockHeight != 0)
        .toList();
  }

  void addDisplayUtxoList() {
    _utxoTagMap.clear();
    for (var (element) in _confirmedUtxoList) {
      final tags =
          _appStateModel.loadUtxoTagListByTxHashIndex(id, element.utxoId);
      _utxoTagMap[element.utxoId] = tags;
    }
    notifyListeners();
  }

  Transaction _createTransaction(
      bool isMaxMode, int feeRate, WalletBase walletBase) {
    if (isMaxMode) {
      return Transaction.forSweep(sendInfo.address, feeRate, walletBase);
    }

    try {
      return Transaction.forPayment(sendInfo.address,
          UnitUtil.bitcoinToSatoshi(sendInfo.amount), feeRate, walletBase);
    } catch (e) {
      if (e.toString().contains('Not enough amount for sending. (Fee')) {
        return Transaction.forSweep(sendInfo.address, feeRate, walletBase);
      }

      rethrow;
    }
  }

  void _syncSelectedUtxosWithTransaction() {
    var inputs = transaction!.inputs;
    List<UTXO> result = [];
    for (int i = 0; i < inputs.length; i++) {
      result.add(_confirmedUtxoList.firstWhere((utxo) =>
          utxo.transactionHash == inputs[i].transactionHash &&
          utxo.index == inputs[i].index));
    }
    _selectedUtxoList = result;
    notifyListeners();
  }

  void initUtxoTagScreenTagData() {
    _appStateModel.initUtxoTagScreenTagData(id);
  }

  int _calculateTotalAmountOfUtxoList(List<UTXO> utxos) {
    return utxos.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);
  }

  int calculateTotalAmountOfUtxoList(List<UTXO> utxos) =>
      _calculateTotalAmountOfUtxoList(utxos);

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

  int get needAmount => sendAmount + (_estimatedFee ?? 0);

  int get selectedUtxoAmountSum =>
      _calculateTotalAmountOfUtxoList(_selectedUtxoList);

  int get sendAmount {
    return _isMaxMode
        ? UnitUtil.bitcoinToSatoshi(
              sendInfo.amount,
            ) -
            (_estimatedFee ?? 0)
        : UnitUtil.bitcoinToSatoshi(
            sendInfo.amount,
          );
  }

  Future<void> setRecommendedFees() async {
    var recommendedFees = await fetchRecommendedFees(_appStateModel);
    if (recommendedFees == null) {
      _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.failed;
      notifyListeners();
      return;
    }

    feeInfos[0].satsPerVb = recommendedFees.fastestFee;
    feeInfos[1].satsPerVb = recommendedFees.halfHourFee;
    feeInfos[2].satsPerVb = recommendedFees.hourFee;

    var result = updateFeeInfoEstimateFee();
    if (result) {
      _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.succeed;
      notifyListeners();
    } else {
      _isErrorInUpdateFeeInfoEstimateFee = true;
      // notifyListeners();
    }
  }

  bool updateFeeInfoEstimateFee() {
    for (var feeInfo in feeInfos) {
      try {
        int estimatedFee = estimateFee(feeInfo.satsPerVb!);
        _initFeeInfo(feeInfo, estimatedFee);
        notifyListeners();
      } catch (e) {
        _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.failed;
        // 수수료 조회 실패 알림
        _errorString = e.toString();
        // notifyListeners();
        return false;
      }
    }
    return true;
  }

  int estimateFee(int feeRate) {
    return transaction!.estimateFee(feeRate, _walletBase!.addressType,
        requiredSignature: _requiredSignature, totalSinger: _totalSigner);
  }

  void _initFeeInfo(FeeInfo feeInfo, int estimatedFee) {
    feeInfo.estimatedFee = estimatedFee;
    feeInfo.fiatValue = _upbitConnectModel.bitcoinPriceKrw != null
        ? FiatUtil.calculateFiatAmount(
            estimatedFee, _upbitConnectModel.bitcoinPriceKrw!)
        : null;

    if (feeInfo is FeeInfoWithLevel && feeInfo.level == _selectedLevel) {
      _estimatedFee = estimatedFee;
      return;
    }
  }

  int? get change {
    if (_recommendedFeeFetchStatus == RecommendedFeeFetchStatus.fetching) {
      return null;
    }

    if (_recommendedFeeFetchStatus == RecommendedFeeFetchStatus.failed &&
        _customFeeInfo == null) {
      return null;
    }

    var change = transaction!.getChangeAmount(_walletBase!.addressBook);
    if (change != 0) return change;
    if (_estimatedFee == null) return null;
    // utxo가 모자랄 때도 change = 0으로 반환되기 때문에 진짜 잔돈이 0인지 아닌지 확인이 필요
    if (_confirmedBalance < needAmount) {
      return _confirmedBalance - needAmount;
    }

    return _isSelectedUtxoEnough() ? change : null;
  }

  bool get customFeeSelected => _selectedLevel == null;

  int? get satsPerVb =>
      _selectedFeeInfoWithLevel?.satsPerVb ?? _customFeeInfo?.satsPerVb;

  FeeInfoWithLevel? get _selectedFeeInfoWithLevel => _selectedLevel == null
      ? null
      : feeInfos.firstWhere((feeInfo) => feeInfo.level == _selectedLevel);

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

  bool isSelectedUtxoEnough() => _isSelectedUtxoEnough();

  bool get isUtxoTagListEmpty => _appStateModel.utxoTagList.isEmpty;

  List<UtxoTag> get utxoTagList => _appStateModel.utxoTagList;

  void onFeeRateChanged(Map<String, dynamic> feeSelectionResult) {
    _estimatedFee =
        (feeSelectionResult[FeeSelectionScreen.feeInfoField] as FeeInfo)
            .estimatedFee;
    _selectedLevel = feeSelectionResult[FeeSelectionScreen.selectedOptionField];
    notifyListeners();

    _customFeeInfo =
        feeSelectionResult[FeeSelectionScreen.selectedOptionField] == null
            ? (feeSelectionResult[FeeSelectionScreen.feeInfoField] as FeeInfo)
            : null;

    var satsPerVb = _customFeeInfo?.satsPerVb! ??
        feeInfos
            .firstWhere((feeInfo) => feeInfo.level == _selectedLevel)
            .satsPerVb!;
    updateFeeRate(satsPerVb);
  }

  void updateFeeRate(int satsPerVb) {
    transaction!.updateFeeRate(satsPerVb, _walletBase!,
        requiredSignature: _requiredSignature, totalSinger: _totalSigner);
  }

  void clearUtxoList() {
    _selectedUtxoList = [];
    notifyListeners();
  }
}
