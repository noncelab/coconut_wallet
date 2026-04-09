import 'dart:async';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/core/transaction/utxo_split_transaction_builder.dart';
import 'package:coconut_wallet/core/exceptions/utxo_split/utxo_split_exception.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
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

  final List<ManualSplitItem> manualSplitItems = [];
  Timer? _debounceTimer;
  SplitPreview? _splitPreview;

  bool _isDustError = false;
  bool _isFeeExceedsAmountError = false;
  String _finalErrorMessage = "";
  bool _isBuilding = false;

  // --- UI Getter ---
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

    addManualSplitItem();
    refreshRecommendedFees();
  }

  // --- UI Text Getter ---
  String get previewFeeText {
    if (_splitPreview != null && _splitPreview!.estimatedFee > 0) {
      return currentUnit.displayBitcoinAmount(_splitPreview!.estimatedFee.ceil(), withUnit: true);
    }
    return '-';
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
    } else if (_selectedCriteria == SplitCriteria.manually) {
      return '${_selectedCriteria!.getLabel(t)} ($utxoAmountText)';
    } else {
      return '-';
    }
  }

  String get newUtxoResultText {
    if (_selectedCriteria == null || _selectedUtxoList.isEmpty) return '-';

    if (_splitPreview != null) {
      final values = _splitPreview!.recipients.values.toList();
      if (values.isNotEmpty) {
        final fee = _splitPreview!.estimatedFee.ceil();
        final Map<int, int> outputMap = {};

        for (int i = 0; i < values.length - 1; i++) {
          outputMap[values[i]] = (outputMap[values[i]] ?? 0) + 1;
        }

        final sweepSats = values.last - fee;
        if (sweepSats > 0) {
          outputMap[sweepSats] = (outputMap[sweepSats] ?? 0) + 1;
        }

        if (outputMap.isNotEmpty) {
          return outputMap.entries
              .map((e) {
                final formattedAmount = currentUnit.displayBitcoinAmount(e.key, withUnit: true);
                return '${e.value} × $formattedAmount';
              })
              .join('\n');
        }
      }
    }
    return '-';
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
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _updatePreviewFeeAsync();
    });
    notifyListeners();
  }

  Future<void> _updatePreviewFeeAsync() async {
    _isDustError = false;
    _isFeeExceedsAmountError = false;
    _splitPreview = null;

    bool isInputValid = true;
    if (_selectedCriteria == null || _selectedUtxoList.isEmpty || hasAmountError) {
      isInputValid = false;
    } else if (_selectedCriteria == SplitCriteria.byAmount) {
      isInputValid = splitAmountSats > 0 && splitAmountSats < _selectedUtxoAmount;
    } else if (_selectedCriteria == SplitCriteria.evenly) {
      isInputValid = splitCount >= 2;
    } else if (_selectedCriteria == SplitCriteria.manually) {
      isInputValid = manualSplitItems.any(
        (item) =>
            (double.tryParse(item.amountController.text) ?? 0) > 0 &&
            (int.tryParse(item.countController.text) ?? 0) > 0,
      );
    }

    if (!isInputValid) {
      notifyListeners();
      return;
    }

    final feeRateText = feeRateController.text;
    final feeRate = double.tryParse(feeRateText) ?? 0.0;

    if (feeRate <= 0) {
      notifyListeners();
      return;
    }

    final utxo = _selectedUtxoList.first;

    final walletItem = _walletProvider.getWalletById(walletId);

    final builder = UtxoSplitTransactionBuilder(
      utxo: utxo,
      feeRate: feeRate,
      walletListItemBase: walletItem,
      addressRepository: _addressRepository,
      dustThreshold: dustLimit,
    );

    try {
      if (_selectedCriteria == SplitCriteria.byAmount) {
        _splitPreview = await builder.getFixedAmountSplitPreview(amountPerOutput: splitAmountSats);
      } else if (_selectedCriteria == SplitCriteria.evenly) {
        _splitPreview = await builder.getEqualAmountSplitPreview(splitCount: splitCount);
      } else if (_selectedCriteria == SplitCriteria.manually) {
        final Map<int, int> amountCountMap = {};
        for (var item in manualSplitItems) {
          final amount = currentUnit.toSatoshi(double.tryParse(item.amountController.text) ?? 0.0);
          final count = int.tryParse(item.countController.text) ?? 0;
          if (amount > 0 && count > 0) {
            amountCountMap[amount] = (amountCountMap[amount] ?? 0) + count;
          }
        }
        if (amountCountMap.isNotEmpty) {
          _splitPreview = await builder.getCustomAmountSplitPreview(amountCountMap: amountCountMap);
        }
      }
    } on SplitOutputDustException {
      _isDustError = true;
    } on SplitInsufficientAmountException {
      _isFeeExceedsAmountError = true;
    } catch (e) {
      // ignore
    }

    notifyListeners();
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
      if (_splitPreview == null) return false;
    } else if (_selectedCriteria == SplitCriteria.evenly) {
      if (splitCount < 2) return false;
      if (_splitPreview == null) return false;
    } else if (_selectedCriteria == SplitCriteria.manually) {
      if (_splitPreview == null) return false;
    }
    return true;
  }

  bool get showSplitResultBox {
    if (!isSplitValid) return false;
    if (_selectedCriteria == SplitCriteria.byAmount && !amountFocusNode.hasFocus) return true;
    if (_selectedCriteria == SplitCriteria.evenly && !splitCountFocusNode.hasFocus) return true;
    if (_selectedCriteria == SplitCriteria.manually &&
        !manualSplitItems.any((item) => item.amountFocusNode.hasFocus || item.countFocusNode.hasFocus))
      return true;
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
        dustThreshold: dustLimit,
      );

      _finalErrorMessage = "";
      UtxoSplitResult? result;

      if (_selectedCriteria == SplitCriteria.byAmount) {
        result = await builder.buildFixedAmountSplit(amountPerOutput: splitAmountSats);
      } else if (_selectedCriteria == SplitCriteria.evenly) {
        result = await builder.buildEqualAmountSplit(splitCount: splitCount);
      } else if (_selectedCriteria == SplitCriteria.manually) {
        final Map<int, int> amountCountMap = {};
        for (var item in manualSplitItems) {
          final amount = currentUnit.toSatoshi(double.tryParse(item.amountController.text) ?? 0.0);
          final count = int.tryParse(item.countController.text) ?? 0;
          if (amount > 0 && count > 0) {
            amountCountMap[amount] = (amountCountMap[amount] ?? 0) + count;
          }
        }
        result = await builder.buildCustomAmountSplit(amountCountMap: amountCountMap);
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

  void addManualSplitItem() {
    final item = ManualSplitItem();
    item.amountController.addListener(_onInputChanged);
    item.countController.addListener(_onInputChanged);
    item.amountFocusNode.addListener(notifyListeners);
    item.countFocusNode.addListener(notifyListeners);
    manualSplitItems.add(item);
    notifyListeners();
  }

  void removeManualSplitItem(int index) {
    if (manualSplitItems.length > 1) {
      final item = manualSplitItems.removeAt(index);
      item.amountController.removeListener(_onInputChanged);
      item.countController.removeListener(_onInputChanged);
      item.amountFocusNode.removeListener(notifyListeners);
      item.countFocusNode.removeListener(notifyListeners);
      item.dispose();
      _onInputChanged();
    }
  }

  void incrementManualSplitCount(int index) {
    manualSplitItems[index].countFocusNode.unfocus();
    final current = int.tryParse(manualSplitItems[index].countController.text) ?? 0;
    manualSplitItems[index].countController.text = (current + 1).toString();
  }

  void decrementManualSplitCount(int index) {
    manualSplitItems[index].countFocusNode.unfocus();
    final current = int.tryParse(manualSplitItems[index].countController.text) ?? 0;
    if (current > 0) {
      manualSplitItems[index].countController.text = (current - 1).toString();
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
    return hasFeeRate ? previewFeeText : t.split_utxo_screen.placeholder_expected_fee;
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

  @override
  void dispose() {
    amountController.dispose();
    amountFocusNode.dispose();
    feeRateController.dispose();
    feeRateFocusNode.dispose();
    splitCountController.dispose();
    splitCountFocusNode.dispose();
    for (var item in manualSplitItems) {
      item.dispose();
    }
    _debounceTimer?.cancel();
    super.dispose();
  }
}

class ManualSplitItem {
  final TextEditingController amountController = TextEditingController();
  final FocusNode amountFocusNode = FocusNode();
  final TextEditingController countController = TextEditingController(text: '0');
  final FocusNode countFocusNode = FocusNode();

  void dispose() {
    amountController.dispose();
    amountFocusNode.dispose();
    countController.dispose();
    countFocusNode.dispose();
  }
}
