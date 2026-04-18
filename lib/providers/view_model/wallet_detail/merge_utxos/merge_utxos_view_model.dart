import 'dart:async';

import 'package:coconut_wallet/constants/dust_constants.dart';
import 'package:coconut_wallet/enums/utxo_merge_enums.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/utils/bitcoin/transaction_util.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fee_rate_mixin.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';

part 'merge_utxos_models.dart';

enum MergeState { idle, preparing, ready, notEnoughSelectedUtxo, failed }

enum MergeRecommendationLevel { recommended, neutral, discouraged }

typedef MergeRecommendationLevelAndInfo = ({MergeRecommendationLevel mergeRecommendationLevel, String message});

class MergeTransactionInputSnapshot {
  final String selectedReceiveAddress;
  final List<UtxoState> selectedUtxos;
  final double inputFeeRate;
  final int totalInputAmount;

  const MergeTransactionInputSnapshot({
    required this.selectedReceiveAddress,
    required this.selectedUtxos,
    required this.inputFeeRate,
    required this.totalInputAmount,
  });
}

class MergeUtxosViewModel extends ChangeNotifier with FeeRateMixin {
  final int walletId;
  final UtxoRepository _utxoRepository;
  final UtxoTagProvider _utxoTagProvider;
  final SendInfoProvider _sendInfoProvider;
  final WalletProvider _walletProvider;
  late final WalletListItemBase _wallet;
  late final int _dustThreshold;
  late String _selectedReceiveAddress;
  late final List<ReceiveAddressOption> _nextReceiveAddressesOfAllWallets;

  MergeUtxosViewModel(
    this.walletId,
    this._utxoRepository,
    this._utxoTagProvider,
    this._sendInfoProvider,
    this._walletProvider,
  ) {
    _wallet = _walletProvider.getWalletById(walletId);
    _dustThreshold = _wallet.walletType.addressType.dustThreshold;
    _initAddresses();
    refreshRecommendedFees();
  }

  void _initAddresses() {
    _nextReceiveAddressesOfAllWallets =
        _walletProvider.walletItemList.map((wallet) {
          final addressObject = _walletProvider.getReceiveAddress(wallet.id);
          if (wallet.id == walletId) {
            _selectedReceiveAddress = addressObject.address;
          }
          return ReceiveAddressOption.fromWalletAddress(addressObject, walletName: wallet.name);
        }).toList();
  }

  List<ReceiveAddressOption> get nextReceiveAddressesOfAllWallets => _nextReceiveAddressesOfAllWallets;
  List<UtxoState> _utxoList = [];
  List<UtxoState> get utxoList => _utxoList;
  late UtxoMergeStep _currentStep;
  UtxoMergeStep get currentStep => _currentStep;
  UtxoMergeCriteria? _selectedMergeCriteria;
  bool _didConfirmMergeCriteria = false;
  UtxoAmountCriteria? _selectedAmountCriteria;
  String? _customAmountCriteriaText;
  bool _isCustomAmountLessThan = false;
  bool _didConfirmAmountCriteria = false;
  bool _didConfirmTagCriteria = false;
  String? _selectedTagName;
  String? _customReceiveAddressText;
  bool _isCustomReceiveAddressValidFormat = false;
  bool _isCustomReceiveAddressOwnedByAnyWallet = false;
  Set<String>? _editedSelectedUtxoIds;
  int? _estimatedMergeFeeSats;
  bool _isEstimatedMergeFeeLoading = false;
  bool _excludeDustUtxos = false;
  double? _appliedMergeFeeRate;
  TransactionBuildResult? _txBuildResult;
  String? _txKey;
  MergeState _mergeState = MergeState.idle;
  int _txPreparationNonce = 0;
  int _receiveAddressSummaryAnimationNonce = 0;
  final TextEditingController feeRateController = TextEditingController();
  final FocusNode feeRateFocusNode = FocusNode();
  String _estimatedFeeText = '-';
  String? _unexpectedErrorMessage;
  Timer? _estimatePrepareDebounceTimer;
  bool _isDisposed = false;
  String get unexpectedErrorMessage => _unexpectedErrorMessage ?? '';
  String get estimatedFeeText => _estimatedFeeText;

