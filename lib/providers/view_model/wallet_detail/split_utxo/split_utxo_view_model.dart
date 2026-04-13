import 'dart:async';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/dust_constants.dart';
import 'package:coconut_wallet/core/transaction/utxo_split_transaction_builder.dart';
import 'package:coconut_wallet/core/exceptions/utxo_split/utxo_split_exception.dart';
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
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

typedef BigTxConfirmPrompt = Future<bool> Function(int outputCount);

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
  final BigTxConfirmPrompt _showBigTxConfirmPrompt;

  // State
  List<UtxoState> _selectedUtxoList = [];
  SplitCriteria? _selectedCriteria;

  final TextEditingController amountController = TextEditingController();
  final FocusNode amountFocusNode = FocusNode();
  final TextEditingController feeRateController = TextEditingController();
  final FocusNode feeRateFocusNode = FocusNode();
  final TextEditingController splitCountController = TextEditingController();
  final FocusNode splitCountFocusNode = FocusNode();
  String _lastFeeRateText = '';
  String _lastAmountText = '';
  String _lastSplitCountText = '';
  late final WalletListItemBase _wallet;
  late final UtxoSplitTransactionBuilder _splitBuilder;

  UtxoSplitResult? _splitResult;
  UtxoSplitResult? get splitResult => _splitResult;

  final List<ManualSplitItem> manualSplitItems = [];
  Timer? _debounceTimer;
  SplitPreview? _splitPreview;

  bool _isDustError = false;
  bool _isFeeExceedsAmountError = false;
  String _finalErrorMessage = "";
  bool _isBuilding = false;

  /// Output 개수가 많을 때 트랜잭션 생성 시 1분 이상 걸릴 수 있으므로 컨펌 필요
  final int _bigTxOutputThreshold = 1000;
  bool? _isBigTxBuild;

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

  bool get usePreview =>
      _splitPreview != null &&
      _splitPreview!.amountCountMap.values.fold<int>(0, (sum, count) => sum + count) > _bigTxOutputThreshold &&
      _isBigTxBuild == false;

  bool get showSplitResultBox => _splitResult != null || usePreview;

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
    this._showBigTxConfirmPrompt,
  ) {
    feeRateController.addListener(() {
      if (_lastFeeRateText != feeRateController.text) {
        _lastFeeRateText = feeRateController.text;
        Logger.log('--> feeRateController.addListener');
        _onInputChanged();
      }
    });
    feeRateFocusNode.addListener(notifyListeners);

    amountController.addListener(() {
      if (_lastAmountText != amountController.text) {
        _lastAmountText = amountController.text;
        _onInputChanged();
      }
    });
    amountFocusNode.addListener(notifyListeners);

    splitCountController.addListener(() {
      if (_lastSplitCountText != splitCountController.text) {
        _lastSplitCountText = splitCountController.text;
        _onInputChanged();
      }
    });
    splitCountFocusNode.addListener(notifyListeners);

    // TODO: 직접 나누기는 어디에 있나?

    _wallet = _walletProvider.getWalletById(walletId);
    _splitBuilder = UtxoSplitTransactionBuilder(
      dustThreshold: _wallet.walletType == WalletType.singleSignature ? DustThresholds.p2wpkh : DustThresholds.p2wsh,
      feeRate: 1.0,
      walletListItemBase: _wallet,
      addressRepository: _addressRepository,
    );
    addManualSplitItem();
    refreshRecommendedFees();
  }

  // --- UI Text Getter ---

  /// utxo.amount를 000 나눌게요
  String get splitSummaryTitle {
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
      return t.split_utxo_screen.expected_result.split_manually(utxoAmountText: utxoAmountText);
    } else {
      return '-';
    }
  }

  /// N x M
  String? get splitOutputText {
    if (usePreview) {
      return _splitPreview!.amountCountMap.entries
          .map((e) {
            final formattedAmount = currentUnit.displayBitcoinAmount(e.key, withUnit: true);
            return '${e.value} × $formattedAmount';
          })
          .join('\n');
    }
    if (_splitResult == null) return null;
    if (_splitResult!.exception != null) return null;

    final outputMap = _splitResult!.splitAmountMap;
    if (outputMap.isNotEmpty) {
      return outputMap.entries
          .map((e) {
            final formattedAmount = currentUnit.displayBitcoinAmount(e.key, withUnit: true);
            return '${e.value} × $formattedAmount';
          })
          .join('\n');
    }

    return null;
  }

  String? get amountErrorText {
    if (_selectedUtxoList.isEmpty) return null;
    if (_splitAmountInput.isEmpty) return null;
    // TODO: dustThreshold check

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
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () async {
      Logger.log('--> _onInputChanged');

      final SplitPreview? preview = await _updatePreview();
      if (preview == null) {
        notifyListeners();
        return;
      }

      final outputCount = preview.amountCountMap.values.fold<int>(0, (sum, count) => sum + count);
      bool isBuildTx = true;
      if (outputCount > _bigTxOutputThreshold) {
        if (_isBigTxBuild == null) {
          _isBigTxBuild = await _showBigTxConfirmPrompt(outputCount);
          isBuildTx = _isBigTxBuild!;
        }
      }

      if (isBuildTx) {
        _splitResult = await _buildTransaction();
      }

      notifyListeners();
    });
  }

  double get feeRate {
    final feeRateText = feeRateController.text;
    return double.tryParse(feeRateText) ?? 0.0;
  }

  bool get isSplitInputValid {
    if (_selectedCriteria == null || _selectedUtxoList.isEmpty || hasAmountError) {
      return false;
    }
    if (feeRate <= 0) {
      return false;
    }
    // TODO: hasAmountError는 언제 발생하는 에러인가?
    if (_selectedCriteria == SplitCriteria.byAmount) {
      return splitAmountSats > 0 && splitAmountSats < _selectedUtxoAmount;
    }
    if (_selectedCriteria == SplitCriteria.evenly) {
      return splitCount >= 2; // TODO: max 이하인지도 확인해야함
    }
    if (_selectedCriteria == SplitCriteria.manually) {
      return manualSplitItems.any(_isValidManualSplitItem);
    }
    return false;
  }

  bool get shouldShowFeePicker {
    if (_selectedCriteria == SplitCriteria.byAmount) {
      return splitAmountSats > 0;
    }
    if (_selectedCriteria == SplitCriteria.evenly) {
      return splitCount >= 2;
    }
    if (_selectedCriteria == SplitCriteria.manually) {
      return manualSplitItems.any(_isValidManualSplitItem);
    }
    return false;
  }

  bool _isValidManualSplitItem(ManualSplitItem item) {
    return (double.tryParse(item.amountController.text) ?? 0) > 0 && (int.tryParse(item.countController.text) ?? 0) > 0;
  }

  Map<int, int> get _manualSplitInput {
    final Map<int, int> amountCountMap = {};
    for (var item in manualSplitItems) {
      if (_isValidManualSplitItem(item)) {
        final amount = currentUnit.toSatoshi(double.tryParse(item.amountController.text) ?? 0.0);
        final count = int.tryParse(item.countController.text) ?? 0;
        amountCountMap[amount] = (amountCountMap[amount] ?? 0) + count;
      }
    }
    return amountCountMap;
  }

  Future<SplitPreview?> _updatePreview() async {
    _isDustError = false;
    _isFeeExceedsAmountError = false;
    _finalErrorMessage = "";
    _splitPreview = null;
    _splitResult = null;

    if (!isSplitInputValid) {
      notifyListeners();
      return null;
    }

    try {
      if (_selectedCriteria == SplitCriteria.byAmount) {
        _splitPreview = await _splitBuilder.getFixedAmountSplitPreview(amountPerOutput: splitAmountSats);
      } else if (_selectedCriteria == SplitCriteria.evenly) {
        _splitPreview = await _splitBuilder.getEqualAmountSplitPreview(splitCount: splitCount);
      } else if (_selectedCriteria == SplitCriteria.manually) {
        _splitPreview = await _splitBuilder.getCustomAmountSplitPreview(amountCountMap: _manualSplitInput);
      }
    } on SplitOutputDustException {
      _isDustError = true;
    } on SplitInsufficientAmountException {
      _isFeeExceedsAmountError = true;
    } catch (e) {
      _finalErrorMessage = e.toString();
    }

    notifyListeners();
    return _splitPreview;
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

  // --- Network ---
  Future<bool> refreshRecommendedFees() async {
    return await fetchRecommendedFees(
      currentFeeRateText: feeRateController.text,
      onDefaultFeeRateSet: (text) {
        feeRateController.text = text;
        _splitBuilder.feeRate = double.parse(text);
      },
    );
  }

  void setSelectedUtxoList(List<UtxoState> utxoList) {
    _selectedUtxoList = utxoList;

    if (_selectedUtxoList.isEmpty) {
      _selectedCriteria = null;
      _splitBuilder.setUtxo(null);
    } else {
      _splitBuilder.setUtxo(_selectedUtxoList.first);
    }

    _onInputChanged();
  }

  void setSelectedCriteria(SplitCriteria criteria) {
    _selectedCriteria = criteria;
    _clearResult();
  }

  void _clearResult() {
    // TODO: textField들 초기화하기
    _lastAmountText = '';
    _lastSplitCountText = '';
    amountController.text = '';
    splitCountController.text = '';
    _resetManualSplitItems();
    _isDustError = false;
    _isFeeExceedsAmountError = false;
    _isBigTxBuild = null;
    _finalErrorMessage = "";
    _splitResult = _splitPreview = null;
    notifyListeners();
  }

  void _resetManualSplitItems() {
    for (final item in manualSplitItems) {
      item.amountController.removeListener(_onInputChanged);
      item.countController.removeListener(_onInputChanged);
      item.amountFocusNode.removeListener(notifyListeners);
      item.countFocusNode.removeListener(notifyListeners);
      item.dispose();
    }
    manualSplitItems.clear();
    addManualSplitItem();
  }

  Future<UtxoSplitResult?> _buildTransaction() async {
    try {
      _finalErrorMessage = "";
      UtxoSplitResult? result;

      if (_selectedCriteria == SplitCriteria.byAmount) {
        result = await _splitBuilder.buildFixedAmountSplit(amountPerOutput: splitAmountSats);
      } else if (_selectedCriteria == SplitCriteria.evenly) {
        result = await _splitBuilder.buildEqualAmountSplit(splitCount: splitCount);
      } else if (_selectedCriteria == SplitCriteria.manually) {
        result = await _splitBuilder.buildCustomAmountSplit(amountCountMap: _manualSplitInput);
      }

      if (result != null && result.isSuccess) {
        return result;
      } else if (result != null && result.exception != null) {
        _finalErrorMessage = result.exception.toString();
      }
    } catch (e) {
      _finalErrorMessage = e.toString();
    } finally {
      _isBuilding = false;
      notifyListeners();
    }
    return null;
  }

  Future<bool> buildTxAndSaveForNext() async {
    if (!isSplitValid || _isBuilding) return false;

    _isBuilding = true;
    notifyListeners();

    try {
      _splitResult ??= await _buildTransaction();
      assert(_splitResult != null && _splitResult!.isSuccess);

      if (_splitResult!.isSuccess) {
        _sendInfoProvider.clear();
        _sendInfoProvider.setSendEntryPoint(SendEntryPoint.walletDetail);
        _sendInfoProvider.setWalletId(_wallet.id);
        _sendInfoProvider.setTransaction(_splitResult!.transaction!);
        _sendInfoProvider.setIsMultisig(_wallet.walletType == WalletType.multiSignature);
        _sendInfoProvider.setWalletImportSource(_wallet.walletImportSource);
        _sendInfoProvider.setFeeRate(feeRate);
        _sendInfoProvider.setIsMaxMode(true);
        return true;
      } else {
        _finalErrorMessage = _splitResult!.exception.toString();
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

  // ----- estimated fee option picker ------
  CoconutOptionStateEnum get feeOptionState {
    if (_isFeeExceedsAmountError) return CoconutOptionStateEnum.error;
    return CoconutOptionStateEnum.normal;
  }

  String? get errorTextAboutFee {
    if (_isFeeExceedsAmountError) return t.split_utxo_screen.fee_error;
    return null;
  }

  String get previewFeeText {
    if (usePreview && _splitPreview != null && _splitPreview!.estimatedFee > 0) {
      return currentUnit.displayBitcoinAmount(_splitPreview!.estimatedFee.ceil(), withUnit: true);
    }
    if (!usePreview && _splitResult != null && _splitResult!.estimatedFee > 0) {
      return currentUnit.displayBitcoinAmount(_splitResult!.estimatedFee.ceil(), withUnit: true);
    }
    return '-';
  }
  // ----- estimated fee option picker ------

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

  Future<SplitPreview> _buildPreview() async {
    if (_selectedCriteria == SplitCriteria.byAmount) {
      return _splitBuilder.getFixedAmountSplitPreview(amountPerOutput: splitAmountSats);
    } else if (_selectedCriteria == SplitCriteria.evenly) {
      return _splitBuilder.getEqualAmountSplitPreview(splitCount: splitCount);
    } else if (_selectedCriteria == SplitCriteria.manually) {
      final Map<int, int> amountCountMap = {};
      for (final item in manualSplitItems) {
        final amount = currentUnit.toSatoshi(double.tryParse(item.amountController.text) ?? 0.0);
        final count = int.tryParse(item.countController.text) ?? 0;
        if (amount > 0 && count > 0) {
          amountCountMap[amount] = (amountCountMap[amount] ?? 0) + count;
        }
      }
      return _splitBuilder.getCustomAmountSplitPreview(amountCountMap: amountCountMap);
    }

    throw StateError('Split criteria must be selected before building preview');
  }

  bool onFeeRateChanged(String text) {
    String? updatedText;
    final isTooLow = handleFeeRateChanged(text, (formattedUpdatedText) {
      updatedText = formattedUpdatedText;
      feeRateController.text = formattedUpdatedText;
    });

    if (!isTooLow && updatedText != null) {
      final parsed = double.tryParse(updatedText!);
      if (parsed != null && parsed > 0) {
        // TODO: feeRate 설정을 여기서 해주는게 맞는가??????
        _splitBuilder.feeRate = parsed;
        _onInputChanged();
      }
    }

    return isTooLow;
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
