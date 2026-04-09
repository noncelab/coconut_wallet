import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/core/transaction/utxo_split_transaction_builder.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/utils/fee_rate_mixin.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:flutter/material.dart';

enum SplitErrorType { none, feeExceedsAmount, dust }

enum SplitCriteria {
  byAmount,
  evenly,
  manually;

  String getLabel(Translations t) {
    switch (this) {
      case SplitCriteria.byAmount:
        return t.split_utxo_screen.criteria_bottom_sheet.split_by_amount;
      case SplitCriteria.evenly:
        return t.split_utxo_screen.criteria_bottom_sheet.split_evenly;
      case SplitCriteria.manually:
        return t.split_utxo_screen.criteria_bottom_sheet.split_manually;
    }
  }
}

class SplitUtxoViewModel extends ChangeNotifier with FeeRateMixin {
  static const List<double> _niceNumbers = [
    0.0001,
    0.0002,
    0.0005,
    0.001,
    0.002,
    0.005,
    0.01,
    0.02,
    0.05,
    0.1,
    0.2,
    0.5,
    1.0,
    2.0,
    5.0,
    10.0,
    20.0,
    50.0,
  ];

  final int walletId;
  final PreferenceProvider _preferenceProvider;
  final WalletProvider _walletProvider;
  final AddressRepository _addressRepository;
  final SendInfoProvider _sendInfoProvider;

  // State
  List<UtxoState> _selectedUtxoList = [];
  SplitCriteria? _selectedCriteria;

  final TextEditingController amountController = TextEditingController();
  final FocusNode amountFocusNode = FocusNode();
  final TextEditingController feeRateController = TextEditingController();
  final FocusNode feeRateFocusNode = FocusNode();
  final TextEditingController splitCountController = TextEditingController();
  final FocusNode splitCountFocusNode = FocusNode();

  int? _estimatedFeeSats;
  bool _isDustError = false;
  bool _isFeeExceedsAmountError = false;
  String _finalErrorMessage = "";
  bool _isBuilding = false;

  // --- UI Getter ---
  int? get estimatedFeeSats => _estimatedFeeSats;
  String get finalErrorMessage => _finalErrorMessage;
  bool get isDustError => _isDustError;
  bool get isFeeExceedsAmountError => _isFeeExceedsAmountError;
  bool get isBuilding => _isBuilding;
  List<UtxoState> get selectedUtxoList => _selectedUtxoList;
  SplitCriteria? get selectedCriteria => _selectedCriteria;
  bool get isUtxoSelected => _selectedUtxoList.isNotEmpty;
  bool get hasFeeRate => feeRateController.text.isNotEmpty;
  BitcoinUnit get currentUnit => _preferenceProvider.currentUnit;
  int get _selectedUtxoAmount => _selectedUtxoList.isNotEmpty ? _selectedUtxoList.first.amount : 0;
  String get _splitAmountInput => amountController.text.replaceAll(',', '').trim();

  int get splitCount {
    final count = int.tryParse(splitCountController.text.trim()) ?? 0;
    return count;
  }

  List<double> get recommendedSplitAmounts {
    if (_selectedUtxoAmount <= 0) return [];

    final validAmounts =
        _niceNumbers.where((btc) {
          final sats = (btc * 1e8).toInt();
          return sats < _selectedUtxoAmount;
        }).toList();

    if (validAmounts.length <= 6) return validAmounts;
    return validAmounts.sublist(validAmounts.length - 6);
  }

  List<int> get recommendedSplitCounts {
    if (_selectedUtxoAmount <= 0) return [];

    final Set<int> counts = {};

    for (final btc in _niceNumbers.reversed) {
      final targetSats = (btc * 1e8).toInt();
      final count = (_selectedUtxoAmount / targetSats).round();
      if (count >= 2) {
        counts.add(count);
      }
      if (counts.length >= 5) break;
    }

    final sortedCounts = counts.toList()..sort();
    return sortedCounts;
  }

