import 'package:coconut_wallet/enums/utxo_merge_enums.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fee_rate_mixin.dart';
import 'package:flutter/material.dart';

enum MergeTransactionSummaryState { idle, preparing, ready, invalidSelection, failed }

class MergeUtxosViewModel extends ChangeNotifier with FeeRateMixin {
  final int walletId;
  final UtxoRepository _utxoRepository;
  final UtxoTagProvider _utxoTagProvider;

  MergeUtxosViewModel(this.walletId, this._utxoRepository, this._utxoTagProvider);

  List<UtxoState> _utxoList = [];
  List<UtxoState> get utxoList => _utxoList;
  late UtxoMergeStep _currentStep;
  UtxoMergeStep get currentStep => _currentStep;
  UtxoMergeCriteria? _selectedMergeCriteria;
  bool _didConfirmMergeCriteria = false;
  bool _isBottomSheetOpen = false;
  UtxoAmountCriteria? _selectedAmountCriteria;
  String? _customAmountCriteriaText;
  bool _isCustomAmountLessThan = false;
  bool _didConfirmAmountCriteria = false;
  bool _didConfirmTagCriteria = false;
  String? _selectedTagName;
  String? _selectedReceiveAddress;
  String? _customReceiveAddressText;
  bool _isCustomReceiveAddressValidFormat = false;
  bool _isCustomReceiveAddressOwnedByAnyWallet = false;
  Set<String>? _editedSelectedUtxoIds;
  int? _estimatedMergeFeeSats;
  bool _isEstimatedMergeFeeLoading = false;
  bool _excludeDustUtxos = false;
  bool _needsManualFeeRateInput = false;
  double? _appliedMergeFeeRate;
  UtxoMergeStep? _displayedHeaderStep;
  UtxoMergeStep? _pendingHeaderStep;
  UtxoMergeStep? _lastObservedHeaderStep;
  bool _isHeaderFadingOut = false;
  int _headerAnimationNonce = 0;
  UtxoMergeStep? _displayedOptionPickerStep;
  UtxoMergeStep? _pendingOptionPickerStep;
  UtxoMergeStep? _lastObservedOptionPickerStep;
  int _optionPickerAnimationNonce = 0;
  final List<UtxoMergeStep> _visibleOptionPickerSteps = [];
  TransactionBuildResult? _preparedMergeTransactionBuildResult;
  MergeTransactionSummaryState _mergeTransactionSummaryState = MergeTransactionSummaryState.idle;
  int _mergeTransactionPreparationNonce = 0;
  int _receiveAddressSummaryAnimationNonce = 0;
  final TextEditingController feeRateController = TextEditingController();
  final FocusNode feeRateFocusNode = FocusNode();
  String _estimatedFeeText = '-';
  int _dustThreshold = 0;
  String? _unexpectedErrorMessage;
  String get unexpectedErrorMessage => _unexpectedErrorMessage ?? '';
  String get estimatedFeeText => _estimatedFeeText;

