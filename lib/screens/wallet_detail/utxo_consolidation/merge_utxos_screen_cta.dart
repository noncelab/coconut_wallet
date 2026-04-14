part of 'merge_utxos_screen.dart';

extension _MergeUtxosScreenCtaExtension on _MergeUtxosScreenState {
  _MergeCtaAssistData? get _mergeCtaAssistData {
    if (_viewModel.mergeTransactionSummaryState != MergeTransactionSummaryState.ready) return null;
    final inputCount = _viewModel.selectedUtxoCount;
    if (inputCount < 2) return null;

    final wallet = context.read<WalletProvider>().getWalletById(widget.id);
    final inputSize = estimateVSizePerInput(
      isMultisig: wallet.walletType != WalletType.singleSignature,
      requiredSignatureCount: wallet.multisigConfig?.requiredSignature,
      totalSignerCount: wallet.multisigConfig?.totalSigner,
    );
    const futureFeeRate = 15.0;
    const minRatioForRecommend = 1.5;
    const minMeaningfulSaving = 1000;
    const discouragedCurrentFeeRate = 5.0;

    final currentFee = _viewModel.estimatedMergeFeeSats ?? 0;
    if (currentFee <= 0) return null;
    final totalInputAmount = _viewModel.selectedUtxosTotalAmountSats;
    if (totalInputAmount <= 0) return null;
    final feeRatioPercent = ((currentFee / totalInputAmount) * 100);

    if (feeRatioPercent >= 10) {
      return _MergeCtaAssistData(
        message: t.merge_utxos_screen.merge_cta_high_fee_ratio(ratio: feeRatioPercent.toStringAsFixed(1)),
        color: CoconutColors.warningText,
      );
    }

    final futureSaving = (inputCount - 1) * inputSize * futureFeeRate;
    final netBenefit = futureSaving - currentFee;
    final ratio = futureSaving / currentFee;

    if (ratio < 1.0) {
      final feeRate = _viewModel.appliedMergeFeeRate ?? 0;
      if (feeRate >= discouragedCurrentFeeRate) {
        return _MergeCtaAssistData(
          message: t.merge_utxos_screen.merge_cta_discouraged_high_fee,
          color: CoconutColors.warningText,
        );
      }
      return _MergeCtaAssistData(
        message: t.merge_utxos_screen.merge_cta_discouraged_costly,
        color: CoconutColors.warningText,
      );
    }

    if (ratio < minRatioForRecommend || netBenefit < minMeaningfulSaving) {
      if (inputCount <= 3) {
        return _MergeCtaAssistData(
          message: t.merge_utxos_screen.merge_cta_neutral_efficient,
          color: CoconutColors.yellow,
        );
      }
      return _MergeCtaAssistData(
        message: t.merge_utxos_screen.merge_cta_neutral_low_saving,
        color: CoconutColors.yellow,
      );
    }

    return _MergeCtaAssistData(
      message: t.merge_utxos_screen.future_fee_saving(amount: netBenefit.toInt()),
      color: CoconutColors.gray300,
    );
  }
}