  int get utxoCount => _utxoList.length;
  UtxoMergeCriteria? get selectedMergeCriteria => _selectedMergeCriteria;
  bool get didConfirmMergeCriteria => _didConfirmMergeCriteria;
  UtxoAmountCriteria? get selectedAmountCriteria => _selectedAmountCriteria;
  String? get customAmountCriteriaText => _customAmountCriteriaText;
  bool get isCustomAmountLessThan => _isCustomAmountLessThan;
  bool get didConfirmAmountCriteria => _didConfirmAmountCriteria;
  bool get didConfirmTagCriteria => _didConfirmTagCriteria;
  String? get selectedTagName => _selectedTagName;
  String? get selectedReceiveAddress => _selectedReceiveAddress;
  String? get customReceiveAddressText => _customReceiveAddressText;
  bool get isCustomReceiveAddressValidFormat => _isCustomReceiveAddressValidFormat;
  bool get isCustomReceiveAddressOwnedByAnyWallet => _isCustomReceiveAddressOwnedByAnyWallet;
  Set<String>? get editedSelectedUtxoIds => _editedSelectedUtxoIds;
  int? get estimatedMergeFeeSats => _estimatedMergeFeeSats;
  bool get isEstimatedMergeFeeLoading => _isEstimatedMergeFeeLoading;
  bool get excludeDustUtxos => _excludeDustUtxos;
  double? get appliedMergeFeeRate => _appliedMergeFeeRate;
  TransactionBuildResult? get preparedMergeTransactionBuildResult => _txBuildResult;
  String? get txKeyState => _txKey;
  MergeState get mergeState => _mergeState;
  int get txPreparationNonce => _txPreparationNonce;
  int get receiveAddressSummaryAnimationNonce => _receiveAddressSummaryAnimationNonce;
  UtxoMergeCriteria get defaultCriteria => UtxoMergeCriteria.smallAmounts;
  UtxoMergeCriteria get currentCriteria => _selectedMergeCriteria ?? defaultCriteria;
  bool get hasUnexpectedError => unexpectedErrorMessage.isNotEmpty;
  bool get isTransactionSummaryFailed => _mergeState == MergeState.failed;

  bool get isMergeButtonVisible => _mergeState == MergeState.ready || _mergeState == MergeState.notEnoughSelectedUtxo;
  bool get isMergeButtonEnabled => _mergeState == MergeState.ready;
  bool get isDirectInputReceiveAddressWarning {
    return _customReceiveAddressText != null &&
        _selectedReceiveAddress == _customReceiveAddressText &&
        _isCustomReceiveAddressValidFormat &&
        !_isCustomReceiveAddressOwnedByAnyWallet;
  }

  String get selectedUtxosTotalAmountText {
    return '${BalanceFormatUtil.formatSatoshiToReadableBitcoin(selectedUtxosTotalAmountSats)} BTC';
  }

  String get estimatedMergeFeeTextDisplay {
    if (_isEstimatedMergeFeeLoading) return '...';
    if (_estimatedMergeFeeSats == null) return '-';
    return '${BalanceFormatUtil.formatSatoshiToReadableBitcoin(_estimatedMergeFeeSats!, forceEightDecimals: true)} BTC';
  }

  UtxoAmountCriteria get defaultAmountCriteria =>
      firstAvailableRecommendedAmountCriteria ?? UtxoAmountCriteria.below00001;
  UtxoAmountCriteria get currentAmountCriteria => _selectedAmountCriteria ?? defaultAmountCriteria;
  int? get currentAmountThresholdSats {
    return switch (currentAmountCriteria) {
      UtxoAmountCriteria.below001 => 1_000_000,
      UtxoAmountCriteria.below0001 => 100_000,
      UtxoAmountCriteria.below00001 => 10_000,
      UtxoAmountCriteria.custom => _customAmountThresholdSats,
    };
  }

