import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/fee_selection_screen.dart';
import 'package:coconut_wallet/screens/send/send_utxo_selection_screen.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
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
  late final UpbitConnectModel _upbitConnectModel;
  late final ConnectivityProvider _connectivityProvider;
  late int _sendAmount;
  late String _recipientAddress;
  late WalletBase _walletBase;
  Transaction? transaction;
  WalletListItemBase? _walletBaseItem;
  List<UTXO> _confirmedUtxoList = [];
  List<UTXO> _selectedUtxoList = [];
  RecommendedFeeFetchStatus _recommendedFeeFetchStatus =
      RecommendedFeeFetchStatus.fetching;
  TransactionFeeLevel? _selectedLevel = TransactionFeeLevel.halfhour;

  RecommendedFee? _recommendedFees;

  FeeInfo? _customFeeInfo;
  bool _isMaxMode = false;
  bool _isErrorInUpdateFeeInfoEstimateFee = false;
  String _errorString = '';
  int _confirmedBalance = 0;
  int? _estimatedFee = 0;
  int? _requiredSignature;
  int? _totalSigner;
  List<FeeInfoWithLevel> feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];

  String selectedUtxoTagName = '전체'; // 선택된 태그
  final Map<String, List<UtxoTag>> _utxoTagMap = {};
  SendUtxoSelectionViewModel(
      this._walletProvider,
      this._tagProvider,
      this._sendInfoProvider,
      this._upbitConnectModel,
      this._connectivityProvider,
      UtxoOrderEnum initialUtxoOrder) {
    _walletBaseItem =
        _walletProvider.getWalletById(_sendInfoProvider.walletId!);
    _requiredSignature =
        _walletBaseItem!.walletType == WalletType.multiSignature
            ? (_walletBaseItem as MultisigWalletListItem).requiredSignatureCount
            : null;
    _totalSigner = _walletBaseItem!.walletType == WalletType.multiSignature
        ? (_walletBaseItem as MultisigWalletListItem).signers.length
        : null;

    // TODO: 불필요한 if문인지 확인 필요
    if (_walletProvider.walletInitState == WalletInitState.finished) {
      _confirmedUtxoList =
          _getAllConfirmedUtxoList(_walletBaseItem!.walletFeature);
      UTXO.sortUTXO(_confirmedUtxoList, initialUtxoOrder);
      _initUtxoTagMap();
    } else {
      _confirmedUtxoList = _selectedUtxoList = [];
    }

    _walletBase = _walletBaseItem!.walletBase;
    _confirmedBalance = _walletBaseItem!.walletFeature.getBalance();
    _recipientAddress = _sendInfoProvider.recipientAddress!;
    _isMaxMode = _confirmedBalance ==
        UnitUtil.bitcoinToSatoshi(_sendInfoProvider.amount!);
    _sendAmount = _isMaxMode
        ? UnitUtil.bitcoinToSatoshi(
              _sendInfoProvider.amount!,
            ) -
            (_estimatedFee ?? 0)
        : UnitUtil.bitcoinToSatoshi(
            _sendInfoProvider.amount!,
          );
    transaction = _createTransaction(_isMaxMode, 1, _walletBase!);
    _syncSelectedUtxosWithTransaction();
    notifyListeners();
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

  int get sendAmount => _sendAmount;
  String get errorString => _errorString;
  int? get estimatedFee => _estimatedFee;
  String get estimatedFeeString => estimatedFee != null
      ? '${satoshiToBitcoinString(estimatedFee!).toString()} BTC'
      : '0 BTC';
  bool get isErrorInUpdateFeeInfoEstimateFee =>
      _isErrorInUpdateFeeInfoEstimateFee;
  bool get isMaxMode => _isMaxMode;
  bool get isUtxoTagListEmpty => _tagProvider.tagList.isEmpty;
  int get needAmount => _sendAmount + (_estimatedFee ?? 0);
  RecommendedFeeFetchStatus get recommendedFeeFetchStatus =>
      _recommendedFeeFetchStatus;
  RecommendedFee? get recommendedFees => _recommendedFees;

  int? get requiredSignature => _requiredSignature;

  int? get satsPerVb =>
      _selectedFeeInfoWithLevel?.satsPerVb ?? _customFeeInfo?.satsPerVb;

  TransactionFeeLevel? get selectedLevel => _selectedLevel;

  int get selectedUtxoAmountSum =>
      _calculateTotalAmountOfUtxoList(_selectedUtxoList);

  List<UTXO> get selectedUtxoList => _selectedUtxoList;

  String get sendAmountString =>
      '${satoshiToBitcoinString(_sendAmount).normalizeToFullCharacters()} BTC';

  SendInfoProvider get sendInfoProvider => _sendInfoProvider;

  UtxoTagProvider get tagProvider => _tagProvider;

  int? get totalSigner => _totalSigner;

  List<UtxoTag> get utxoTagList => _tagProvider.tagList;

  Map<String, List<UtxoTag>> get utxoTagMap => _utxoTagMap;

  WalletBase? get walletBase => _walletBase;

  WalletListItemBase? get walletBaseItem => _walletBaseItem;

  WalletProvider get walletProvider => _walletProvider;

  FeeInfoWithLevel? get _selectedFeeInfoWithLevel => _selectedLevel == null
      ? null
      : feeInfos.firstWhere((feeInfo) => feeInfo.level == _selectedLevel);

  bool get isNetworkOn => _connectivityProvider.isNetworkOn == true;

  void _initUtxoTagMap() {
    for (var (element) in _confirmedUtxoList) {
      final tags = _tagProvider.loadSelectedUtxoTagList(
          _sendInfoProvider.walletId!, element.utxoId);
      _utxoTagMap[element.utxoId] = tags;
    }
  }

  void addSelectedUtxoList(UTXO utxo) {
    _selectedUtxoList.add(utxo);
    notifyListeners();
  }

  int calculateTotalAmountOfUtxoList(List<UTXO> utxos) =>
      _calculateTotalAmountOfUtxoList(utxos);

  void clearUtxoList() {
    _selectedUtxoList = [];
    notifyListeners();
  }

  int estimateFee(int feeRate) {
    return transaction!.estimateFee(feeRate, _walletBase.addressType,
        requiredSignature: _requiredSignature, totalSinger: _totalSigner);
  }

  bool isSelectedUtxoEnough() => _isSelectedUtxoEnough();

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

  void setEstimatedFee(int value) {
    _estimatedFee = value;
    notifyListeners();
  }

  Future<void> setRecommendedFees() async {
    var recommendedFees = await fetchRecommendedFees(
        () => _walletProvider.getMinimumNetworkFeeRate());
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
      notifyListeners();
    }
  }

  // void updateProvider() async {
  //   try {
  //     final WalletListItemBase walletListItemBase =
  //         _walletProvider.getWalletById(_walletId);
  //     _walletAddress =
  //         walletListItemBase.walletBase.getReceiveAddress().address;

  //     /// 다음 Faucet 요청 수량 계산 1 -> 0.00021 -> 0.00021
  //     _requestCount = _faucetRecord.count;
  //     if (_requestCount == 0) {
  //       _requestAmount = _faucetMaxAmount;
  //     } else if (_requestCount <= 2) {
  //       _requestAmount = _faucetMinAmount;
  //     }
  //   } catch (e) {}

  //   notifyListeners();
  // }

  void setSelectedUtxoList(List<UTXO> utxoList) {
    _selectedUtxoList = utxoList;
    notifyListeners();
  }

  void setSelectedUtxoTagName(String value) {
    selectedUtxoTagName = value;
    notifyListeners();
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

  void updateFeeRate(int satsPerVb) {
    transaction!.updateFeeRate(satsPerVb, _walletBase!,
        requiredSignature: _requiredSignature, totalSinger: _totalSigner);
  }

  void updateSendInfoProvider() {
    _sendInfoProvider.setEstimatedFee(_estimatedFee!);
    _sendInfoProvider.setFeeRate(satsPerVb!);
    _sendInfoProvider.setIsMaxMode(isMaxMode);
    _sendInfoProvider.setIsMultisig(_requiredSignature != null);
    _sendInfoProvider.setTransaction(transaction!);
  }

  void updateUpbitConnectModel(UpbitConnectModel model) {
    _upbitConnectModel = model;
    notifyListeners();
  }

  int _calculateTotalAmountOfUtxoList(List<UTXO> utxos) {
    return utxos.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);
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
    feeInfo.fiatValue = _upbitConnectModel.bitcoinPriceKrw != null
        ? FiatUtil.calculateFiatAmount(
            estimatedFee, _upbitConnectModel.bitcoinPriceKrw!)
        : null;

    if (feeInfo is FeeInfoWithLevel && feeInfo.level == _selectedLevel) {
      _estimatedFee = estimatedFee;
      return;
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

  void deselectAllUtxo() {
    clearUtxoList();
    if (!_isMaxMode) {
      transaction = Transaction.fromUtxoList(
          [], _recipientAddress, _sendAmount, satsPerVb ?? 1, _walletBase);
    }
  }

  void selectAllUtxo() {
    setSelectedUtxoList(List.from(confirmedUtxoList));

    if (!isMaxMode) {
      transaction = Transaction.fromUtxoList(selectedUtxoList,
          _recipientAddress, _sendAmount, satsPerVb ?? 1, _walletBase);

      if (estimatedFee != null && isSelectedUtxoEnough()) {
        setEstimatedFee(estimateFee(satsPerVb ?? 1));
      }
    }
  }

  void toggleUtxoSelection(UTXO utxo) {
    if (selectedUtxoList.contains(utxo)) {
      if (!_isMaxMode) {
        transaction!.removeInputWithUtxo(utxo, satsPerVb ?? 1, _walletBase,
            requiredSignature: _requiredSignature, totalSinger: _totalSigner);
      }

      // 모두 선택 시 List.from 으로 전체 리스트, 필터 리스트 구분 될 때
      // 라이브러리 UTXO에 copyWith 구현 필요함
      final keyToRemove = '${utxo.transactionHash}_${utxo.index}';

      setSelectedUtxoList(selectedUtxoList
          .fold<Map<String, UTXO>>({}, (map, utxo) {
            final key = '${utxo.transactionHash}_${utxo.index}';
            if (key != keyToRemove) {
              // 제거할 키가 아니면 추가
              map[key] = utxo;
            }
            return map;
          })
          .values
          .toList());

      if (estimatedFee != null && _isSelectedUtxoEnough()) {
        setEstimatedFee(estimateFee(satsPerVb!));
      }
    } else {
      if (!_isMaxMode) {
        transaction!.addInputWithUtxo(utxo, satsPerVb ?? 1, _walletBase,
            requiredSignature: _requiredSignature, totalSinger: _totalSigner);
        setEstimatedFee(estimateFee(satsPerVb ?? 1));
      }
      selectedUtxoList.add(utxo);
    }
  }

  Future<Result<int, CoconutError>?> getMinimumFeeRateFromNetwork() async {
    return await _walletProvider.getMinimumNetworkFeeRate();
  }

  bool hasTaggedUtxo() {
    return _selectedUtxoList
        .any((utxo) => _utxoTagMap[utxo.utxoId]?.isNotEmpty == true);
  }

  void saveUsedUtxoIdsWhenTagged({required bool isTagsMoveAllowed}) {
    _tagProvider.saveUsedUtxoIdsIncludingTagged(
        _selectedUtxoList.map((utxo) => utxo.utxoId).toList(),
        isTagsMoveAllowed: isTagsMoveAllowed);
  }

  void changeUtxoOrder(UtxoOrderEnum orderEnum) async {
    UTXO.sortUTXO(_confirmedUtxoList, orderEnum);
    notifyListeners();
  }
}
