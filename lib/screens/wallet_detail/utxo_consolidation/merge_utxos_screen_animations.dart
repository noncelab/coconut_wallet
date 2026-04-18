part of 'merge_utxos_screen.dart';

extension _MergeUtxosScreenAnimationsExtension on _MergeUtxosScreenState {
  void _scheduleHeaderAnimation(UtxoMergeStep step) {
    if (!_viewModel.isAnimatedHeaderStep(step) || _lastObservedHeaderStep == step) return;
    _lastObservedHeaderStep = step;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _playHeaderAnimation(step);
    });
  }

  void _scheduleOptionPickerAnimation(UtxoMergeStep step) {
    if (!_viewModel.isAnimatedHeaderStep(step) || _lastObservedOptionPickerStep == step) return;
    _lastObservedOptionPickerStep = step;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _playOptionPickerAnimation(step);
    });
  }

  void _refreshAnimationsForCurrentStep() {
    final step = _viewModel.currentStep;
    _lastObservedHeaderStep = null;
    _lastObservedOptionPickerStep = null;
    _scheduleHeaderAnimation(step);
    _scheduleOptionPickerAnimation(step);
  }

  /// 현재 헤더를 페이드아웃 후 새 문구로 스왑하는 크로스페이드 전환
  void _playHeaderAnimation(UtxoMergeStep step) {
    if (!_viewModel.isAnimatedHeaderStep(step)) return;
    if (_displayedHeaderStep == UtxoMergeStep.selectReceiveAddress && step != UtxoMergeStep.selectReceiveAddress) {
      _resetReceiveAddressSummary();
    }

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

  /// selectReceiveAddress 스텝에서 벗어날 때 진행 상태와 Lottie를 초기화한다.
  void _resetReceiveAddressSummary() {
    _viewModel.resetReceiveAddressSummaryForStepTransition();
    _receiveAddressSummaryLottieController.stop();
    _receiveAddressSummaryLottieController.reset();
  }

  void _playOptionPickerAnimation(UtxoMergeStep step) {
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