  String? get mostUsedTagName {
    final tagCounts = <String, int>{};

    for (final utxo in _utxoList.where((utxo) => !utxo.isLocked)) {
      for (final tag in utxo.tags ?? const <UtxoTag>[]) {
        tagCounts[tag.name] = (tagCounts[tag.name] ?? 0) + 1;
      }
    }

    String? result;
    int maxCount = 0;
    tagCounts.forEach((tagName, count) {
      if (count > maxCount) {
        maxCount = count;
        result = tagName;
      }
    });

    return maxCount >= 2 ? result : null;
  }

  String? get effectiveSelectedTagName => _selectedTagName ?? mostUsedTagName;
  List<UtxoState> get candidateUtxosForCurrentCriteria {
    final utxos = _utxoList.where((utxo) => !utxo.isLocked).toList();
    switch (currentCriteria) {
      case UtxoMergeCriteria.smallAmounts:
        final satsThreshold = currentAmountThresholdSats;
        return utxos.where((utxo) {
          if (satsThreshold == null) return false;
          return _isCustomAmountLessThan ? utxo.amount < satsThreshold : utxo.amount <= satsThreshold;
        }).toList();
      case UtxoMergeCriteria.sameAddress:
        final addressCounts = <String, int>{};
        for (final utxo in utxos) {
          addressCounts[utxo.to] = (addressCounts[utxo.to] ?? 0) + 1;
        }
        return utxos.where((utxo) => (addressCounts[utxo.to] ?? 0) >= 2).toList();
      case UtxoMergeCriteria.sameTag:
        final tagName = effectiveSelectedTagName;
        if (tagName == null || tagName.isEmpty) return [];
        return utxos.where((utxo) => (utxo.tags ?? []).any((tag) => tag.name == tagName)).toList();
    }
  }

  List<UtxoState> get selectedUtxosBeforeDustExclusion {
    final candidateUtxos = candidateUtxosForCurrentCriteria;
    final editedSelectedUtxoIds = _editedSelectedUtxoIds;
    if (editedSelectedUtxoIds == null) return candidateUtxos;
    return candidateUtxos.where((utxo) => editedSelectedUtxoIds.contains(utxo.utxoId)).toList();
  }

  List<UtxoState> get selectedUtxosForCurrentCriteria {
    final selectedUtxos = selectedUtxosBeforeDustExclusion;
    if (!_excludeDustUtxos) return selectedUtxos;
    return selectedUtxos.where((utxo) => !_isSuspiciousDustUtxo(utxo)).toList();
  }

  bool get hasDustUtxosInInputs => candidateUtxosForCurrentCriteria.any(_isSuspiciousDustUtxo);
  Set<String> get reusedAddressesInWallet {
    final counts = <String, int>{};
    for (final utxo in _utxoList) {
      counts[utxo.to] = (counts[utxo.to] ?? 0) + 1;
    }
    return counts.entries.where((entry) => entry.value >= 2).map((entry) => entry.key).toSet();
  }

  UtxoAmountCriteria? get firstAvailableRecommendedAmountCriteria {
    for (final criteria in recommendedAmountCriteriaItems.reversed) {
      if (hasCandidateUtxosForAmountCriteria(criteria)) {
        if (criteria == UtxoAmountCriteria.below00001) {
          continue;
        }
        return criteria;
      }
    }
    return null;
  }

  static const List<UtxoAmountCriteria> recommendedAmountCriteriaItems = [
    UtxoAmountCriteria.below001,
    UtxoAmountCriteria.below0001,
    UtxoAmountCriteria.below00001,
  ];

  void initialize() {
    final allUtxos = _utxoRepository.getUtxoStateList(walletId);
    _utxoList = allUtxos.where((utxo) => utxo.status == UtxoStatus.unspent).toList();
    _currentStep =
        utxoList.length >= 2 && utxoList.length < 11 ? UtxoMergeStep.entry : UtxoMergeStep.selectMergeCriteria;

    for (var utxo in _utxoList) {
      utxo.tags = _utxoTagProvider.getUtxoTagsByUtxoId(walletId, utxo.utxoId);
    }

    notifyListeners();
  }

