import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/send_utxo_selection_screen.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

typedef WalletInfoUpdateCallback = void Function(
  WalletListItemBase walletItem,
  List<UtxoState> selectedUtxoList,
  bool isUtxoSelectionAuto,
);

enum SendError {
  none,
  invalidAddress,
  noTestnetAddress,
  noMainnetAddress,
  noRegtestnetAddress,
  duplicatedAddress,
  insufficientBalance,
  minimumAmount;

  String getMessage(BitcoinUnit currentUnit) {
    switch (this) {
      case SendError.invalidAddress:
        return t.errors.address_error.invalid;
      case SendError.noTestnetAddress:
        return t.errors.address_error.not_for_testnet;
      case SendError.noMainnetAddress:
        return t.errors.address_error.not_for_mainnet;
      case SendError.noRegtestnetAddress:
        return t.errors.address_error.not_for_regtest;
      case SendError.duplicatedAddress:
        return t.errors.address_error.duplicated;
      case SendError.insufficientBalance:
        return t.errors.insufficient_balance;
      case SendError.minimumAmount:
        return t.alert.error_send.minimum_amount(
            bitcoin: currentUnit == BitcoinUnit.btc
                ? UnitUtil.convertSatoshiToBitcoin(dustLimit + 1)
                : (dustLimit + 1).toThousandsSeparatedString(),
            unit: currentUnit.symbol);
      case SendError.none:
      default:
        return "";
    }
  }

  bool get isError => this != SendError.none;
  bool get isNotError => this == SendError.none;
}

class SendViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;
  final SendInfoProvider _sendInfoProvider;
  final Function(String) _onAmountTextUpdate; // send_screen: _amountController

  bool _isMaxMode = false;
  bool get isMaxMode => _isMaxMode;

  // 수신자 정보
  late List<RecipientInfo> _recipientList;
  List<RecipientInfo> get recipientList => _recipientList;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  int get lastIndex => _recipientList.length - 1;

  bool _showAddressBoard = false;
  bool get showAddressBoard => _showAddressBoard;

  int _amountSum = 0;
  String get amountSumText => _currentUnit.displayBitcoinAmount(_amountSum, withUnit: true);

  late final List<WalletAddress> _walletAddressList;
  List<WalletAddress> get walletAddressList => _walletAddressList;

  WalletListItemBase? _selectedWalletItem;
  bool _isUtxoSelectionAuto = true;

  bool _isFeePaidByRecipients = false;
  bool get isFeePaidByRecipients => _isFeePaidByRecipients;

  List<UtxoState> _selectedUtxoList = [];
  List<UtxoState> get selectedUtxoList => _selectedUtxoList;
  int get selectedUtxoListLength => _selectedUtxoList.length;

  List<WalletListItemBase> get walletItemList => _walletProvider.walletItemListNotifier.value;
  WalletListItemBase? get selectedWalletItem => _selectedWalletItem;

  int get selectedWalletId => _selectedWalletItem != null ? _selectedWalletItem!.id : -1;
  bool get isUtxoSelectionAuto => _isUtxoSelectionAuto;

  RecommendedFeeFetchStatus _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.fetching;
  RecommendedFeeFetchStatus get recommendedFeeFetchStatus => _recommendedFeeFetchStatus;

  late bool? _isNetworkOn;
  late BitcoinUnit _currentUnit;
  late int _confirmedBalance;
  int selectedUtxoAmountSum = 0;

  int get balance => isUtxoSelectionAuto || selectedUtxoListLength == 0
      ? _confirmedBalance
      : selectedUtxoAmountSum;

  SendError _insufficientBalanceError = SendError.none;
  SendError _qrAddressError = SendError.none;

  bool _hasFinalError = true;
  bool get hasFinalError => _hasFinalError;

  String _finalErrorMessage = "";
  String get finalErrorMessage => _finalErrorMessage;

  bool get hasInsufficientBalanceError => _insufficientBalanceError.isError;
  String get qrErrorMessage => _qrAddressError.getMessage(_currentUnit);

  bool _showFeeBoard = false;
  bool get showFeeBoard => _showFeeBoard;

  bool get isBtcUnit => _currentUnit == BitcoinUnit.btc;
  BitcoinUnit get currentUnit => _currentUnit;
  bool get isSatsUnit => !isBtcUnit;

  bool get isNetworkOn => _isNetworkOn == true;
  num get dustLimitDenominator => (isBtcUnit ? 1e8 : 1);
  bool get isAmountDisabled => _isMaxMode && _currentIndex == lastIndex;

  SendViewModel(this._walletProvider, this._sendInfoProvider, this._isNetworkOn, this._currentUnit,
      this._onAmountTextUpdate, int walletId) {
    final walletIndex = _walletProvider.walletItemList.indexWhere((e) => e.id == walletId);
    _walletAddressList = _walletProvider.getReceiveAddresses();
    _recipientList = [RecipientInfo()];
    selectWalletItem(walletIndex);
    _initBalances();
  }

  /// UI State Management
  void setCurrentPage(int index) {
    if (_currentIndex == index) return;
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
    notifyListeners();
  }

  void setMaxMode(bool isEnabled) {
    if (_isMaxMode == isEnabled) return;
    _isMaxMode = isEnabled;

    // 최대 amount 설정
    if (_isMaxMode) {
      double amountSumExceptLast = 0;
      for (int i = 0; i < lastIndex; ++i) {
        if (_recipientList[i].amount.isNotEmpty) {
          amountSumExceptLast += double.parse(_recipientList[i].amount);
        }
      }

      int maxBalanceInSats = balance -
          (isBtcUnit ? UnitUtil.convertBitcoinToSatoshi(amountSumExceptLast) : amountSumExceptLast)
              .toInt();
      _recipientList[lastIndex].amount =
          (isBtcUnit ? UnitUtil.convertSatoshiToBitcoin(maxBalanceInSats) : maxBalanceInSats)
              .toString();
      _validateAmount(-1);
    }
    notifyListeners();
  }

  void onWalletInfoUpdated(
      WalletListItemBase walletItem, List<UtxoState> selectedUtxoList, bool isUtxoSelectionAuto) {
    _selectedWalletItem = walletItem;
    _sendInfoProvider.setWalletId(_selectedWalletItem!.id);
    _selectedUtxoList = selectedUtxoList;
    selectedUtxoAmountSum =
        _selectedUtxoList.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);
    _isUtxoSelectionAuto = isUtxoSelectionAuto;
    _initBalances();
    _validateAmount(-1);
    notifyListeners();
  }

  void selectWalletItem(int index) {
    final newWalletItem = _walletProvider.walletItemList[index];
    if (_selectedWalletItem != null && _selectedWalletItem!.id == newWalletItem.id) return;

    _selectedWalletItem = _walletProvider.walletItemList[index];
    _sendInfoProvider.setWalletId(_selectedWalletItem!.id);
    _selectedUtxoList = [];
    selectedUtxoAmountSum = 0;
    notifyListeners();
  }

  void addRecipient() {
    final newList = [..._recipientList, RecipientInfo(address: '', amount: '')];
    _recipientList = newList;
    _updateFinalError();
    notifyListeners();
  }

  void deleteRecipient() {
    _recipientList.removeAt(_currentIndex);
    _recipientList = [..._recipientList];
    if (_currentIndex - 1 >= 0) --_currentIndex;
    if (_recipientList.isEmpty) setMaxMode(false); // 수신자 추가할 수 있도록 최대 보내기 모드를 비활성화
    _validateAmount(-1);
    notifyListeners();
  }

  void _updateFeeBoardVisibility() {
    bool hasValidRecipient = _recipientList.any((e) =>
        e.address.isNotEmpty &&
        e.amount.isNotEmpty &&
        e.addressError.isNotError &&
        e.minimumAmountError.isNotError);
    _showFeeBoard = hasValidRecipient;
    notifyListeners();
  }

  void _setFinalErrorMessage(String message) {
    _finalErrorMessage = message;
    _hasFinalError = message.isNotEmpty;
    notifyListeners();
  }

  void _updateFinalError() {
    String message = "";
    // [전체] 충분하지 않은 Balance > [수신자] dust 보다 적은 금액을 보내는 경우 > [수신자] 주소가 틀림 > [수신자] 중복된 주소가 있는 경우 > [수신자] empty 값이 존재 > 수신자 0명인 경우
    if (_insufficientBalanceError.isError) {
      message = _insufficientBalanceError.getMessage(currentUnit);
    } else if (_recipientList.any((e) => e.minimumAmountError.isError)) {
      message = SendError.minimumAmount.getMessage(currentUnit);
    } else if (_recipientList.any((e) => e.addressError == SendError.invalidAddress)) {
      message = SendError.invalidAddress.getMessage(currentUnit);
    } else if (_recipientList.any((e) => e.addressError == SendError.duplicatedAddress)) {
      message = SendError.duplicatedAddress.getMessage(currentUnit);
    } else if (_recipientList.any((e) => e.address.isEmpty || e.amount.isEmpty)) {
      message = " ";
    } else if (_recipientList.isEmpty) {
      message = " ";
    }

    _setFinalErrorMessage(message);
    _updateFeeBoardVisibility();
  }

  void setAddressText(String text, int index) {
    final recipient = _recipientList[index];
    recipient.address = text;

    if (recipient.address.isEmpty) {
      _setAddressError(SendError.none, index);
    } else {
      validateAddress(recipient.address, index: index);
    }

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
      notifyListeners();
    } catch (e) {
      Logger.log(e);
    }
  }

  void setIsPaidByRecipients(bool isEnabled) {
    if (_isFeePaidByRecipients == isEnabled) return;
    _isFeePaidByRecipients = isEnabled;
    notifyListeners();
  }

  void onKeyTap(String newInput) {
    if (_currentIndex == _recipientList.length) return;
    final recipient = _recipientList[_currentIndex];
    if (newInput == ' ') return;
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
        /// 일반적인 경우 추가
        recipient.amount += newInput;
      }
    }

    _validateAmount(_currentIndex);
    notifyListeners();
  }

  void clearAmountText() {
    if (_currentIndex == _recipientList.length) return;
    _recipientList[_currentIndex].amount = "";
    _validateAmount(_currentIndex);
    notifyListeners();
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  void _initBalances() {
    List<UtxoState> utxos = _walletProvider.getUtxoList(_sendInfoProvider.walletId!);
    int unspentBalance = 0;
    for (UtxoState utxo in utxos) {
      if (utxo.status == UtxoStatus.unspent) {
        unspentBalance += utxo.amount;
      }
    }
    _confirmedBalance = unspentBalance;
  }

  void _validateAmount(int index) {
    // insufficientBalance 전체 범위 적용
    double amountSum = 0;
    for (final recipient in recipientList) {
      if (recipient.amount.isNotEmpty) amountSum += double.parse(recipient.amount);
    }

    if (amountSum > 0 && amountSum > balance / dustLimitDenominator) {
      _insufficientBalanceError = SendError.insufficientBalance;
    } else {
      _insufficientBalanceError = SendError.none;
    }

    if (_currentUnit == BitcoinUnit.btc) {
      _amountSum = UnitUtil.convertBitcoinToSatoshi(amountSum);
    } else {
      _amountSum = amountSum.toInt();
    }

    // minimumAmount 수신자 범위 적용
    if (index != -1) {
      final recipient = recipientList[index];
      if (recipient.amount.isNotEmpty && double.parse(recipient.amount) > 0) {
        if (double.parse(recipient.amount) <= dustLimit / dustLimitDenominator) {
          recipient.minimumAmountError = SendError.minimumAmount;
        } else {
          recipient.minimumAmountError = SendError.none;
        }
      } else {
        recipient.minimumAmountError = SendError.none;
      }
    }

    _updateFinalError();
    notifyListeners();
  }

  void _setAddressError(SendError error, int index) {
    if (index == -1) {
      _qrAddressError = error;
      return;
    }

    _recipientList[index].addressError = error;
    _updateFinalError();
    notifyListeners();
  }

  bool validateAddress(String recipient, {int index = -1}) {
    if (recipient.isEmpty) {
      _setAddressError(SendError.invalidAddress, index);
      return false;
    }

    final normalized = recipient.toLowerCase();

    // Bech32m(T2R) 주소 최대 62자
    if (normalized.length < 26 || normalized.length > 62) {
      _setAddressError(SendError.invalidAddress, index);
      return false;
    }

    if (NetworkType.currentNetworkType == NetworkType.testnet) {
      if (normalized.startsWith('1') ||
          normalized.startsWith('3') ||
          normalized.startsWith('bc1')) {
        _setAddressError(SendError.noTestnetAddress, index);
        return false;
      }
    } else if (NetworkType.currentNetworkType == NetworkType.mainnet) {
      if (normalized.startsWith('m') ||
          normalized.startsWith('n') ||
          normalized.startsWith('2') ||
          normalized.startsWith('tb1')) {
        _setAddressError(SendError.noMainnetAddress, index);
        return false;
      }
    } else if (NetworkType.currentNetworkType == NetworkType.regtest) {
      if (!normalized.startsWith('bcrt1')) {
        _setAddressError(SendError.noRegtestnetAddress, index);
        return false;
      }
    }

    bool result = false;
    try {
      final addressForValidation = _isBech32(normalized) ? normalized : recipient;
      result = WalletUtility.validateAddress(addressForValidation);
    } catch (e) {
      _setAddressError(SendError.invalidAddress, index);
      return false;
    }

    if (!result) {
      _setAddressError(SendError.invalidAddress, index);
      return false;
    }

    if (_recipientList.where((e) => e.address == recipient).length >= 2) {
      _setAddressError(SendError.duplicatedAddress, index);
      return false;
    }

    _setAddressError(SendError.none, index);
    return true;
  }

  bool _isBech32(String address) {
    final normalizedAddress = address.toLowerCase();
    return normalizedAddress.startsWith('bc1') ||
        normalizedAddress.startsWith('tb1') ||
        normalizedAddress.startsWith('bcrt1');
  }
}

class RecipientInfo {
  String address;
  String amount;
  SendError addressError; // 주소가 틀린 경우, 이전 주소와 중복된 경우
  SendError minimumAmountError; // 전송량이 적은 경우

  RecipientInfo(
      {this.address = '',
      this.amount = '',
      this.addressError = SendError.none,
      this.minimumAmountError = SendError.none});
}