  // --- Initialization ---
  SplitUtxoViewModel(
    this.walletId,
    this._preferenceProvider,
    this._walletProvider,
    this._addressRepository,
    this._sendInfoProvider,
  ) {
    amountController.addListener(_onInputChanged);
    feeRateController.addListener(_onInputChanged);
    amountFocusNode.addListener(notifyListeners);
    feeRateFocusNode.addListener(notifyListeners);
    splitCountController.addListener(_onInputChanged);
    splitCountFocusNode.addListener(notifyListeners);

    refreshRecommendedFees();
  }

  // --- UI Text Getter ---
  String get estimatedFeeText {
    if (_estimatedFeeSats == null || _estimatedFeeSats! <= 0) return '-';
    return currentUnit.displayBitcoinAmount(_estimatedFeeSats, withUnit: true);
  }

  String get splitText {
    if (_selectedCriteria == null || _selectedUtxoList.isEmpty) return '';
    final utxoAmountText = currentUnit.displayBitcoinAmount(_selectedUtxoAmount, withUnit: true);

    if (_selectedCriteria == SplitCriteria.byAmount) {
      final formattedSplitAmount = currentUnit.displayBitcoinAmount(splitAmountSats, withUnit: true);
      return t.split_utxo_screen.expected_result.split_by_amount(
        utxoAmountText: utxoAmountText,
        formattedSplitAmount: formattedSplitAmount,
      );
    } else if (_selectedCriteria == SplitCriteria.evenly) {
      return t.split_utxo_screen.expected_result.split_evenly(utxoAmountText: utxoAmountText, splitCount: splitCount);
    } else {
      return '-';
    }
  }

  String get newUtxoResultText {
    if (_selectedCriteria == null || _selectedUtxoList.isEmpty) return '-';

    if (_selectedCriteria == SplitCriteria.byAmount && splitAmountSats > 0) {
      final maxCount = _availableAmountForSplit ~/ splitAmountSats;
      if (maxCount > 0) {
        final formattedSplitAmount = currentUnit.displayBitcoinAmount(splitAmountSats, withUnit: true);
        return '$maxCount × $formattedSplitAmount';
      }
    }

    if (_selectedCriteria == SplitCriteria.evenly && splitCount >= 2 && _estimatedFeeSats != null) {
      final baseAmount = _availableAmountForSplit ~/ splitCount;
      if (baseAmount > 0) {
        final remainder = _availableAmountForSplit % splitCount;
        final formattedBaseAmount = currentUnit.displayBitcoinAmount(baseAmount, withUnit: true);
        if (remainder == 0) {
          return '$splitCount × $formattedBaseAmount';
        } else {
          final formattedExtraAmount = currentUnit.displayBitcoinAmount(baseAmount + 1, withUnit: true);
          return '${splitCount - remainder} × $formattedBaseAmount\n$remainder × $formattedExtraAmount';
        }
      }
    }
    return '-';
  }

  String get remainderText {
    if (_selectedCriteria == null || _selectedUtxoList.isEmpty) return '';

    if (_selectedCriteria == SplitCriteria.byAmount && splitAmountSats > 0) {
      final maxCount = _availableAmountForSplit ~/ splitAmountSats;
      if (maxCount > 0) {
        final remainderSats = _availableAmountForSplit % splitAmountSats;
        if (remainderSats > 0) {
          final formattedRemainder = currentUnit.displayBitcoinAmount(remainderSats, withUnit: true);
          return '+ $formattedRemainder';
        }
      }
    }
    return '';
  }

  String? get amountErrorText {
    if (_selectedUtxoList.isEmpty) return null;
    if (_splitAmountInput.isEmpty) return null;

    if (splitAmountSats >= _selectedUtxoAmount) {
      return t.split_utxo_screen.amount_error.amount_too_large;
    }

    if (_isFeeExceedsAmountError) {
      return t.split_utxo_screen.amount_error.insufficient_after_fee;
    }

    return null;
  }