  void setCurrentStep(UtxoMergeStep step) {
    _currentStep = step;
    notifyListeners();
  }

  void confirmMergeCriteriaSelection(UtxoMergeCriteria selectedItem) {
    final previousMergeCriteria = _selectedMergeCriteria;
    final didMergeCriteriaChange = previousMergeCriteria != selectedItem;

    _selectedMergeCriteria = selectedItem;
    _didConfirmMergeCriteria = true;

    if (didMergeCriteriaChange) {
      switch (selectedItem) {
        case UtxoMergeCriteria.smallAmounts:
          _didConfirmAmountCriteria = false;
          _didConfirmTagCriteria = false;
          _selectedTagName = null;
          _editedSelectedUtxoIds = null;
          _estimatedMergeFeeSats = null;
          break;
        case UtxoMergeCriteria.sameTag:
          _didConfirmTagCriteria = false;
          _editedSelectedUtxoIds = null;
          _estimatedMergeFeeSats = null;
          break;
        case UtxoMergeCriteria.sameAddress:
          _didConfirmTagCriteria = false;
          _selectedTagName = null;
          _editedSelectedUtxoIds = null;
          _estimatedMergeFeeSats = null;
          break;
      }
    }
  }

  void confirmAmountCriteriaSelection({
    required UtxoAmountCriteria criteria,
    required String? customAmountText,
    required bool isLessThan,
  }) {
    _selectedAmountCriteria = criteria;
    _customAmountCriteriaText = customAmountText;
    _isCustomAmountLessThan = isLessThan;
    _editedSelectedUtxoIds = null;
    _estimatedMergeFeeSats = null;
    _didConfirmAmountCriteria = true;
  }

  void confirmTagCriteriaSelection(String? selectedTagName) {
    _selectedTagName = selectedTagName;
    _didConfirmTagCriteria = selectedTagName != null;
    _editedSelectedUtxoIds = null;
    _estimatedMergeFeeSats = null;
  }

  void setSelectedReceiveAddress(String value) => _selectedReceiveAddress = value;
  void setCustomReceiveAddressText(String? value) => _customReceiveAddressText = value;
  void setIsCustomReceiveAddressValidFormat(bool value) => _isCustomReceiveAddressValidFormat = value;
  void setIsCustomReceiveAddressOwnedByAnyWallet(bool value) => _isCustomReceiveAddressOwnedByAnyWallet = value;

  bool isAnimatedHeaderStep(UtxoMergeStep step) {
    return step == UtxoMergeStep.selectMergeCriteria ||
        step == UtxoMergeStep.selectAmountCriteria ||
        step == UtxoMergeStep.selectTag ||
        step == UtxoMergeStep.selectReceiveAddress;
  }

  List<UtxoMergeStep> visibleOptionPickerStepsFor(UtxoMergeStep step) {
    switch (step) {
      case UtxoMergeStep.selectMergeCriteria:
        return const [UtxoMergeStep.selectMergeCriteria];
      case UtxoMergeStep.selectAmountCriteria:
        return const [UtxoMergeStep.selectAmountCriteria, UtxoMergeStep.selectMergeCriteria];
      case UtxoMergeStep.selectTag:
        return const [UtxoMergeStep.selectTag, UtxoMergeStep.selectMergeCriteria];
      case UtxoMergeStep.selectReceiveAddress:
        switch (currentCriteria) {
          case UtxoMergeCriteria.sameAddress:
            return const [UtxoMergeStep.selectReceiveAddress, UtxoMergeStep.selectMergeCriteria];
          case UtxoMergeCriteria.sameTag:
            return const [
              UtxoMergeStep.selectReceiveAddress,
              UtxoMergeStep.selectTag,
              UtxoMergeStep.selectMergeCriteria,
            ];
          case UtxoMergeCriteria.smallAmounts:
            return const [
              UtxoMergeStep.selectReceiveAddress,
              UtxoMergeStep.selectAmountCriteria,
              UtxoMergeStep.selectMergeCriteria,
            ];
        }
      case UtxoMergeStep.entry:
        return const [];
    }
  }

