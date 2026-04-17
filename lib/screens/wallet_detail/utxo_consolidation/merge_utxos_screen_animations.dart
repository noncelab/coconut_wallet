part of 'merge_utxos_screen.dart';

extension _MergeUtxosScreenAnimationsExtension on _MergeUtxosScreenState {
  void _scheduleHeaderAnimation(UtxoMergeStep step) {
    if (!_viewModel.isAnimatedHeaderStep(step) || _lastObservedHeaderStep == step) return;
    _lastObservedHeaderStep = step;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncHeaderAnimation(step);
    });
  }

  void _scheduleOptionPickerAnimation(UtxoMergeStep step) {
    if (!_viewModel.isAnimatedHeaderStep(step) || _lastObservedOptionPickerStep == step) return;
    _lastObservedOptionPickerStep = step;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncOptionPickerAnimation(step);
    });
  }

  void _refreshAnimationsForCurrentStep() {
    final step = _viewModel.currentStep;
    _lastObservedHeaderStep = null;
    _lastObservedOptionPickerStep = null;
    _scheduleHeaderAnimation(step);
    _scheduleOptionPickerAnimation(step);
  }

  void _syncHeaderAnimation(UtxoMergeStep step) {
    if (!_viewModel.isAnimatedHeaderStep(step)) return;
    _handleReceiveAddressSummaryAnimation(step);

    _pendingHeaderStep = step;

    if (_displayedHeaderStep == null) {
      _setScreenState(() {
        _displayedHeaderStep = step;
        _isHeaderFadingOut = false;
      });
      return;
    }

    if (_displayedHeaderStep == step && !_isHeaderFadingOut) {
      return;
    }

    if (_isHeaderFadingOut) {
      return;
    }

    final token = _headerAnimationNonce + 1;
    _headerAnimationNonce = token;
    _setScreenState(() {
      _isHeaderFadingOut = true;
    });

    Future.delayed(_MergeUtxosScreenState._headerAnimationDuration, () {
      if (!mounted || token != _headerAnimationNonce) return;

      _setScreenState(() {
        _displayedHeaderStep = _pendingHeaderStep;
        _isHeaderFadingOut = false;
      });
    });
  }

  void _handleReceiveAddressSummaryAnimation(UtxoMergeStep step) {
    if (step != UtxoMergeStep.selectReceiveAddress) {
      _viewModel.setMergeTransactionPreparationNonce(_viewModel.mergeTransactionPreparationNonce + 1);
      _viewModel.setPreparedMergeTransactionBuildResult(null);
      _viewModel.setPreparedMergeTransactionKeyState(null);
      _viewModel.setMergeTransactionSummaryState(MergeState.idle);
      _viewModel.setEstimatedMergeFeeSats(null);
      _viewModel.setIsEstimatedMergeFeeLoading(false);
      _viewModel.setAppliedMergeFeeRate(null);
      _receiveAddressSummaryLottieController.stop();
      _receiveAddressSummaryLottieController.reset();
      return;
    }
  }

  void _syncOptionPickerAnimation(UtxoMergeStep step) {
    if (!_viewModel.isAnimatedHeaderStep(step)) return;

    _pendingOptionPickerStep = step;
    final nextVisibleSteps = _viewModel.visibleOptionPickerStepsFor(step);

    if (_displayedOptionPickerStep == null) {
      _setScreenState(() {
        _displayedOptionPickerStep = step;
        _visibleOptionPickerSteps
          ..clear()
          ..addAll(nextVisibleSteps);
      });
      return;
    }

    if (_displayedOptionPickerStep == step && listEquals(_visibleOptionPickerSteps, nextVisibleSteps)) {
      return;
    }

    _optionPickerAnimationNonce = _optionPickerAnimationNonce + 1;
    _setScreenState(() {
      _displayedOptionPickerStep = _pendingOptionPickerStep;
      _visibleOptionPickerSteps
        ..clear()
        ..addAll(nextVisibleSteps);
    });
  }
}