  int get splitAmountSats {
    if (_splitAmountInput.isEmpty) return 0;
    final splitAmountDouble = double.tryParse(_splitAmountInput) ?? 0.0;
    return currentUnit.toSatoshi(splitAmountDouble);
  }

  void _onInputChanged() {
    _updateEstimatedFee();
    notifyListeners();
  }

  void _updateEstimatedFee() {
    _isDustError = false;
    _isFeeExceedsAmountError = false;

    bool isInputValid = true;
    if (_selectedCriteria == null || _selectedUtxoList.isEmpty || hasAmountError) {
      isInputValid = false;
    } else if (_selectedCriteria == SplitCriteria.byAmount) {
      isInputValid = splitAmountSats > 0 && splitAmountSats < _selectedUtxoAmount;
    } else if (_selectedCriteria == SplitCriteria.evenly) {
      isInputValid = splitCount >= 2;
    }

    if (!isInputValid) {
      _estimatedFeeSats = null;
      return;
    }

    final feeRateText = feeRateController.text;
    final feeRate = double.tryParse(feeRateText) ?? 0.0;

    if (feeRate <= 0) {
      _estimatedFeeSats = null;
      return;
    }

    final utxo = _selectedUtxoList.first;

    final walletItem = _walletProvider.getWalletById(walletId);

    if (_selectedCriteria == SplitCriteria.byAmount) {
      final result = _estimateFeeForFixedAmountSplit(utxo, walletItem, splitAmountSats, feeRate);
      _estimatedFeeSats = result.$1;
      if (result.$2 == SplitErrorType.dust) {
        _isDustError = true;
      } else if (result.$2 == SplitErrorType.feeExceedsAmount) {
        _isFeeExceedsAmountError = true;
      }
    } else if (_selectedCriteria == SplitCriteria.evenly) {
      final result = _estimateFeeForEqualSplit(utxo, walletItem, splitCount, feeRate);
      _estimatedFeeSats = result.$1;
      if (result.$2 == SplitErrorType.dust) {
        _isDustError = true;
      } else if (result.$2 == SplitErrorType.feeExceedsAmount) {
        _isFeeExceedsAmountError = true;
      }
    } else {
      _estimatedFeeSats = null;
    }
  }

  (int?, SplitErrorType) _estimateFeeForFixedAmountSplit(
    UtxoState utxo,
    WalletListItemBase walletItem,
    int amountPerOutput,
    double feeRate,
  ) {
    if (amountPerOutput <= dustLimit) return (null, SplitErrorType.dust);

    final double oneOutputTxVBytes = _getTxVBytes(walletItem, 1, 1);
    final double twoOutputTxVBytes = _getTxVBytes(walletItem, 1, 2);
    final double outputVBytes = twoOutputTxVBytes - oneOutputTxVBytes;

    final feePerOutput = outputVBytes * feeRate;
    double firstLeft = utxo.amount - (oneOutputTxVBytes * feeRate) - amountPerOutput;

    if (firstLeft <= dustLimit + feePerOutput) {
      final fee = (twoOutputTxVBytes * feeRate).ceil();
      return (fee, SplitErrorType.feeExceedsAmount);
    }

    var neededSatsPerOneMore = amountPerOutput + feePerOutput;
    double left = firstLeft;
    int count = 1;

    while (left - neededSatsPerOneMore > dustLimit + feePerOutput) {
      if (count + 1 == 253) {
        // VarInt threshold
        if (left - (2 * feeRate) - neededSatsPerOneMore <= dustLimit + feePerOutput) break;
        left -= (2 * feeRate);
      }
      left -= neededSatsPerOneMore;
      count++;
    }

    int totalOutputCount = count + 1; // +1 for sweep output
    double exactVBytes = _getTxVBytes(walletItem, 1, totalOutputCount);
    int fee = (exactVBytes * feeRate).ceil();

    // TransactionBuilder fallback 시뮬레이션
    int sweepAmount = utxo.amount - (count * amountPerOutput) - fee;
    if (sweepAmount <= dustLimit && count > 1) {
      count--;
      totalOutputCount = count + 1;
      exactVBytes = _getTxVBytes(walletItem, 1, totalOutputCount);
      fee = (exactVBytes * feeRate).ceil();
      sweepAmount = utxo.amount - (count * amountPerOutput) - fee;
    }

    // 실제 Transaction 빌더와 오차를 없애기 위한 정밀 계산 (Iteration)
    try {
      Set<int> feeSet = {fee};
      for (int i = 0; i < 10; i++) {
        final tx = Transaction.withInputsAndOutputs(
          [TransactionInput.forPayment(utxo.transactionHash, utxo.index)],
          List.generate(totalOutputCount, (index) {
            return TransactionOutput.forPayment(
              index < count ? amountPerOutput : sweepAmount,
              utxo.to,
              isChangeOutput: index == totalOutputCount - 1,
            );
          }),
          walletItem.walletType.addressType,
        );

        final realEstimatedFee = _getRealTxFee(tx, feeRate, walletItem);

        if (fee != realEstimatedFee) {
          if (feeSet.contains(realEstimatedFee)) break;
          feeSet.add(realEstimatedFee);

          fee = realEstimatedFee;
          sweepAmount = utxo.amount - (count * amountPerOutput) - fee;

          if (sweepAmount <= dustLimit && count > 1) {
            count--;
            totalOutputCount = count + 1;
            exactVBytes = _getTxVBytes(walletItem, 1, totalOutputCount);
            fee = (exactVBytes * feeRate).ceil();
            sweepAmount = utxo.amount - (count * amountPerOutput) - fee;
            feeSet = {fee};
          }
          continue;
        }
        break;
      }
    } catch (e) {
      // 무시하고 기본 계산값 사용
    }

    return (fee, SplitErrorType.none);
  }