  void toggleDustExclusion() {
    final nextExcludeDustUtxos = !_excludeDustUtxos;
    final selectedUtxoIdsBeforeToggle = selectedUtxosBeforeDustExclusion.map((utxo) => utxo.utxoId).toSet();

    _excludeDustUtxos = nextExcludeDustUtxos;
    if (nextExcludeDustUtxos) {
      _editedSelectedUtxoIds =
          selectedUtxoIdsBeforeToggle.where((utxoId) {
            final utxo = candidateUtxosForCurrentCriteria.firstWhere((item) => item.utxoId == utxoId);
            return utxo.amount > _dustThreshold;
          }).toSet();
      return;
    }

    _editedSelectedUtxoIds = null;
  }

  void commitEditedSelectedUtxoIds(Set<String> committedSelectedUtxoIds) {
    _editedSelectedUtxoIds = committedSelectedUtxoIds;
    if (selectionContainsDust(committedSelectedUtxoIds)) {
      _excludeDustUtxos = false;
    }
  }

  /// selectReceiveAddress 스텝이 아닌 단계로 전환될 때 진행 상태를 일괄 리셋한다.
  void resetReceiveAddressSummaryForStepTransition() {
    _txPreparationNonce = _txPreparationNonce + 1;
    _txBuildResult = null;
    _txKey = null;
    _mergeState = MergeState.idle;
    _estimatedMergeFeeSats = null;
    _isEstimatedMergeFeeLoading = false;
    _appliedMergeFeeRate = null;
    notifyListeners();
  }

  void setEstimatedFeeText(String text) {
    if (_estimatedFeeText == text) return;
    _estimatedFeeText = text;
    notifyListeners();
  }

  void syncEstimatedFeeText() {
    setEstimatedFeeText(estimatedMergeFeeTextDisplay);
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
    notifyListeners();
  }

  Future<bool> refreshRecommendedFees() async {
    return fetchRecommendedFees(
      currentFeeRateText: feeRateController.text,
      onDefaultFeeRateSet: (text) => feeRateController.text = text,
    );
  }

  int candidateUtxoCountForAmountCriteria(UtxoAmountCriteria criteria) {
    final utxos = _utxoList.where((utxo) => !utxo.isLocked).toList();
    final satsThreshold = switch (criteria) {
      UtxoAmountCriteria.below001 => 1_000_000,
      UtxoAmountCriteria.below0001 => 100_000,
      UtxoAmountCriteria.below00001 => 10_000,
      UtxoAmountCriteria.custom => null,
    };

    if (satsThreshold == null) return 0;
    return utxos.where((utxo) => utxo.amount <= satsThreshold).length;
  }

  int candidateUtxoCountForCustomAmountText(String text, {required bool isLessThan}) {
    if (text.trim().isEmpty) return 0;

    final btcAmount = double.tryParse(text.trim());
    if (btcAmount == null || btcAmount == 0) return 0;

    final satsThreshold = UnitUtil.convertBitcoinToSatoshi(btcAmount);
    final utxos = _utxoList.where((utxo) => !utxo.isLocked).toList();

    return utxos.where((utxo) => isLessThan ? utxo.amount < satsThreshold : utxo.amount <= satsThreshold).length;
  }

  bool hasCandidateUtxosForAmountCriteria(UtxoAmountCriteria criteria) {
    return candidateUtxoCountForAmountCriteria(criteria) >= 2;
  }

  bool selectionContainsDust(Set<String> selectedUtxoIds) {
    return candidateUtxosForCurrentCriteria.any(
      (utxo) => selectedUtxoIds.contains(utxo.utxoId) && _isSuspiciousDustUtxo(utxo),
    );
  }

  String get feeRateInput => feeRateController.text.trim();

