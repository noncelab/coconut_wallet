import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/core/transaction/utxo_split_transaction_builder.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/utils/fee_rate_mixin.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:flutter/material.dart';

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

  // State
  List<UtxoState> _selectedUtxoList = [];
  SplitCriteria? _selectedCriteria;

  final TextEditingController amountController = TextEditingController();
  final FocusNode amountFocusNode = FocusNode();
  final TextEditingController feeRateController = TextEditingController();
  final FocusNode feeRateFocusNode = FocusNode();

  int? _estimatedFeeSats;
  bool _isDustError = false;
  String _finalErrorMessage = "";
  bool _isBuilding = false;

  // --- UI Getter ---
  int? get estimatedFeeSats => _estimatedFeeSats;
  String get finalErrorMessage => _finalErrorMessage;
  bool get isBuilding => _isBuilding;
  List<UtxoState> get selectedUtxoList => _selectedUtxoList;
  SplitCriteria? get selectedCriteria => _selectedCriteria;
  bool get isUtxoSelected => _selectedUtxoList.isNotEmpty;
  bool get hasFeeRate => feeRateController.text.isNotEmpty;
  BitcoinUnit get currentUnit => _preferenceProvider.currentUnit;
  int get _selectedUtxoAmount => _selectedUtxoList.isNotEmpty ? _selectedUtxoList.first.amount : 0;
  String get _splitAmountInput => amountController.text.replaceAll(',', '').trim();

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
      return '$utxoAmountText를 $formattedSplitAmount씩 나눌게요';
    } else {
      return '$utxoAmountText를 나눌게요';
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
      return '선택한 UTXO 금액보다 작게 입력해주세요';
    }

    if (_isDustError) {
      return '수수료를 포함하면 나눌 수 없는 금액이에요';
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

    bool isInputValid = true;
    if (_selectedCriteria == null || _selectedUtxoList.isEmpty || hasAmountError) {
      isInputValid = false;
    } else if (_selectedCriteria == SplitCriteria.byAmount) {
      isInputValid = splitAmountSats > 0 && splitAmountSats < _selectedUtxoAmount;
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
      _estimatedFeeSats = _estimateFeeForFixedAmountSplit(utxo, walletItem, splitAmountSats, feeRate);
      if (_estimatedFeeSats == null) {
        _isDustError = true;
      }
    } else {
      _estimatedFeeSats = null;
    }
  }

  int? _estimateFeeForFixedAmountSplit(
    UtxoState utxo,
    WalletListItemBase walletItem,
    int amountPerOutput,
    double feeRate,
  ) {
    if (amountPerOutput <= dustLimit) return null;

    final isSingleSig = walletItem.walletType == WalletType.singleSignature;
    final double oneOutputTxVBytes =
        isSingleSig
            ? 110
            : 132 +
                ((walletItem as MultisigWalletListItem).signers.length - 2) * 8 +
                (walletItem.requiredSignatureCount - 1) * 18;
    final double outputVBytes = isSingleSig ? 31 : 43;

    final feePerOutput = outputVBytes * feeRate;
    double firstLeft = utxo.amount - (oneOutputTxVBytes * feeRate) - amountPerOutput;

    if (firstLeft <= dustLimit + feePerOutput) return null;

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

    final totalOutputCount = count + 1; // +1 for sweep output
    return ((oneOutputTxVBytes + outputVBytes * (totalOutputCount - 1)) * feeRate +
            (totalOutputCount >= 253 ? 2 * feeRate : 0))
        .ceil();
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

    if (_selectedCriteria == SplitCriteria.byAmount) {
      if (splitAmountSats <= 0) return false;
      if (splitAmountSats >= _selectedUtxoAmount) return false;
      if (_estimatedFeeSats == null) return false;
    }
    return true;
  }

  bool get showSplitResultBox {
    if (!isSplitValid) return false;
    return _selectedCriteria == SplitCriteria.byAmount && !amountFocusNode.hasFocus;
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
      }
      // TODO: evenly, manually 추가 구현 시 분기 처리

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

  @override
  void dispose() {
    amountController.dispose();
    amountFocusNode.dispose();
    feeRateController.dispose();
    feeRateFocusNode.dispose();
    super.dispose();
  }
}