  int get utxoCount => _utxoList.length;
  UtxoMergeCriteria? get selectedMergeCriteria => _selectedMergeCriteria;
  bool get didConfirmMergeCriteria => _didConfirmMergeCriteria;
  bool get isBottomSheetOpen => _isBottomSheetOpen;
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
  bool get needsManualFeeRateInput => _needsManualFeeRateInput;
  double? get appliedMergeFeeRate => _appliedMergeFeeRate;
  UtxoMergeStep? get displayedHeaderStep => _displayedHeaderStep;
  UtxoMergeStep? get pendingHeaderStep => _pendingHeaderStep;
  UtxoMergeStep? get lastObservedHeaderStep => _lastObservedHeaderStep;
  bool get isHeaderFadingOut => _isHeaderFadingOut;
  int get headerAnimationNonce => _headerAnimationNonce;
  UtxoMergeStep? get displayedOptionPickerStep => _displayedOptionPickerStep;
  UtxoMergeStep? get pendingOptionPickerStep => _pendingOptionPickerStep;
  UtxoMergeStep? get lastObservedOptionPickerStep => _lastObservedOptionPickerStep;
  int get optionPickerAnimationNonce => _optionPickerAnimationNonce;
  List<UtxoMergeStep> get visibleOptionPickerSteps => _visibleOptionPickerSteps;
  TransactionBuildResult? get preparedMergeTransactionBuildResult => _preparedMergeTransactionBuildResult;
  MergeTransactionSummaryState get mergeTransactionSummaryState => _mergeTransactionSummaryState;
  int get mergeTransactionPreparationNonce => _mergeTransactionPreparationNonce;
  int get receiveAddressSummaryAnimationNonce => _receiveAddressSummaryAnimationNonce;
  int get dustThreshold => _dustThreshold;
  UtxoMergeCriteria get defaultMergeCriteria => UtxoMergeCriteria.smallAmounts;
  UtxoMergeCriteria get currentMergeCriteria => _selectedMergeCriteria ?? defaultMergeCriteria;
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
    switch (currentMergeCriteria) {
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

  bool get hasDustUtxosInCurrentCandidates => candidateUtxosForCurrentCriteria.any(_isSuspiciousDustUtxo);
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

  void setSelectedMergeCriteria(UtxoMergeCriteria? value) => _selectedMergeCriteria = value;
  void setDidConfirmMergeCriteria(bool value) => _didConfirmMergeCriteria = value;
  void setIsBottomSheetOpen(bool value) => _isBottomSheetOpen = value;
  void setSelectedAmountCriteria(UtxoAmountCriteria? value) => _selectedAmountCriteria = value;
  void setCustomAmountCriteriaText(String? value) => _customAmountCriteriaText = value;
  void setIsCustomAmountLessThan(bool value) => _isCustomAmountLessThan = value;
  void setDidConfirmAmountCriteria(bool value) => _didConfirmAmountCriteria = value;
  void setDidConfirmTagCriteria(bool value) => _didConfirmTagCriteria = value;
  void setSelectedTagName(String? value) => _selectedTagName = value;
  void setSelectedReceiveAddress(String? value) => _selectedReceiveAddress = value;
  void setCustomReceiveAddressText(String? value) => _customReceiveAddressText = value;
  void setIsCustomReceiveAddressValidFormat(bool value) => _isCustomReceiveAddressValidFormat = value;
  void setIsCustomReceiveAddressOwnedByAnyWallet(bool value) => _isCustomReceiveAddressOwnedByAnyWallet = value;
  void setEditedSelectedUtxoIds(Set<String>? value) => _editedSelectedUtxoIds = value;
  void setEstimatedMergeFeeSats(int? value) => _estimatedMergeFeeSats = value;
  void setIsEstimatedMergeFeeLoading(bool value) => _isEstimatedMergeFeeLoading = value;
  void setExcludeDustUtxos(bool value) => _excludeDustUtxos = value;
  void setNeedsManualFeeRateInput(bool value) => _needsManualFeeRateInput = value;
  void setAppliedMergeFeeRate(double? value) => _appliedMergeFeeRate = value;
  void setDisplayedHeaderStep(UtxoMergeStep? value) => _displayedHeaderStep = value;
  void setPendingHeaderStep(UtxoMergeStep? value) => _pendingHeaderStep = value;
  void setLastObservedHeaderStep(UtxoMergeStep? value) => _lastObservedHeaderStep = value;
  void setIsHeaderFadingOut(bool value) => _isHeaderFadingOut = value;
  void setHeaderAnimationNonce(int value) => _headerAnimationNonce = value;
  void setDisplayedOptionPickerStep(UtxoMergeStep? value) => _displayedOptionPickerStep = value;
  void setPendingOptionPickerStep(UtxoMergeStep? value) => _pendingOptionPickerStep = value;
  void setLastObservedOptionPickerStep(UtxoMergeStep? value) => _lastObservedOptionPickerStep = value;
  void setOptionPickerAnimationNonce(int value) => _optionPickerAnimationNonce = value;
  void replaceVisibleOptionPickerSteps(Iterable<UtxoMergeStep> steps) {
    _visibleOptionPickerSteps
      ..clear()
      ..addAll(steps);
  }

  void setPreparedMergeTransactionBuildResult(TransactionBuildResult? value) =>
      _preparedMergeTransactionBuildResult = value;
  void setMergeTransactionSummaryState(MergeTransactionSummaryState value) => _mergeTransactionSummaryState = value;
  void setMergeTransactionPreparationNonce(int value) => _mergeTransactionPreparationNonce = value;
  void setReceiveAddressSummaryAnimationNonce(int value) => _receiveAddressSummaryAnimationNonce = value;
  void setDustThreshold(int value) => _dustThreshold = value;
  void setUnexpectedErrorMessage(String? value) => _unexpectedErrorMessage = value;

  void setEstimatedFeeText(String text) {
    if (_estimatedFeeText == text) return;
    _estimatedFeeText = text;
    notifyListeners();
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

  bool get canPrepareMergeTransaction {
    final currentFeeRateText = feeRateController.text.trim();
    return _currentStep == UtxoMergeStep.selectReceiveAddress &&
        _selectedReceiveAddress != null &&
        _selectedReceiveAddress!.isNotEmpty &&
        selectedUtxosForCurrentCriteria.length >= 2 &&
        !(_needsManualFeeRateInput && currentFeeRateText.isEmpty);
  }

  String? get mergeTransactionPreparationKey {
    if (!canPrepareMergeTransaction) return null;

    final selectedUtxoIds = selectedUtxosForCurrentCriteria.map((utxo) => utxo.utxoId).toList()..sort();
    return [
      currentMergeCriteria.name,
      currentAmountCriteria.name,
      _selectedReceiveAddress,
      feeRateController.text.trim().isEmpty ? 'auto' : feeRateController.text.trim(),
      _excludeDustUtxos,
      selectedUtxoIds.join(','),
    ].join('|');
  }

  int get selectedUtxosTotalAmountSats {
    return selectedUtxosForCurrentCriteria.fold<int>(0, (sum, utxo) => sum + utxo.amount);
  }

  int get selectedUtxoCount => selectedUtxosForCurrentCriteria.length;

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

  @override
  void dispose() {
    feeRateController.dispose();
    feeRateFocusNode.dispose();
    super.dispose();
  }
}
