part of 'merge_utxos_screen.dart';

extension _MergeUtxosScreenAnimationsExtension on _MergeUtxosScreenState {
  void _scheduleHeaderAnimation(UtxoMergeStep step) {
    if (!_isAnimatedHeaderStep(step) || _viewModel.lastObservedHeaderStep == step) return;
    _viewModel.setLastObservedHeaderStep(step);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncHeaderAnimation(step);
    });
  }

  void _scheduleOptionPickerAnimation(UtxoMergeStep step) {
    if (!_isAnimatedHeaderStep(step) || _viewModel.lastObservedOptionPickerStep == step) return;
    _viewModel.setLastObservedOptionPickerStep(step);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncOptionPickerAnimation(step);
    });
  }

  void _refreshAnimationsForCurrentStep() {
    final step = _viewModel.currentStep;
    _viewModel.setLastObservedHeaderStep(null);
    _viewModel.setLastObservedOptionPickerStep(null);
    _scheduleHeaderAnimation(step);
    _scheduleOptionPickerAnimation(step);
  }

  void _syncHeaderAnimation(UtxoMergeStep step) {
    if (!_isAnimatedHeaderStep(step)) return;
    _handleReceiveAddressSummaryAnimation(step);

    _viewModel.setPendingHeaderStep(step);

    if (_viewModel.displayedHeaderStep == null) {
      _setScreenState(() {
        _viewModel.setDisplayedHeaderStep(step);
        _viewModel.setIsHeaderFadingOut(false);
      });
      return;
    }

    if (_viewModel.displayedHeaderStep == step && !_viewModel.isHeaderFadingOut) {
      return;
    }

    if (_viewModel.isHeaderFadingOut) {
      return;
    }

    final token = _viewModel.headerAnimationNonce + 1;
    _viewModel.setHeaderAnimationNonce(token);
    _setScreenState(() {
      _viewModel.setIsHeaderFadingOut(true);
    });

    Future.delayed(_MergeUtxosScreenState._headerAnimationDuration, () {
      if (!mounted || token != _viewModel.headerAnimationNonce) return;

      _setScreenState(() {
        _viewModel.setDisplayedHeaderStep(_viewModel.pendingHeaderStep);
        _viewModel.setIsHeaderFadingOut(false);
      });
    });
  }

  void _handleReceiveAddressSummaryAnimation(UtxoMergeStep step) {
    if (step != UtxoMergeStep.selectReceiveAddress) {
      _viewModel.setMergeTransactionPreparationNonce(_viewModel.mergeTransactionPreparationNonce + 1);
      _viewModel.setPreparedMergeTransactionBuildResult(null);
      _preparedMergeTransactionKey = null;
      _viewModel.setMergeTransactionSummaryState(MergeTransactionSummaryState.idle);
      _viewModel.setEstimatedMergeFeeSats(null);
      _viewModel.setIsEstimatedMergeFeeLoading(false);
      _viewModel.setAppliedMergeFeeRate(null);
      _receiveAddressSummaryLottieController.stop();
      _receiveAddressSummaryLottieController.reset();
      return;
    }
  }

  void _syncOptionPickerAnimation(UtxoMergeStep step) {
    if (!_isAnimatedHeaderStep(step)) return;

    _viewModel.setPendingOptionPickerStep(step);
    final nextVisibleSteps = _visibleOptionPickerStepsFor(step);

    if (_viewModel.displayedOptionPickerStep == null) {
      _setScreenState(() {
        _viewModel.setDisplayedOptionPickerStep(step);
        _viewModel.replaceVisibleOptionPickerSteps(nextVisibleSteps);
      });
      return;
    }

    if (_viewModel.displayedOptionPickerStep == step &&
        listEquals(_viewModel.visibleOptionPickerSteps, nextVisibleSteps)) {
      return;
    }

    _viewModel.setOptionPickerAnimationNonce(_viewModel.optionPickerAnimationNonce + 1);
    _setScreenState(() {
      _viewModel.setDisplayedOptionPickerStep(_viewModel.pendingOptionPickerStep);
      _viewModel.replaceVisibleOptionPickerSteps(nextVisibleSteps);
    });
  }
}
