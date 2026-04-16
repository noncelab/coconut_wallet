part of 'merge_utxos_screen.dart';

extension _MergeUtxosScreenCtaExtension on _MergeUtxosScreenState {
  _MergeCtaAssistData? get _mergeCtaAssistData {
    if (_viewModel.mergeTransactionSummaryState != MergeTransactionSummaryState.ready) return null;
    if (_viewModel.appliedMergeFeeRate == null) return null;
    if (_viewModel.estimatedMergeFeeSats == null) return null;

    final inputCount = _viewModel.selectedUtxoCount;
    if (inputCount < 2) return null;

    final wallet = context.read<WalletProvider>().getWalletById(widget.id);
    final inputSize = estimateVSizePerInput(
      isMultisig: wallet.walletType != WalletType.singleSignature,
      requiredSignatureCount: wallet.multisigConfig?.requiredSignature,
      totalSignerCount: wallet.multisigConfig?.totalSigner,
    );

    const expectedfutureFeeRate = 15.0;
    final futureSavingFee = (inputCount - 1) * inputSize * expectedfutureFeeRate;
    final currentFeeRate = _viewModel.appliedMergeFeeRate!;
    final currentFee = _viewModel.estimatedMergeFeeSats!;
    const discouragedFeeRateThreshold = 5.0;
    Color textColor = CoconutColors.hotPink;
    final ratio = futureSavingFee / currentFee;
    if (ratio < 1.0) {
      if (currentFeeRate >= discouragedFeeRateThreshold) {
        // 현재 수수료가 높아 합치기에는 적절하지 않아요
        return _MergeCtaAssistData(message: t.merge_utxos_screen.merge_cta_discouraged_high_fee, color: textColor);
      }
      // 합치는 비용이 절약되는 수수료보다 더 커요
      return _MergeCtaAssistData(message: t.merge_utxos_screen.merge_cta_discouraged_costly, color: textColor);
    }

    textColor = CoconutColors.yellow;
    final savingAmount = futureSavingFee - currentFee;
    if (ratio < 1.5) {
      final feeToInputRatioPercent =
          ((currentFee / _viewModel.selectedUtxosTotalAmountSats * 100) * 100).roundToDouble() / 100;
      if (feeToInputRatioPercent >= 10) {
        // 수수료 비중이 높아요.
        return _MergeCtaAssistData(
          message: t.merge_utxos_screen.merge_cta_high_fee_ratio(
            ratio: feeToInputRatioPercent % 1 == 0 ? feeToInputRatioPercent.toInt() : feeToInputRatioPercent,
          ),
          color: textColor,
        );
      }

      if (savingAmount < 1000) {
        // 합쳐도 수수료 절감 효과가 크지 않아요
        return _MergeCtaAssistData(message: t.merge_utxos_screen.merge_cta_neutral_low_saving, color: textColor);
      }

      if (inputCount <= 3) {
        // 합치지 않아도 충분히 효율적이에요
        return _MergeCtaAssistData(message: t.merge_utxos_screen.merge_cta_efficient_without_merge, color: textColor);
      }
    }

    textColor = CoconutColors.white;
    final savingAmountText = savingAmount.round().toThousandsSeparatedString();

    return _MergeCtaAssistData(
      message: t.merge_utxos_screen.future_fee_saving(amount: savingAmountText),
      color: textColor,
    );
  }
}