  (int?, SplitErrorType) _estimateFeeForEqualSplit(
    UtxoState utxo,
    WalletListItemBase walletItem,
    int splitCount,
    double feeRate,
  ) {
    if (splitCount < 2) return (null, SplitErrorType.none);

    final double exactVBytes = _getTxVBytes(walletItem, 1, splitCount);
    int fee = (exactVBytes * feeRate).ceil();

    if (fee >= utxo.amount) return (fee, SplitErrorType.feeExceedsAmount);

    int availableAmount = utxo.amount - fee;
    final int baseAmount = availableAmount ~/ splitCount;
    if (baseAmount <= dustLimit) return (fee, SplitErrorType.dust);

    // 실제 Transaction 빌더와 오차를 없애기 위한 정밀 계산 (Iteration)
    try {
      Set<int> feeSet = {fee};
      for (int i = 0; i < 10; i++) {
        int remainder = availableAmount % splitCount;
        final tx = Transaction.withInputsAndOutputs(
          [TransactionInput.forPayment(utxo.transactionHash, utxo.index)],
          List.generate(splitCount, (index) {
            return TransactionOutput.forPayment(
              index < (splitCount - remainder) ? baseAmount : baseAmount + 1,
              utxo.to,
              isChangeOutput: index == splitCount - 1,
            );
          }),
          walletItem.walletType.addressType,
        );

        final realEstimatedFee = _getRealTxFee(tx, feeRate, walletItem);

        if (fee != realEstimatedFee) {
          if (feeSet.contains(realEstimatedFee)) break;
          feeSet.add(realEstimatedFee);

          fee = realEstimatedFee;
          availableAmount = utxo.amount - fee;
          int newBaseAmount = availableAmount ~/ splitCount;

          if (newBaseAmount <= dustLimit) return (fee, SplitErrorType.dust);
          continue;
        }
        break;
      }
    } catch (e) {
      // 무시하고 기본 계산값 사용
    }

    return (fee, SplitErrorType.none);
  }

  int get _availableAmountForSplit {
    final amount = _selectedUtxoAmount - (_estimatedFeeSats ?? 0);
    return amount > 0 ? amount : 0;
  }

