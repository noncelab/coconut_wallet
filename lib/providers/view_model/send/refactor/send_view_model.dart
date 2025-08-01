import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/extensions/double_extensions.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/send_utxo_selection_screen.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

typedef WalletInfoUpdateCallback = void Function(
  WalletListItemBase walletItem,
  List<UtxoState> selectedUtxoList,
  bool isUtxoSelectionAuto,
);

enum AddressError {
  none,
  invalid,
  invalidNetworkAddress,
  duplicated;

  bool get isError => this != AddressError.none;
  bool get isNotError => this == AddressError.none;

  String getMessage() {
    switch (this) {
      case AddressError.invalid:
        return t.errors.address_error.invalid;
      case AddressError.duplicated:
        return t.errors.address_error.duplicated;
      case AddressError.invalidNetworkAddress:
        {
          if (NetworkType.currentNetworkType == NetworkType.testnet) {
            return t.errors.address_error.not_for_testnet;
          } else if (NetworkType.currentNetworkType == NetworkType.mainnet) {
            return t.errors.address_error.not_for_mainnet;
          } else if (NetworkType.currentNetworkType == NetworkType.regtest) {
            return t.errors.address_error.not_for_regtest;
          } else {
            throw "Unknown network type";
          }
        }
      case AddressError.none:
      default:
        return "";
    }
  }
}

enum AmountError {
  none,
  insufficientBalance,
  minimumAmount;

  bool get isError => this != AmountError.none;
  bool get isNotError => this == AmountError.none;

  String getMessage(BitcoinUnit currentUnit) {
    switch (this) {
      case AmountError.insufficientBalance:
        return t.errors.insufficient_balance;
      case AmountError.minimumAmount:
        return t.alert.error_send.minimum_amount(
            bitcoin: currentUnit == BitcoinUnit.btc
                ? UnitUtil.convertSatoshiToBitcoin(dustLimit + 1)
                : (dustLimit + 1).toThousandsSeparatedString(),
            unit: currentUnit.symbol);
      case AmountError.none:
      default:
        return "";
    }
  }
}

class SendViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;
  final SendInfoProvider _sendInfoProvider;
  final NodeProvider _nodeProvider;

  // send_screen: _amountController, _feeRateController, _recipientPageController
  final Function(String) _onAmountTextUpdate;
  final Function(String) _onFeeRateTextUpdate;
  final Function(int) _onRecipientPageDeleted;

  bool _isMaxMode = false;
  bool get isMaxMode => _isMaxMode;
  bool get isBatchMode => recipientList.length >= 2;

  // 수신자 정보
  List<RecipientInfo> _recipientList = [];
  List<RecipientInfo> get recipientList => _recipientList;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  int get lastIndex => _recipientList.length - 1;

  bool _showAddressBoard = false;
  bool get showAddressBoard => _showAddressBoard;

  int _amountSum = 0;
  String get amountSumText => _currentUnit.displayBitcoinAmount(_amountSum, withUnit: true);

  List<bool> _walletAddressNeedsUpdate = [];
  Map<int, WalletAddress> _walletAddressMap = {};
  Map<int, WalletAddress> get walletAddressMap => _walletAddressMap;

  WalletListItemBase? _selectedWalletItem;
  bool _isUtxoSelectionAuto = true;

  bool _isFeeSubtractedFromSendAmount = false;
  bool _previousIsFeeSubtractedFromSendAmount = false;
  bool get isFeeSubtractedFromSendAmount => _isFeeSubtractedFromSendAmount;

  List<UtxoState> _selectedUtxoList = [];
  List<UtxoState> get selectedUtxoList => _selectedUtxoList;
  int get selectedUtxoListLength => _selectedUtxoList.length;

  List<WalletListItemBase> get walletItemList => _walletProvider.walletItemList;
  WalletListItemBase? get selectedWalletItem => _selectedWalletItem;

  int get selectedWalletId => _selectedWalletItem != null ? _selectedWalletItem!.id : -1;
  bool get isUtxoSelectionAuto => _isUtxoSelectionAuto;

  RecommendedFeeFetchStatus _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.fetching;
  RecommendedFeeFetchStatus get recommendedFeeFetchStatus => _recommendedFeeFetchStatus;

  List<FeeInfoWithLevel> feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];

  TransactionBuilder? _txBuilder;
  String _feeRateText = "";
  String _changeAddressDerivationPath = "";

  int? _estimatedFee;
  int? get estimatedFeeInSats => _estimatedFee;
  double get _estimatedFeeByUnit {
    int estimatedFeeInInt = _estimatedFee ?? 0;
    return isBtcUnit
        ? UnitUtil.convertSatoshiToBitcoin(estimatedFeeInInt)
        : estimatedFeeInInt.toDouble();
  }

  bool _isFeeRateLowerThanMin = false;

  double? _minimumFeeRate;
  double? get minimumFeeRate => _minimumFeeRate;

  late bool? _isNetworkOn;
  late BitcoinUnit _currentUnit;
  int _confirmedBalance = 0;
  int _incomingBalance = 0;
  int selectedUtxoAmountSum = 0;

  int get balance => isUtxoSelectionAuto || selectedUtxoListLength == 0
      ? _confirmedBalance
      : selectedUtxoAmountSum;
  int get incomingBalance => _incomingBalance;

  AmountError _isAmountSumExceedsBalance = AmountError.none;
  AmountError _isLastAmountInsufficient = AmountError.none;

  String _finalErrorMessage = "";
  String get finalErrorMessage => _finalErrorMessage;

  bool get isTotalSendAmountExceedsBalance => _isAmountSumExceedsBalance.isError;
  bool get isLastAmountInsufficient => _isLastAmountInsufficient.isError;

  bool _showFeeBoard = false;
  bool get showFeeBoard => _showFeeBoard;

  bool get isBtcUnit => _currentUnit == BitcoinUnit.btc;
  BitcoinUnit get currentUnit => _currentUnit;
  bool get isSatsUnit => !isBtcUnit;

  bool get isNetworkOn => _isNetworkOn == true;
  num get _dustLimitDenominator => (isBtcUnit ? 1e8 : 1);
  bool get isAmountDisabled => _isMaxMode && _currentIndex == lastIndex;
  bool get isEstimatedFeeGreaterThanBalance => balance < (_estimatedFee ?? 0);
  bool get hasValidRecipient => validRecipientList.isNotEmpty;

  int? _unintendedDustFee;
  int? get unintendedDustFee => _unintendedDustFee;

  List<RecipientInfo> get validRecipientList {
    return _recipientList
        .where((e) =>
            e.address.isNotEmpty &&
            e.amount.isNotEmpty &&
            e.addressError.isNotError &&
            e.minimumAmountError.isNotError)
        .toList();
  }

  Map<String, int> get recipientMap {
    final Map<String, int> recipientMap = {};
    for (final recipient in validRecipientList) {
      recipientMap[recipient.address] = (isBtcUnit
          ? UnitUtil.convertBitcoinToSatoshi(double.parse(recipient.amount))
          : int.parse(recipient.amount));
    }
    return recipientMap;
  }

  double get _amountSumExceptLast {
    double sumExceptLast = 0;
    for (int i = 0; i < lastIndex; ++i) {
      if (_recipientList[i].amount.isNotEmpty) {
        sumExceptLast += double.parse(_recipientList[i].amount);
      }
    }
    return sumExceptLast;
  }

  bool get isReadyToSend {
    if (_isAmountSumExceedsBalance.isError || _isLastAmountInsufficient.isError) {
      return false;
    }

    for (final recipient in _recipientList) {
      if (!recipient.isInputValid) {
        return false;
      }
    }

    return true;
  }

  bool isMaxModeIndex(int index) {
    return _isMaxMode && index == lastIndex;
  }

  bool isAmountInsufficient(int index) {
    if (index != lastIndex) return false;
    return _isMaxMode && _recipientList[index].amount == '0';
  }

  SendViewModel(
      this._walletProvider,
      this._sendInfoProvider,
      this._nodeProvider,
      this._isNetworkOn,
      this._currentUnit,
      this._onAmountTextUpdate,
      this._onFeeRateTextUpdate,
      this._onRecipientPageDeleted,
      int? walletId,
      SendEntryPoint sendEntryPoint) {
    _sendInfoProvider.clear();
    _sendInfoProvider.setSendEntryPoint(sendEntryPoint);

    if (walletId != null) {
      final walletIndex = _walletProvider.walletItemList.indexWhere((e) => e.id == walletId);
      if (walletIndex != -1) _initializeWithSelectedWallet(walletIndex);
    }

    _recipientList = [RecipientInfo()];
    _walletAddressMap = {};
    _initWalletAddressList();
    _initBalances();
    _setRecommendedFees();
  }

  void _initializeWithSelectedWallet(int index) {
    if (index == -1) return;
    if (_selectedWalletItem != null &&
        _selectedWalletItem!.id == _walletProvider.walletItemList[index].id) return;

    _selectedWalletItem = _walletProvider.walletItemList[index];
    _sendInfoProvider.setWalletId(_selectedWalletItem!.id);
    _changeAddressDerivationPath =
        _walletProvider.getChangeAddress(_selectedWalletItem!.id).derivationPath;

    // UTXO 자동 선택 모드이므로 전체 UTXO 리스트 설정
    _selectedUtxoList = _walletProvider.getUtxoList(_selectedWalletItem!.id);
    selectedUtxoAmountSum =
        _selectedUtxoList.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);
  }

  void _setEstimatedFee(int? estimatedFee) {
    if (_estimatedFee == estimatedFee) return;

    _estimatedFee = estimatedFee;

    if (_isMaxMode) {
      _adjustLastReceiverAmount();
    } else {
      _updateAmountValidationState();
    }
  }

  void _calculateEstimatedFee() {
    if (_selectedWalletItem == null ||
        !hasValidRecipient ||
        _feeRateText.isEmpty ||
        _feeRateText == "0" ||
        _changeAddressDerivationPath.isEmpty) {
      _setEstimatedFee(null);
      return;
    }

    final feeRate = double.parse(_feeRateText);
    _txBuilder = TransactionBuilder(
      availableUtxos: _selectedUtxoList,
      recipients: _getRecipientMapForTx(recipientMap),
      feeRate: feeRate,
      changeDerivationPath: _changeAddressDerivationPath,
      walletListItemBase: _selectedWalletItem!,
      isFeeSubtractedFromAmount: _isFeeSubtractedFromSendAmount,
      isUtxoFixed: !_isUtxoSelectionAuto,
    );

    var result = _txBuilder!.build();

    final estimatedFee = result.isSuccess
        ? result.transaction!.estimateFee(feeRate, _selectedWalletItem!.walletType.addressType,
            requiredSignature: _selectedWalletItem!.multisigConfig?.requiredSignature,
            totalSigner: _selectedWalletItem!.multisigConfig?.totalSigner)
        : result.estimatedFee;
    _setEstimatedFee(estimatedFee);

    final unintendedDustFee = result.isSuccess && estimatedFee < result.estimatedFee
        ? result.estimatedFee - estimatedFee
        : null;
    _setUnintendedDustFee(unintendedDustFee);

    //Logger.log(_txBuilder);
    //Logger.log(result);
  }

  void _setUnintendedDustFee(int? unintendedDustFee) {
    if (_unintendedDustFee == unintendedDustFee) return;
    _unintendedDustFee = unintendedDustFee;
    notifyListeners();
  }

  void _initWalletAddressList() {
    _walletAddressMap = _walletProvider.getReceiveAddressMap();
    _walletAddressNeedsUpdate = List.filled(_walletAddressMap.length, false);
  }

  void _updateWalletAddressList() {
    for (int i = 0; i < _walletAddressNeedsUpdate.length; ++i) {
      if (!_walletAddressNeedsUpdate[i]) continue;

      final walletListItem = _walletProvider.walletItemList[i];
      final nextAddressIndex = _walletAddressMap[walletListItem.id]!.index + 1;
      final walletAddress =
          _walletProvider.generateAddress(walletListItem.walletBase, nextAddressIndex, false);
      _walletAddressMap[walletListItem.id] = walletAddress;
      _walletAddressNeedsUpdate[i] = false;
    }

    notifyListeners();
  }

  void markWalletAddressForUpdate(int index) {
    _walletAddressNeedsUpdate[index] = true;
  }

  Future<bool> _setRecommendedFees() async {
    final recommendedFeesResult = await _nodeProvider
        .getRecommendedFees()
        .timeout(const Duration(seconds: 10), onTimeout: () {
      return Result.failure(
          const AppError('NodeProvider', "TimeoutException: Isolate response timeout"));
    });

    if (recommendedFeesResult.isFailure) {
      _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.failed;
      _onFeeRateTextUpdate('-');
      return false;
    }

    final recommendedFees = recommendedFeesResult.value;
    feeInfos[0].satsPerVb = recommendedFees.fastestFee.toDouble();
    feeInfos[1].satsPerVb = recommendedFees.halfHourFee.toDouble();
    feeInfos[2].satsPerVb = recommendedFees.hourFee.toDouble();
    _minimumFeeRate = recommendedFees.hourFee.toDouble();

    final defaultFeeRate = recommendedFees.halfHourFee.toString();
    _feeRateText = defaultFeeRate;
    _onFeeRateTextUpdate(defaultFeeRate);
    _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.succeed;
    return true;
  }

  void setCurrentPage(int index) {
    _currentIndex = index;

    // 수신자 추가가 표시되어 있으면 주소 보드를 닫는다.
    if (index == recipientList.length) {
      setShowAddressBoard(false);
    } else {
      _onAmountTextUpdate(recipientList[_currentIndex].amount);
    }
    notifyListeners();
  }

  void setShowAddressBoard(bool isEnabled) {
    if (_showAddressBoard == isEnabled) return;
    _showAddressBoard = isEnabled;
    if (_showAddressBoard) _updateWalletAddressList();
    notifyListeners();
  }

  void _adjustLastReceiverAmount({int? recipientIndex}) {
    double amountSumExceptLast = _amountSumExceptLast;
    int estimatedFeeInSats = _estimatedFee ?? 0;
    int maxBalanceInSats = balance -
        (isBtcUnit ? UnitUtil.convertBitcoinToSatoshi(amountSumExceptLast) : amountSumExceptLast)
            .toInt() -
        estimatedFeeInSats;
    _recipientList[lastIndex].amount = maxBalanceInSats > 0
        ? (isBtcUnit ? UnitUtil.convertSatoshiToBitcoin(maxBalanceInSats) : maxBalanceInSats)
            .toString()
        : "0";

    if (_currentIndex == lastIndex) {
      _onAmountTextUpdate(recipientList[lastIndex].amount);
    }

    _updateAmountValidationState(recipientIndex: recipientIndex);
  }

  void setMaxMode(bool isEnabled) {
    if (_isMaxMode == isEnabled) return;

    _isMaxMode = isEnabled;
    if (_isMaxMode) {
      _adjustLastReceiverAmount();
      _updateFeeBoardVisibility();
      _previousIsFeeSubtractedFromSendAmount = _isFeeSubtractedFromSendAmount;
      _isFeeSubtractedFromSendAmount = true;
    } else {
      _isFeeSubtractedFromSendAmount = _previousIsFeeSubtractedFromSendAmount;
    }

    _calculateEstimatedFee();
    _updateFinalErrorMessage();
    vibrateLight();
    notifyListeners();
  }

  void onWalletInfoUpdated(
      WalletListItemBase walletItem, List<UtxoState> selectedUtxoList, bool isUtxoSelectionAuto) {
    // 모두 보내기 모드 활성화 상태에서 지갑 변경시 모두 보내기 모드를 끄고 마지막 수신자 정보를 초기화
    if (_selectedWalletItem != null && _selectedWalletItem!.id != walletItem.id && _isMaxMode) {
      _recipientList[lastIndex].amount = "";
      setMaxMode(false);
      if (_currentIndex == lastIndex) {
        _onAmountTextUpdate(recipientList[lastIndex].amount);
      }
    }

    _selectedWalletItem = walletItem;
    _sendInfoProvider.setWalletId(_selectedWalletItem!.id);
    _isUtxoSelectionAuto = isUtxoSelectionAuto;
    _selectedUtxoList = selectedUtxoList;
    selectedUtxoAmountSum =
        _selectedUtxoList.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);
    _changeAddressDerivationPath =
        _walletProvider.getChangeAddress(_selectedWalletItem!.id).derivationPath;

    _initBalances();
    _updateAmountValidationState();
    _updateFeeBoardVisibility();
    _calculateEstimatedFee();
    notifyListeners();
  }

  void addRecipient() {
    final newList = [..._recipientList, RecipientInfo(address: '', amount: '')];
    _recipientList = newList;
    _updateFinalErrorMessage();
    vibrateLight();
    notifyListeners();
  }

  void deleteRecipient() {
    _recipientList.removeAt(_currentIndex);
    _recipientList = [..._recipientList];
    if (lastIndex >= 0) _currentIndex = lastIndex;
    setCurrentPage(_currentIndex);
    _onRecipientPageDeleted(_currentIndex);

    _calculateEstimatedFee();

    /// AddressError.duplicate였던 것을 해제
    checkAndSetDuplicationError();
    _updateAmountValidationState();
    vibrateLight();
    notifyListeners();
  }

  void _updateFeeBoardVisibility() {
    if (_showFeeBoard) return;

    _showFeeBoard = _isAmountSumExceedsBalance.isNotError && hasValidRecipient;
    if (_showFeeBoard) _calculateEstimatedFee();
    notifyListeners();
  }

  void _updateFinalErrorMessage() {
    String message = "";
    // [전체] 충분하지 않은 Balance > [마지막 수신자] 전송 금액 - 예상 수수료가 dustLimit보다 크지 않음 > [수신자] dust 보다 적은 금액을 보내는 경우 > [수신자] 주소가 틀림 > [수신자] 중복된 주소가 있는 경우 > [수신자] empty 값 또는 0이 존재 > 예상 수수료 오류
    if (_isAmountSumExceedsBalance.isError) {
      message = _isAmountSumExceedsBalance.getMessage(currentUnit);
    } else if (_recipientList.any((r) => r.minimumAmountError.isError)) {
      message = AmountError.minimumAmount.getMessage(currentUnit);
    } else if (_isLastAmountInsufficient.isError) {
      message = _isLastAmountInsufficient.getMessage(currentUnit);
    } else if (_recipientList.any((r) => r.addressError.isError)) {
      int addressErrorIndex = _recipientList.indexWhere((r) => r.addressError.isError);
      if (addressErrorIndex != -1) {
        message = _recipientList[addressErrorIndex].addressError.getMessage();
      }
    } else if (_isFeeRateLowerThanMin) {
      message = t.toast.min_fee(minimum: _minimumFeeRate ?? 0);
    }

    _finalErrorMessage = message;
    notifyListeners();
  }

  void checkAndSetDuplicationError() {
    // 주소별 갯수 집계
    final Map<String, int> addressCount = {};
    for (final recipient in _recipientList) {
      if (recipient.address.isEmpty) continue;
      addressCount[recipient.address] = (addressCount[recipient.address] ?? 0) + 1;
    }

    for (int i = 0; i < _recipientList.length; i++) {
      final recipient = _recipientList[i];
      if (recipient.address.isEmpty) continue;
      if (recipient.addressError != AddressError.none &&
          recipient.addressError != AddressError.duplicated) {
        // 중복 오류가 아닌 다른 오류는 건드리지 않음
        continue;
      }

      if (addressCount[recipient.address]! >= 2) {
        // 중복인 경우 duplicated 오류 설정
        _setAddressError(AddressError.duplicated, i);
      } else {
        // 더 이상 중복이 아니면 오류 해제
        _setAddressError(AddressError.none, i);
      }
    }
  }

  void setAddressText(String text, int recipientIndex) {
    if (_recipientList[recipientIndex].address == text) return;
    _recipientList[recipientIndex].address = text;
    validateAddress(text, recipientIndex);
    checkAndSetDuplicationError();
    _calculateEstimatedFee();
    _updateFeeBoardVisibility();
    notifyListeners();
  }

  void setFeeRateText(String feeRate) {
    _feeRateText = feeRate;

    try {
      var feeRateValue = double.parse(feeRate);
      _isFeeRateLowerThanMin = _minimumFeeRate != null && feeRateValue < _minimumFeeRate!;
    } catch (e) {
      Logger.error(e);
      _isFeeRateLowerThanMin = false;
    }

    _calculateEstimatedFee();
    notifyListeners();
  }

  void toggleUnit() {
    // 너무 큰 수가 입력된 경우: Positive input exceeds the limit of integer
    try {
      _currentUnit = isBtcUnit ? BitcoinUnit.sats : BitcoinUnit.btc;
      for (RecipientInfo recipient in recipientList) {
        if (recipient.amount.isNotEmpty && recipient.amount != '0' && recipient.amount != '0.0') {
          recipient.amount = (isBtcUnit
                  ? UnitUtil.convertSatoshiToBitcoin(int.parse(recipient.amount))
                  : UnitUtil.convertBitcoinToSatoshi(double.parse(recipient.amount)))
              .toString();

          // sats to btc 변환에서 지수로 표현되는 경우에는 다시 변환한다.
          if (recipient.amount.contains('e')) {
            recipient.amount = double.parse(recipient.amount).toStringAsFixed(8);
          }
        }
      }

      if (currentIndex != recipientList.length) {
        _onAmountTextUpdate(recipientList[_currentIndex].amount);
      }

      vibrateLight();
      notifyListeners();
    } catch (e) {
      Logger.error(e);
    }
  }

  void setIsFeeSubtractedFromSendAmount(bool isEnabled) {
    if (_isFeeSubtractedFromSendAmount == isEnabled) return;
    _isFeeSubtractedFromSendAmount = isEnabled;
    _calculateEstimatedFee();
    notifyListeners();
  }

  void onKeyTap(String newInput) {
    if (_currentIndex == _recipientList.length) return;
    if (isSatsUnit && newInput == '.') return;

    final recipient = _recipientList[_currentIndex];
    if (newInput == '<') {
      if (recipient.amount.isNotEmpty) {
        recipient.amount = recipient.amount.substring(0, recipient.amount.length - 1);
      }
    } else if (newInput == '.') {
      if (recipient.amount.isEmpty) {
        recipient.amount = '0.';
      } else {
        if (!recipient.amount.contains('.')) {
          recipient.amount += newInput;
        }
      }
    } else {
      if (recipient.amount.isEmpty) {
        /// 첫 입력이 0인 경우는 바로 추가
        if (newInput == '0') {
          recipient.amount += newInput;
        } else if (newInput != '0' || recipient.amount.contains('.')) {
          recipient.amount += newInput;
        }
      } else if (recipient.amount == '0' && newInput != '.') {
        /// 첫 입력이 0이고, 그 후 0이 아닌 숫자가 올 경우에는 기존 0을 대체
        recipient.amount = newInput;
      } else if (recipient.amount.contains('.')) {
        /// 소수점 이후 숫자가 8자리 이하인 경우 추가
        int decimalIndex = recipient.amount.indexOf('.');
        if (recipient.amount.length - decimalIndex <= 8) {
          recipient.amount += newInput;
        }
      } else {
        /// 자연수인 경우 BTC 8자리 제한, sats 16자리 제한
        if (recipient.amount.length < (isBtcUnit ? 8 : 16)) {
          recipient.amount += newInput;
        }
      }
    }

    if (_isMaxMode) {
      _adjustLastReceiverAmount(recipientIndex: _currentIndex);
    } else {
      _updateAmountValidationState(recipientIndex: _currentIndex);
    }

    _calculateEstimatedFee();
    _updateFeeBoardVisibility();
    notifyListeners();
  }

  void clearAmountText() {
    if (_currentIndex == _recipientList.length) return;
    _recipientList[_currentIndex].amount = "";
    _updateAmountValidationState(recipientIndex: _currentIndex);
    notifyListeners();
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  void _initBalances() {
    if (_selectedWalletItem == null) {
      _confirmedBalance = 0;
      _incomingBalance = 0;
      return;
    }

    List<UtxoState> utxos = _walletProvider.getUtxoList(_selectedWalletItem!.id);
    int unspentBalance = 0, incomingBalance = 0;
    for (UtxoState utxo in utxos) {
      if (utxo.status == UtxoStatus.unspent) {
        unspentBalance += utxo.amount;
      } else if (utxo.status == UtxoStatus.incoming) {
        incomingBalance += utxo.amount;
      }
    }

    _confirmedBalance = unspentBalance;
    _incomingBalance = incomingBalance;
  }

  void _updateAmountSum() {
    double amountSum = recipientList
        .where((r) => r.amount.isNotEmpty)
        .fold(0, (sum, r) => sum + double.parse(r.amount));
    _amountSum = isBtcUnit ? UnitUtil.convertBitcoinToSatoshi(amountSum) : amountSum.toInt();

    _updateIsAmountSumExceedsBalance(amountSum);
    notifyListeners();
  }

  void _updateIsAmountSumExceedsBalance(double amountSum) {
    double total = _isFeeSubtractedFromSendAmount ? amountSum : amountSum + _estimatedFeeByUnit;
    _isAmountSumExceedsBalance = total > 0 && total > balance / _dustLimitDenominator
        ? AmountError.insufficientBalance
        : AmountError.none;
  }

  void _validateOneAmount(int recipientIndex) {
    assert(recipientIndex != -1);
    final recipient = recipientList[recipientIndex];
    if (recipient.amount.isNotEmpty && double.parse(recipient.amount) > 0) {
      if (double.parse(recipient.amount) <= dustLimit / _dustLimitDenominator) {
        recipient.minimumAmountError = AmountError.minimumAmount;
      } else {
        recipient.minimumAmountError = AmountError.none;
      }
    } else {
      recipient.minimumAmountError = AmountError.none;
    }
  }

  // 마지막 수신자의 전송 금액을 확인한다. (전송 금액 - 예상 수수료 <= dust)
  // _isFeeSubtractedFromSendAmount가 true일 때만 체크되어야 함
  void _updateLastAmountErrorIfInsufficient() {
    if (!_isFeeSubtractedFromSendAmount) {
      if (_isLastAmountInsufficient.isError) {
        _isLastAmountInsufficient = AmountError.none;
      }
      return;
    }

    if (_recipientList[lastIndex].amount.isNotEmpty) {
      double amount = double.parse(_recipientList[lastIndex].amount);
      int estimatedFeeInSats = _estimatedFee ?? 0;
      bool isAmountInsufficientForFee =
          (isBtcUnit ? UnitUtil.convertBitcoinToSatoshi(amount) : amount).toInt() -
                  estimatedFeeInSats <=
              dustLimit;

      _isLastAmountInsufficient =
          isAmountInsufficientForFee ? AmountError.insufficientBalance : AmountError.none;
      Logger.log("_insufficientBalanceErrorOfLastRecipient: $_isLastAmountInsufficient");
    }
  }

  void _updateAmountValidationState({int? recipientIndex}) {
    _updateAmountSum();
    if (recipientIndex != null) {
      _validateOneAmount(recipientIndex);
    }
    _updateLastAmountErrorIfInsufficient();

    _updateFinalErrorMessage();
    notifyListeners();
  }

  void _setAddressError(AddressError error, int index) {
    if (_recipientList[index].addressError != error) {
      _recipientList[index].addressError = error;
      _updateFinalErrorMessage();
      notifyListeners();
    }
  }

  AddressValidationError? validateScannedAddress(String address) {
    return AddressValidator.validateAddress(address, NetworkType.currentNetworkType);
  }

  bool validateAddress(String address, int recipientIndex) {
    AddressValidationError? error =
        AddressValidator.validateAddress(address, NetworkType.currentNetworkType);

    switch (error) {
      case AddressValidationError.noTestnetAddress:
      case AddressValidationError.noMainnetAddress:
      case AddressValidationError.noRegtestnetAddress:
        _setAddressError(AddressError.invalidNetworkAddress, recipientIndex);
        return false;
      case AddressValidationError.minimumLength:
      case AddressValidationError.unknown:
        _setAddressError(AddressError.invalid, recipientIndex);
        return false;
      case AddressValidationError.empty:
      default:
        break;
    }

    _setAddressError(AddressError.none, recipientIndex);
    return true;
  }

  Map<String, int> _getRecipientMapForTx(Map<String, int> map) {
    if (!_isMaxMode) return map;
    // 모두 보내기 상황에서 마지막 수신자의 amount에 수수료를 제하지 않은 상태로 반환한다. (트랜잭션 처리를 위해)
    double amountSumExceptLast = _amountSumExceptLast;
    int maxBalanceInSats = balance -
        (isBtcUnit ? UnitUtil.convertBitcoinToSatoshi(amountSumExceptLast) : amountSumExceptLast)
            .toInt();
    String lastRecipientAddress = _recipientList[lastIndex].address;
    map[lastRecipientAddress] = maxBalanceInSats;
    return map;
  }

  void saveSendInfo() {
    final recipientMapInBtc =
        recipientMap.map((key, value) => MapEntry(key, UnitUtil.convertSatoshiToBitcoin(value)));

    // 모두 보내기 모드가 아니고 수수료 수신자 부담 옵션을 활성화한 경우, 마지막 수신자의 amount에서 수수료를 뺀다. (보기용)
    if (!_isMaxMode && _isFeeSubtractedFromSendAmount) {
      String lastRecipientAddress = _recipientList[lastIndex].address;
      recipientMapInBtc[lastRecipientAddress] = (recipientMapInBtc[lastRecipientAddress]! -
              UnitUtil.convertSatoshiToBitcoin(estimatedFeeInSats!))
          .roundTo8Digits();
    }

    // 이전에 사용한 정보 초기화
    _sendInfoProvider.setRecipientsForBatch(null);
    _sendInfoProvider.setRecipientAddress(null);
    _sendInfoProvider.setAmount(null);

    if (isBatchMode) {
      _sendInfoProvider.setRecipientsForBatch(recipientMapInBtc);
    } else {
      final firstEntry = recipientMapInBtc.entries.first;
      _sendInfoProvider.setRecipientAddress(firstEntry.key);
      _sendInfoProvider.setAmount(firstEntry.value);
    }

    var result = _txBuilder!.build();
    _sendInfoProvider.setTransaction(result.transaction!);
    _sendInfoProvider.setIsMultisig(_selectedWalletItem!.walletType == WalletType.multiSignature);
    _sendInfoProvider.setWalletImportSource(_selectedWalletItem!.walletImportSource);
  }
}

class RecipientInfo {
  String address;
  String amount;
  AddressError addressError;
  AmountError minimumAmountError; // 전송량이 적은 경우

  RecipientInfo(
      {this.address = '',
      this.amount = '',
      this.addressError = AddressError.none,
      this.minimumAmountError = AmountError.none});

  bool get isInputValid {
    final amountDecimal = Decimal.tryParse(amount);
    return address.trim().isNotEmpty &&
        amount.trim().isNotEmpty &&
        amountDecimal != null &&
        amountDecimal != Decimal.zero &&
        addressError.isNotError &&
        minimumAmountError.isNotError;
  }
}