  bool get canPrepareMergeTransaction {
    return _currentStep == UtxoMergeStep.selectReceiveAddress &&
        _selectedReceiveAddress.isNotEmpty &&
        selectedUtxosForCurrentCriteria.length >= 2 &&
        feeRateInput.isNotEmpty;
  }

  // TODO: 이렇게 키를 생성해서 사용하는 것이 좋은 방법인지 확인
  String? get mergeTransactionPreparationKey {
    if (!canPrepareMergeTransaction) return null;

    final selectedUtxoIds = selectedUtxosForCurrentCriteria.map((utxo) => utxo.utxoId).toList()..sort();
    return [
      currentCriteria.name,
      currentAmountCriteria.name,
      _selectedReceiveAddress,
      feeRateInput.isEmpty ? 'auto' : feeRateInput,
      _excludeDustUtxos,
      selectedUtxoIds.join(','),
    ].join('|');
  }

  bool get hasMergeableTaggedUtxos {
    final tagCounts = <String, int>{};
    for (final utxo in _utxoList) {
      final tags = utxo.tags;
      if (tags == null || tags.isEmpty) continue;

      final uniqueTagNames = tags.map((tag) => tag.name).toSet();
      for (final tagName in uniqueTagNames) {
        final count = (tagCounts[tagName] ?? 0) + 1;
        if (count >= 2) return true;
        tagCounts[tagName] = count;
      }
    }
    return false;
  }

  bool get hasSameAddressUtxos {
    final addressSet = <String>{};
    for (final utxo in _utxoList) {
      if (!addressSet.add(utxo.to)) return true;
    }
    return false;
  }

  int get selectedUtxosTotalAmountSats {
    return selectedUtxosForCurrentCriteria.fold<int>(0, (sum, utxo) => sum + utxo.amount);
  }

  int get selectedUtxoCount => selectedUtxosForCurrentCriteria.length;

  MergeRecommendationLevelAndInfo? get mergeRecommendationLevelAndInfo {
    if (_mergeState != MergeState.ready) return null;
    if (_appliedMergeFeeRate == null) return null;
    if (_estimatedMergeFeeSats == null) return null;

    final inputCount = selectedUtxoCount;
    if (inputCount < 2) return null;

    final inputSize = estimateVSizePerInput(
      isMultisig: _wallet.walletType != WalletType.singleSignature,
      requiredSignatureCount: _wallet.multisigConfig?.requiredSignature,
      totalSignerCount: _wallet.multisigConfig?.totalSigner,
    );

    const expectedfutureFeeRate = 15.0;
    final futureSavingFee = (inputCount - 1) * inputSize * expectedfutureFeeRate;
    final currentFeeRate = _appliedMergeFeeRate!;
    final currentFee = _estimatedMergeFeeSats!;
    const discouragedFeeRateThreshold = 5.0;
    final ratio = futureSavingFee / currentFee;
    // discouraged
    if (ratio < 1.0) {
      if (currentFeeRate >= discouragedFeeRateThreshold) {
        // 현재 수수료가 높아 합치기에는 적절하지 않아요
        return (
          mergeRecommendationLevel: MergeRecommendationLevel.discouraged,
          message: t.merge_utxos_screen.merge_cta_discouraged_high_fee,
        );
      }
      // 합치는 비용이 절약되는 수수료보다 더 커요
      return (
        mergeRecommendationLevel: MergeRecommendationLevel.discouraged,
        message: t.merge_utxos_screen.merge_cta_discouraged_costly,
      );
    }

    final savingAmount = futureSavingFee - currentFee;
    // neutral
    if (ratio < 1.5) {
      final feeToInputRatioPercent = ((currentFee / selectedUtxosTotalAmountSats * 100) * 100).roundToDouble() / 100;
      if (feeToInputRatioPercent >= 10) {
        // 수수료 비중이 높아요
        return (
          mergeRecommendationLevel: MergeRecommendationLevel.neutral,
          message: t.merge_utxos_screen.merge_cta_high_fee_ratio(
            ratio: feeToInputRatioPercent % 1 == 0 ? feeToInputRatioPercent.toInt() : feeToInputRatioPercent,
          ),
        );
      }

      if (savingAmount < 1000) {
        // 합쳐도 수수료 절감 효과가 크지 않아요
        return (
          mergeRecommendationLevel: MergeRecommendationLevel.neutral,
          message: t.merge_utxos_screen.merge_cta_neutral_low_saving,
        );
      }

      if (inputCount <= 3) {
        // 합치지 않아도 충분히 효율적이에요
        return (
          mergeRecommendationLevel: MergeRecommendationLevel.neutral,
          message: t.merge_utxos_screen.merge_cta_efficient_without_merge,
        );
      }
    }

    final savingAmountText = savingAmount.round().toThousandsSeparatedString();
    return (
      mergeRecommendationLevel: MergeRecommendationLevel.recommended,
      message: t.merge_utxos_screen.future_fee_saving(amount: savingAmountText),
    );
  }

