part of 'utxo_merge_screen.dart';

extension _UtxoMergeScreenAnimationsExtension on _UtxoMergeScreenState {
  void _scheduleHeaderAnimation(UtxoMergeStep step) {
    if (!_viewModel.isAnimatedHeaderStep(step) || !_headerTransitionController.markObserved(step)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _playHeaderAnimation(step);
    });
  }

  void _scheduleOptionPickerAnimation(UtxoMergeStep step) {
    if (!_viewModel.isAnimatedHeaderStep(step) || !_optionPickerTransitionController.markObserved(step)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _playOptionPickerAnimation(step);
    });
  }

  void _refreshAnimationsForCurrentStep() {
    final step = _viewModel.currentStep;
    _headerTransitionController.resetObserved();
    _optionPickerTransitionController.resetObserved();
    _scheduleHeaderAnimation(step);
    _scheduleOptionPickerAnimation(step);
  }

  /// 현재 헤더를 페이드아웃 후 새 문구로 스왑하는 크로스페이드 전환
  void _playHeaderAnimation(UtxoMergeStep step) {
    if (!_viewModel.isAnimatedHeaderStep(step)) return;
    if (_headerTransitionController.displayedStep == UtxoMergeStep.selectReceivingAddress &&
        step != UtxoMergeStep.selectReceivingAddress) {
      _resetReceiveAddressSummary();
    }

    _headerTransitionController.pendingStep = step;

    if (_headerTransitionController.displayedStep == null) {
      _setScreenState(() {
        _headerTransitionController.displayedStep = step;
        _isHeaderFadingOut = false;
      });
      return;
    }

    if (_headerTransitionController.displayedStep == step && !_isHeaderFadingOut) {
      return;
    }

    if (_isHeaderFadingOut) {
      return;
    }

    final token = _headerTransitionController.bumpNonce();
    _setScreenState(() {
      _isHeaderFadingOut = true;
    });

    Future.delayed(_UtxoMergeScreenState._headerAnimationDuration, () {
      if (!mounted || token != _headerTransitionController.nonce) return;

      _setScreenState(() {
        _headerTransitionController.displayedStep = _headerTransitionController.pendingStep;
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

    _optionPickerTransitionController.pendingStep = step;
    final nextVisibleSteps = _viewModel.visibleOptionPickerStepsFor(step);

    if (_optionPickerTransitionController.displayedStep == null) {
      _setScreenState(() {
        _optionPickerTransitionController.displayedStep = step;
        _visibleOptionPickerSteps
          ..clear()
          ..addAll(nextVisibleSteps);
      });
      return;
    }

    if (_optionPickerTransitionController.displayedStep == step &&
        listEquals(_visibleOptionPickerSteps, nextVisibleSteps)) {
      return;
    }

    _optionPickerTransitionController.bumpNonce();
    _setScreenState(() {
      _optionPickerTransitionController.displayedStep = _optionPickerTransitionController.pendingStep;
      _visibleOptionPickerSteps
        ..clear()
        ..addAll(nextVisibleSteps);
    });
  }
}