  // --- Validation ---
  bool get hasAmountError {
    if (_selectedUtxoList.isEmpty) return false;
    return _selectedUtxoAmount >= 1000 && _selectedUtxoAmount < 20000;
  }

  bool get hasAmountWarning {
    if (_selectedUtxoList.isEmpty) return false;
    return _selectedUtxoAmount >= 20000 && _selectedUtxoAmount < 50000;
  }

  bool get isSplitValid {
    if (_selectedCriteria == null || _selectedUtxoList.isEmpty) return false;
    if (hasAmountError) return false;

    if (_isDustError || _isFeeExceedsAmountError) return false;

    if (_selectedCriteria == SplitCriteria.byAmount) {
      if (splitAmountSats <= 0) return false;
      if (splitAmountSats >= _selectedUtxoAmount) return false;
      if (_estimatedFeeSats == null) return false;
    } else if (_selectedCriteria == SplitCriteria.evenly) {
      if (splitCount < 2) return false;
      if (_estimatedFeeSats == null) return false;
    }
    return true;
  }

  bool get showSplitResultBox {
    if (!isSplitValid) return false;
    if (_selectedCriteria == SplitCriteria.byAmount && !amountFocusNode.hasFocus) return true;
    if (_selectedCriteria == SplitCriteria.evenly && !splitCountFocusNode.hasFocus) return true;
    return false;
  }

  // --- Network ---
  Future<void> refreshRecommendedFees() async {
    await fetchRecommendedFees(
      currentFeeRateText: feeRateController.text,
      onDefaultFeeRateSet: (text) => feeRateController.text = text,
    );
  }

  void setSelectedUtxoList(List<UtxoState> utxoList) {
    _selectedUtxoList = utxoList;

    if (_selectedUtxoList.isEmpty) {
      _selectedCriteria = null;
    }

    _onInputChanged();
  }

  void setSelectedCriteria(SplitCriteria criteria) {
    _selectedCriteria = criteria;
    _onInputChanged();
  }

  String getHeaderTitle(Translations t) {
    if (_selectedUtxoList.isEmpty) {
      return t.split_utxo_screen.question_select_utxo;
    }
    if (_selectedCriteria == null) {
      return t.split_utxo_screen.question_select_criteria;
    }

    switch (_selectedCriteria!) {
      case SplitCriteria.byAmount:
        return t.split_utxo_screen.question_split_by_amount;
      case SplitCriteria.evenly:
        return t.split_utxo_screen.question_split_evenly;
      case SplitCriteria.manually:
        return t.split_utxo_screen.question_select_criteria;
    }
  }

  // --- Transaction ---
  Future<bool> buildSplitTransaction() async {
    if (!isSplitValid || _isBuilding) return false;

    _isBuilding = true;
    notifyListeners();

    try {
      final feeRateText = feeRateController.text;
      final feeRate = double.tryParse(feeRateText) ?? 0.0;

      if (feeRate <= 0) return false;

      final utxo = _selectedUtxoList.first;
      final walletItem = _walletProvider.getWalletById(walletId);

      final builder = UtxoSplitTransactionBuilder(
        utxo: utxo,
        feeRate: feeRate,
        walletListItemBase: walletItem,
        addressRepository: _addressRepository,
      );

      _finalErrorMessage = "";
      UtxoSplitResult? result;

      if (_selectedCriteria == SplitCriteria.byAmount) {
        result = await builder.buildFixedAmountSplit(amountPerOutput: splitAmountSats);
      } else if (_selectedCriteria == SplitCriteria.evenly) {
        result = await builder.buildEqualAmountSplit(splitCount: splitCount);
      }

      if (result != null && result.isSuccess) {
        _sendInfoProvider.clear();
        _sendInfoProvider.setSendEntryPoint(SendEntryPoint.walletDetail);
        _sendInfoProvider.setWalletId(walletItem.id);
        _sendInfoProvider.setTransaction(result.transaction!);
        _sendInfoProvider.setIsMultisig(walletItem.walletType == WalletType.multiSignature);
        _sendInfoProvider.setWalletImportSource(walletItem.walletImportSource);
        _sendInfoProvider.setFeeRate(feeRate);
        _sendInfoProvider.setIsMaxMode(false);
        return true;
      } else if (result != null && result.exception != null) {
        _finalErrorMessage = result.exception.toString();
      }
    } catch (e) {
      _finalErrorMessage = e.toString();
    } finally {
      _isBuilding = false;
      notifyListeners();
    }
    return false;
  }