  bool saveForNext() {
    final txBuildResult = _txBuildResult;
    if (txBuildResult == null || !txBuildResult.isSuccess || txBuildResult.transaction == null) {
      return false;
    }

    _sendInfoProvider.clear();
    _sendInfoProvider.setSendEntryPoint(SendEntryPoint.walletDetail);
    _sendInfoProvider.setWalletId(_wallet.id);
    _sendInfoProvider.setTransaction(txBuildResult.transaction!);
    _sendInfoProvider.setIsMultisig(_wallet.walletType == WalletType.multiSignature);
    _sendInfoProvider.setWalletImportSource(_wallet.walletImportSource);
    _sendInfoProvider.setFeeRate(_appliedMergeFeeRate!);
    _sendInfoProvider.setIsMaxMode(false);
    return true;
  }

  MergeTransactionInputSnapshot? get mergeTransactionInputSnapshot {
    final selectedReceiveAddress = _selectedReceiveAddress;
    final selectedUtxos = selectedUtxosForCurrentCriteria;
    final inputFeeRate = double.tryParse(feeRateInput);

    if (_currentStep != UtxoMergeStep.selectReceiveAddress ||
        selectedReceiveAddress.isEmpty ||
        selectedUtxos.length < 2 ||
        inputFeeRate == null) {
      return null;
    }

    return MergeTransactionInputSnapshot(
      selectedReceiveAddress: selectedReceiveAddress,
      selectedUtxos: selectedUtxos,
      inputFeeRate: inputFeeRate,
      totalInputAmount: selectedUtxos.fold<int>(0, (sum, utxo) => sum + utxo.amount),
    );
  }

  String? get selectedReceiveAddressWalletName {
    if (_selectedReceiveAddress.isEmpty) return null;

    final matchedOption = _nextReceiveAddressesOfAllWallets.cast<ReceiveAddressOption?>().firstWhere(
      (item) => item?.address == _selectedReceiveAddress,
      orElse: () => null,
    );

    return matchedOption?.walletName;
  }

  bool shouldSkipMergeTransactionRebuild({required bool forceRebuild, required String preparationKey}) {
    return !forceRebuild && _mergeState != MergeState.preparing && _txKey == preparationKey && _txBuildResult != null;
  }

  void resetPreparedMergeTransaction({required MergeState summaryState}) {
    _txBuildResult = null;
    _txKey = null;
    _estimatedMergeFeeSats = null;
    _isEstimatedMergeFeeLoading = false;
    _appliedMergeFeeRate = null;
    _mergeState = summaryState;
  }

  void beginMergeTransactionPreparation({required int nonce, required String preparationKey}) {
    _txPreparationNonce = nonce;
    _txKey = preparationKey;
    _isEstimatedMergeFeeLoading = true;
    _mergeState = MergeState.preparing;
    _receiveAddressSummaryAnimationNonce = _receiveAddressSummaryAnimationNonce + 1;
  }

