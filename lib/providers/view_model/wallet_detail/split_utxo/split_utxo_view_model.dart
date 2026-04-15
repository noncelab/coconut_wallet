import 'dart:async';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/dust_constants.dart';
import 'package:coconut_wallet/base/async/cancelable_task.dart';
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

typedef UsePreviewConfirmPrompt = Future<bool> Function(int outputCount);

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
  final int walletId;
  final PreferenceProvider _preferenceProvider;
  final WalletProvider _walletProvider;
  final AddressRepository _addressRepository;
  final SendInfoProvider _sendInfoProvider;
  final UsePreviewConfirmPrompt _showUsePreviewConfirmPrompt;

  // State
  List<UtxoState> _selectedUtxoList = [];
  SplitCriteria? _selectedCriteria;
  List<int> _recommendedSplitCounts = [];

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
  double? get feeRatio {
    if (_splitResult != null) {
      return _splitResult!.feeRatio;
    } else if (usePreview) {
      return _splitBuilder.calculateFeeRatio(_splitPreview!.estimatedFee.toInt(), _selectedUtxoAmount);
    }
    return null;
  }

  final List<ManualSplitItem> manualSplitItems = [];
  Timer? _debounceTimer;
  SplitPreview? _splitPreview;
  CancelableTask<UtxoSplitResult>? _activeBuildTask;
  int _buildRequestId = 0;

  bool _isDustError = false;
  bool _isAmountInsufficientAfterFee = false; // byAmount or manual: 수수료를 제외하면 나눌 수 없는 금액이에요
  bool _isFeeExceedsUtxoAmount = false;
  double? _errorEstimatedFee;
  String _unexpectedErrorMessage = "";
  bool _isPreparingNextStep = false;

  /// Output 개수가 많을 때 트랜잭션 생성 시 1분 이상 걸릴 수 있으므로 컨펌 필요
  final int _bigTxOutputThreshold = 1000;
  bool? _usePreview;

  // --- UI Getter ---
  String get unexpectedErrorMessage => _unexpectedErrorMessage;
  bool get isDustError => _isDustError;
  bool get isPreparingNextStep => _isPreparingNextStep;
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
      _usePreview == true;

  bool get showSkeletonResultBox => _activeBuildTask != null;
  bool get showSplitResultBox =>
      shouldShowFeePicker && hasFeeRate && (showSkeletonResultBox || _splitResult != null || usePreview);

  List<double> get recommendedSplitAmounts {
    if (_selectedUtxoAmount <= 0) return [];

    final validAmounts =
        UtxoSplitTransactionBuilder.niceAmounts
            .where((sats) {
              return sats < _selectedUtxoAmount;
            })
            .map((sats) => sats / 1e8)
            .toList();

    if (validAmounts.length <= 6) return validAmounts;
    return validAmounts.sublist(validAmounts.length - 6);
  }

  List<int> get recommendedSplitCounts => _recommendedSplitCounts;

  // --- Initialization ---
  SplitUtxoViewModel(
    this.walletId,
    this._preferenceProvider,
    this._walletProvider,
    this._addressRepository,
    this._sendInfoProvider,
    this._showUsePreviewConfirmPrompt,
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

  String? get splitAmountErrorText {
    if (_selectedUtxoList.isEmpty) return null;
    if (_splitAmountInput.isEmpty) return null;
    // TODO: dustThreshold check

    if (splitAmountSats >= _selectedUtxoAmount) {
      return t.split_utxo_screen.amount_error.amount_too_large;
    }

    if (_isAmountInsufficientAfterFee && _selectedCriteria == SplitCriteria.byAmount) {
      return t.split_utxo_screen.amount_error.insufficient_after_fee;
    }

    return null;
  }

  String? get headerTitleErrorMessage {
    if (isOutputSumOverInput) {
      return t.split_utxo_screen.amount_error.manual_sum_over_input;
    }

    if (_isDustError) {
      return t.split_utxo_screen.dust_error;
    }

    if (_isAmountInsufficientAfterFee && _selectedCriteria == SplitCriteria.manually) {
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
      final requestId = ++_buildRequestId;
      Logger.log(
        '--> SplitUtxoViewModel._onInputChanged requestId=$requestId criteria=$_selectedCriteria '
        'feeRate=$feeRate splitAmountSats=$splitAmountSats splitCount=$splitCount '
        'manualSplitInput=$_manualSplitInput hasActiveBuild=${_activeBuildTask != null}',
      );
      await _cancelActiveBuild();

      final SplitPreview? preview = await _updatePreview();
      if (requestId != _buildRequestId) {
        Logger.log(
          '--> SplitUtxoViewModel._onInputChanged stale request after preview requestId=$requestId currentRequestId=$_buildRequestId',
        );
        return;
      }
      if (preview == null) {
        Logger.log('--> SplitUtxoViewModel._onInputChanged preview is null requestId=$requestId');
        notifyListeners();
        return;
      }
      Logger.log(
        '--> SplitUtxoViewModel._onInputChanged preview ready requestId=$requestId '
        'estimatedFee=${preview.estimatedFee} amountCountMap=${preview.amountCountMap}',
      );

      final outputCount = preview.amountCountMap.values.fold<int>(0, (sum, count) => sum + count);
      bool isBuildTx = true;
      if (outputCount > _bigTxOutputThreshold) {
        _usePreview ??= await _showUsePreviewConfirmPrompt(outputCount);
        if (requestId != _buildRequestId) {
          Logger.log(
            '--> SplitUtxoViewModel._onInputChanged stale request after use preview confirm requestId=$requestId currentRequestId=$_buildRequestId',
          );
          return;
        }
        isBuildTx = !_usePreview!;
        Logger.log(
          '--> SplitUtxoViewModel._onInputChanged use preview  decision requestId=$requestId outputCount=$outputCount isBuildTx=$isBuildTx',
        );
      }

      if (isBuildTx) {
        try {
          final result = await _buildTransaction();
          if (requestId != _buildRequestId) {
            Logger.log(
              '--> SplitUtxoViewModel._onInputChanged stale request after build requestId=$requestId currentRequestId=$_buildRequestId',
            );
            return;
          }
          _splitResult = result;
          Logger.log(
            '--> SplitUtxoViewModel._onInputChanged build finished requestId=$requestId success=${result?.isSuccess}',
          );
        } on TaskCancelledException {
          Logger.log(
            '--> SplitUtxoViewModel._onInputChanged build cancelled requestId=$requestId currentRequestId=$_buildRequestId',
          );
          if (requestId != _buildRequestId) {
            return;
          }
        }
      }
      notifyListeners();
    });
  }

  double get feeRate {
    final feeRateText = feeRateController.text;
    return double.tryParse(feeRateText) ?? 0.0;
  }

  bool get isSplitInputValid {
    if (_selectedCriteria == null || _selectedUtxoList.isEmpty || hasSelectedUtxoAmountError) {
      return false;
    }
    if (feeRate <= 0) {
      return false;
    }

    if (_selectedCriteria == SplitCriteria.byAmount) {
      return splitAmountSats > 0 && splitAmountSats < _selectedUtxoAmount;
    }
    if (_selectedCriteria == SplitCriteria.evenly) {
      return splitCount >= 2; // TODO: max 이하인지도 확인해야함
    }
    if (_selectedCriteria == SplitCriteria.manually) {
      return manualSplitItems.any(_isValidManualSplitItem) && !isOutputSumOverInput;
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

  int get _manualSplitRequestedTotal {
    int total = 0;
    for (final item in manualSplitItems) {
      if (_isValidManualSplitItem(item)) {
        final amount = currentUnit.toSatoshi(double.tryParse(item.amountController.text) ?? 0.0);
        final count = int.tryParse(item.countController.text) ?? 0;
        total += amount * count;
      }
    }
    return total;
  }

  bool get _doesManualSplitRequestedTotalExceedInput {
    return _selectedUtxoList.isNotEmpty && _manualSplitRequestedTotal >= _selectedUtxoAmount;
  }

  bool get isOutputSumOverInput {
    // byAmount일 때, splitAmountErrorText로 반환 중
    // if (_selectedCriteria == SplitCriteria.byAmount) {
    //   return _selectedUtxoList.isNotEmpty && splitAmountSats >= _selectedUtxoAmount;
    // }

    if (_selectedCriteria == SplitCriteria.manually) {
      return _doesManualSplitRequestedTotalExceedInput;
    }

    return false;
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
    _isAmountInsufficientAfterFee = false;
    _isFeeExceedsUtxoAmount = false;
    _errorEstimatedFee = null;
    _unexpectedErrorMessage = "";
    _splitPreview = null;
    _splitResult = null;

    if (!isSplitInputValid) {
      Logger.log(
        '--> SplitUtxoViewModel._updatePreview skipped invalid input criteria=$_selectedCriteria feeRate=$feeRate splitAmountSats=$splitAmountSats splitCount=$splitCount manualSplitInput=$_manualSplitInput',
      );
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
      Logger.log(
        '--> SplitUtxoViewModel._updatePreview success criteria=$_selectedCriteria estimatedFee=${_splitPreview?.estimatedFee} amountCountMap=${_splitPreview?.amountCountMap}',
      );
    } on SplitOutputDustException {
      Logger.log('--> SplitUtxoViewModel._updatePreview SplitOutputDustException criteria=$_selectedCriteria');
      _isDustError = true;
    } on FeeExceedsUtxoAmountException catch (e) {
      Logger.log(
        '--> SplitUtxoViewModel._updatePreview FeeExceedsUtxoAmountException estimatedFee=${e.estimatedFee} criteria=$_selectedCriteria',
      );
      _isFeeExceedsUtxoAmount = true;
      _errorEstimatedFee = e.estimatedFee;
    } on SplitInsufficientAmountException catch (e) {
      Logger.log(
        '--> SplitUtxoViewModel._updatePreview SplitInsufficientAmountException estimatedFee=${e.estimatedFee} criteria=$_selectedCriteria',
      );
      _isAmountInsufficientAfterFee = true;
      _errorEstimatedFee = e.estimatedFee;
    } catch (e) {
      Logger.log('--> SplitUtxoViewModel._updatePreview error=$e criteria=$_selectedCriteria');
      _unexpectedErrorMessage = e.toString();
    }

    notifyListeners();
    return _splitPreview;
  }

  // --- Validation ---
  bool get hasSelectedUtxoAmountError {
    if (_selectedUtxoList.isEmpty) return false;
    return _selectedUtxoAmount >= 1000 && _selectedUtxoAmount < 20000;
  }

  bool get hasSelectedUtxoAmountWarning {
    if (_selectedUtxoList.isEmpty) return false;
    return _selectedUtxoAmount >= 20000 && _selectedUtxoAmount < 50000;
  }

  bool get isSplitValid {
    if (_selectedCriteria == null || _selectedUtxoList.isEmpty) return false;
    if (hasSelectedUtxoAmountError) return false;

    if (_isDustError || _isAmountInsufficientAfterFee || _isFeeExceedsUtxoAmount || isOutputSumOverInput) return false;
    if (_splitPreview == null) return false;
    if (_selectedCriteria == SplitCriteria.byAmount) {
      if (splitAmountSats <= 0) return false;
      if (splitAmountSats >= _selectedUtxoAmount) return false;
    } else if (_selectedCriteria == SplitCriteria.evenly) {
      if (splitCount < 2) return false;
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
        _updateRecommendedSplitCounts();
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

    _updateRecommendedSplitCounts();
    _onInputChanged();
  }

  void setSelectedCriteria(SplitCriteria criteria) {
    final previousCriteria = _selectedCriteria;
    final requestId = ++_buildRequestId;
    Logger.log(
      '--> SplitUtxoViewModel.setSelectedCriteria previous=$previousCriteria next=$criteria '
      'requestId=$requestId hasActiveBuild=${_activeBuildTask != null}',
    );
    _cancelActiveBuild();
    _selectedCriteria = criteria;
    _clearResult();
  }

  void _clearResult() {
    _lastAmountText = '';
    _lastSplitCountText = '';
    amountController.text = '';
    splitCountController.text = '';
    _resetManualSplitItems();
    _isDustError = false;
    _isAmountInsufficientAfterFee = false;
    _isFeeExceedsUtxoAmount = false;
    _errorEstimatedFee = null;
    _usePreview = null;
    _unexpectedErrorMessage = "";
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

  Future<void> _cancelActiveBuild() async {
    final task = _activeBuildTask;
    _activeBuildTask = null;
    if (task != null) {
      Logger.log(
        '--> SplitUtxoViewModel._cancelActiveBuild cancelling taskHash=${task.hashCode} requestId=$_buildRequestId',
      );
      await task.cancel();
      Logger.log(
        '--> SplitUtxoViewModel._cancelActiveBuild cancelled taskHash=${task.hashCode} requestId=$_buildRequestId',
      );
    } else {
      Logger.log('--> SplitUtxoViewModel._cancelActiveBuild no active task requestId=$_buildRequestId');
    }
  }

  Future<UtxoSplitResult?> _buildTransaction() async {
    assert(_splitPreview != null);
    CancelableTask<UtxoSplitResult>? task;
    try {
      _unexpectedErrorMessage = "";
      Logger.log(
        '--> SplitUtxoViewModel._buildTransaction start requestId=$_buildRequestId '
        'criteria=$_selectedCriteria feeRate=$feeRate splitAmountSats=$splitAmountSats '
        'splitCount=$splitCount manualSplitInput=$_manualSplitInput preview=${_splitPreview?.amountCountMap}',
      );

      if (_selectedCriteria == SplitCriteria.byAmount) {
        task = _splitBuilder.buildFixedAmountSplit(amountPerOutput: splitAmountSats);
      } else if (_selectedCriteria == SplitCriteria.evenly) {
        task = _splitBuilder.buildEqualAmountSplit(splitCount: splitCount);
      } else if (_selectedCriteria == SplitCriteria.manually) {
        task = _splitBuilder.buildCustomAmountSplit(amountCountMap: _manualSplitInput);
      }

      _activeBuildTask = task;
      final result = await task?.future;

      if (result != null && result.isSuccess) {
        return result;
      } else if (result != null) {
        _unexpectedErrorMessage = result.exception.toString();
      }
    } on TaskCancelledException {
      rethrow;
    } catch (e) {
      _unexpectedErrorMessage = e.toString();
    } finally {
      if (identical(_activeBuildTask, task)) {
        _activeBuildTask = null;
      }
      notifyListeners();
    }
    return null;
  }

  Future<bool> buildTxAndSaveForNext() async {
    if (!isSplitValid || _isPreparingNextStep) return false;

    _isPreparingNextStep = true;
    notifyListeners();

    try {
      _splitResult ??= await _buildTransaction();

      if (_splitResult != null && _splitResult!.isSuccess) {
        _sendInfoProvider.clear();
        _sendInfoProvider.setSendEntryPoint(SendEntryPoint.walletDetail);
        _sendInfoProvider.setWalletId(_wallet.id);
        _sendInfoProvider.setTransaction(_splitResult!.transaction!);
        _sendInfoProvider.setIsMultisig(_wallet.walletType == WalletType.multiSignature);
        _sendInfoProvider.setWalletImportSource(_wallet.walletImportSource);
        _sendInfoProvider.setFeeRate(feeRate);
        _sendInfoProvider.setIsMaxMode(true);
        return true;
      }

      if (_splitResult != null) {
        _unexpectedErrorMessage = _splitResult!.exception.toString();
      }
    } catch (e) {
      _unexpectedErrorMessage = e.toString();
    } finally {
      _isPreparingNextStep = false;
      notifyListeners();
    }
    return false;
  }

  // --- UI Presentation Helpers ---
  String getSelectedUtxoAmountText(Translations t) {
    return isUtxoSelected
        ? currentUnit.displayBitcoinAmount(_selectedUtxoAmount, withUnit: true)
        : t.split_utxo_screen.placeholder_utxo;
  }

  CoconutOptionStateEnum get utxoOptionState {
    if (hasSelectedUtxoAmountError) return CoconutOptionStateEnum.error;
    if (hasSelectedUtxoAmountWarning) return CoconutOptionStateEnum.warning;
    return CoconutOptionStateEnum.normal;
  }

  String? getUtxoGuideText(Translations t) {
    if (hasSelectedUtxoAmountError) return t.split_utxo_screen.utxo_error;
    if (hasSelectedUtxoAmountWarning) return t.split_utxo_screen.utxo_warning;
    return null;
  }

  /// ---------------- estimated fee option picker ----------------
  CoconutOptionStateEnum get feeOptionState {
    if (_isFeeExceedsUtxoAmount) return CoconutOptionStateEnum.error;
    return CoconutOptionStateEnum.normal;
  }

  String? get errorTextAboutFee {
    if (_isFeeExceedsUtxoAmount) return t.split_utxo_screen.fee_error;
    return null;
  }

  String get feePickerDisplayText {
    if (_errorEstimatedFee != null && _errorEstimatedFee! > 0) {
      return currentUnit.displayBitcoinAmount(_errorEstimatedFee!.ceil(), withUnit: true);
    }

    if (usePreview && _splitPreview != null && _splitPreview!.estimatedFee > 0) {
      return currentUnit.displayBitcoinAmount(_splitPreview!.estimatedFee.ceil(), withUnit: true);
    }
    if (!usePreview && _splitResult != null && _splitResult!.estimatedFee > 0) {
      return currentUnit.displayBitcoinAmount(_splitResult!.estimatedFee.ceil(), withUnit: true);
    }
    return '-';
  }

  /// ---------------- estimated fee option picker ----------------

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

  /// -------------------------------------------------
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
      notifyListeners();
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

  /// -------------------------------------------------

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

  bool onFeeRateChanged(String text) {
    String? updatedText;
    final isTooLow = handleFeeRateChanged(text, (formattedUpdatedText) {
      updatedText = formattedUpdatedText;
      feeRateController.text = formattedUpdatedText;
    });

    if (!isTooLow && updatedText != null) {
      final parsed = double.tryParse(updatedText!);
      if (parsed != null && parsed > 0) {
        _splitBuilder.feeRate = parsed;
        _updateRecommendedSplitCounts();
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

  Future<void> _updateRecommendedSplitCounts() async {
    if (_selectedUtxoList.isEmpty) {
      _recommendedSplitCounts = [];
      notifyListeners();
      return;
    }
    try {
      _recommendedSplitCounts = await _splitBuilder.getNiceSplitCounts();
      notifyListeners();
    } catch (e) {
      Logger.log('Error getting recommended split counts: $e');
    }
  }

  @override
  void dispose() {
    _cancelActiveBuild();
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