  // --- UI Presentation Helpers ---
  String getSelectedUtxoAmountText(Translations t) {
    return isUtxoSelected
        ? currentUnit.displayBitcoinAmount(_selectedUtxoList.first.amount, withUnit: true)
        : t.split_utxo_screen.placeholder_utxo;
  }

  CoconutOptionStateEnum get utxoOptionState {
    if (hasAmountError) return CoconutOptionStateEnum.error;
    if (hasAmountWarning) return CoconutOptionStateEnum.warning;
    return CoconutOptionStateEnum.normal;
  }

  String? getUtxoGuideText(Translations t) {
    if (hasAmountError) return t.split_utxo_screen.utxo_error;
    if (hasAmountWarning) return t.split_utxo_screen.utxo_warning;
    return null;
  }

  CoconutOptionStateEnum get feeOptionState {
    if (_isFeeExceedsAmountError) return CoconutOptionStateEnum.error;
    return CoconutOptionStateEnum.normal;
  }

  String? get feeExceedsAmountErrorText {
    if (_isFeeExceedsAmountError) return t.split_utxo_screen.fee_error;
    return null;
  }

  void incrementSplitCount() {
    splitCountFocusNode.unfocus();
    final current = int.tryParse(splitCountController.text) ?? 0;
    splitCountController.text = (current + 1).toString();
  }

  void decrementSplitCount() {
    splitCountFocusNode.unfocus();
    final current = int.tryParse(splitCountController.text) ?? 0;
    if (current > 0) {
      splitCountController.text = (current - 1).toString();
    }
  }

  void onRecommendedCountTapped(int count) {
    splitCountFocusNode.unfocus();
    splitCountController.text = count.toString();
  }

  void onRecommendedAmountTapped(double btc) {
    amountFocusNode.unfocus();
    if (currentUnit.isBasedOnSatoshi) {
      amountController.text = (btc * 1e8).toInt().toString();
    } else {
      amountController.text = btc.toStringAsFixed(8).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
    }
  }

  String getFeePickerText(Translations t) {
    return hasFeeRate ? estimatedFeeText : t.split_utxo_screen.placeholder_expected_fee;
  }

  bool onFeeRateChanged(String text) {
    return handleFeeRateChanged(text, (formattedText) {
      feeRateController.text = formattedText;
    });
  }

  void removeTrailingDotInFeeRate() {
    feeRateController.text = removeTrailingDotInFeeRateText(feeRateController.text);
  }

  void setFeeRateFromRecommendation(double sats) {
    feeRateController.text = sats.toStringAsFixed(1);
  }

  double _getTxVBytes(WalletListItemBase walletItem, int inputCount, int outputCount) {
    return WalletUtility.estimateVirtualByte(
      walletItem.walletType.addressType,
      inputCount,
      outputCount,
      requiredSignature: walletItem.multisigConfig?.requiredSignature,
      totalSigner: walletItem.multisigConfig?.totalSigner,
    );
  }

  int _getRealTxFee(Transaction tx, double feeRate, WalletListItemBase walletItem) {
    return tx.estimateFee(
      feeRate,
      walletItem.walletType.addressType,
      requiredSignature: walletItem.multisigConfig?.requiredSignature,
      totalSigner: walletItem.multisigConfig?.totalSigner,
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    amountFocusNode.dispose();
    feeRateController.dispose();
    feeRateFocusNode.dispose();
    splitCountController.dispose();
    splitCountFocusNode.dispose();
    super.dispose();
  }
}