  void applyPreparedMergeTransactionResult({
    required TransactionBuildResult txBuildResult,
    required double inputFeeRate,
  }) {
    _txBuildResult = txBuildResult;
    _appliedMergeFeeRate = inputFeeRate;
    _estimatedMergeFeeSats = txBuildResult.estimatedFee - (txBuildResult.unintendedDustFee ?? 0);
    _isEstimatedMergeFeeLoading = false;
    _mergeState = txBuildResult.isSuccess ? MergeState.ready : MergeState.failed;
    _receiveAddressSummaryAnimationNonce = _receiveAddressSummaryAnimationNonce + 1;
  }

  void applyPreparedMergeTransactionUnexpectedFailure(Object error) {
    _unexpectedErrorMessage = error.toString();
    _txBuildResult = null;
    _estimatedMergeFeeSats = null;
    _isEstimatedMergeFeeLoading = false;
    _appliedMergeFeeRate = null;
    _mergeState = MergeState.failed;
    _receiveAddressSummaryAnimationNonce = _receiveAddressSummaryAnimationNonce + 1;
  }

  int? get _customAmountThresholdSats {
    if (_customAmountCriteriaText == null || _customAmountCriteriaText!.trim().isEmpty) {
      return null;
    }
    try {
      return UnitUtil.convertBitcoinToSatoshi(double.parse(_customAmountCriteriaText!.trim()));
    } catch (_) {
      return null;
    }
  }

  bool _isSuspiciousDustUtxo(UtxoState utxo) => _dustThreshold > 0 && utxo.amount <= _dustThreshold;

  void scheduleMergeTransactionPreparation({Duration delay = const Duration(seconds: 1)}) {
    _estimatePrepareDebounceTimer?.cancel();
    _estimatePrepareDebounceTimer = Timer(delay, () {
      if (_isDisposed) return;
      unawaited(prepareMergeTransaction());
    });
  }

  void runMergeTransactionPreparationNow() {
    _estimatePrepareDebounceTimer?.cancel();
    unawaited(prepareMergeTransaction());
  }

  Future<void> prepareMergeTransaction({bool forceRebuild = false}) async {
    Logger.log('--> prepareMergeTransaction');
    final preparationKey = mergeTransactionPreparationKey;
    if (preparationKey == null) {
      resetPreparedMergeTransaction(
        summaryState: selectedUtxoCount >= 2 ? MergeState.idle : MergeState.notEnoughSelectedUtxo,
      );
      notifyListeners();
      syncEstimatedFeeText();
      return;
    }

    if (shouldSkipMergeTransactionRebuild(forceRebuild: forceRebuild, preparationKey: preparationKey)) {
      return;
    }

    final inputSnapshot = mergeTransactionInputSnapshot;
    if (inputSnapshot == null) {
      resetPreparedMergeTransaction(summaryState: MergeState.notEnoughSelectedUtxo);
      notifyListeners();
      syncEstimatedFeeText();
      return;
    }

    final nonce = _txPreparationNonce + 1;
    beginMergeTransactionPreparation(nonce: nonce, preparationKey: preparationKey);
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
    if (_isDisposed || nonce != _txPreparationNonce) return;

    try {
      final changeAddress = _walletProvider.getChangeAddress(walletId);

      final txBuildResult =
          TransactionBuilder(
            availableUtxos: inputSnapshot.selectedUtxos,
            recipients: {inputSnapshot.selectedReceiveAddress: inputSnapshot.totalInputAmount},
            feeRate: inputSnapshot.inputFeeRate,
            changeDerivationPath: changeAddress.derivationPath,
            walletListItemBase: _wallet,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: true,
          ).build();

      if (_isDisposed || nonce != _txPreparationNonce) return;
      applyPreparedMergeTransactionResult(txBuildResult: txBuildResult, inputFeeRate: inputSnapshot.inputFeeRate);
      notifyListeners();
      syncEstimatedFeeText();
    } catch (e) {
      if (_isDisposed || nonce != _txPreparationNonce) return;
      applyPreparedMergeTransactionUnexpectedFailure(e);
      notifyListeners();
      syncEstimatedFeeText();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _estimatePrepareDebounceTimer?.cancel();
    feeRateController.dispose();
    feeRateFocusNode.dispose();
    super.dispose();
  }
}
