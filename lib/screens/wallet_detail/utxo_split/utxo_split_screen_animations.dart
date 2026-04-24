part of 'utxo_split_screen.dart';

extension _UtxoSplitScreenAnimations on _UtxoSplitScreenState {
  void _scheduleHeaderAnimation(String nextTitle, UtxoSplitMethod? nextMethod) {
    final nextStep = (title: nextTitle, method: nextMethod);
    if (!_headerTransitionController.markObserved(nextStep)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncHeaderAnimation(nextStep);
    });
  }

  void _syncHeaderAnimation(({String title, UtxoSplitMethod? method}) nextStep) {
    _headerTransitionController.pendingStep = nextStep;
    final displayed = _headerTransitionController.displayedStep;

    if (displayed == null) {
      _setScreenState(() {
        _headerTransitionController.displayedStep = nextStep;
        _isHeaderFadingOut = false;
        _isMethodBodyVisible = true;
      });
      return;
    }

    if (displayed == nextStep && !_isHeaderFadingOut) return;
    if (_isHeaderFadingOut) return;

    final token = _headerTransitionController.bumpNonce();

    final currentMethod = displayed.method;
    final isMethodChanging = currentMethod != null && nextStep.method != null && currentMethod != nextStep.method;
    final isFirstTimeMethod = currentMethod == null && nextStep.method != null;

    _setScreenState(() {
      _isHeaderFadingOut = true;
      if (isMethodChanging) {
        _isMethodBodyVisible = false;
      } else if (isFirstTimeMethod) {
        _isMethodBodyVisible = true;
        _headerTransitionController.displayedStep = nextStep;
      }
    });

    Future.delayed(_UtxoSplitScreenState._headerAnimationDuration, () {
      if (!mounted || token != _headerTransitionController.nonce) return;

      _setScreenState(() {
        _headerTransitionController.displayedStep = _headerTransitionController.pendingStep;
        if (!isFirstTimeMethod) {
          _headerTransitionController.displayedStep = _headerTransitionController.pendingStep;
        }
        _isHeaderFadingOut = false;
      });

      if (isMethodChanging) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || token != _headerTransitionController.nonce) return;
          _setScreenState(() {
            _isMethodBodyVisible = true;
          });
        });
      }
    });
  }

  void _scheduleOptionPickerAnimation(UtxoSplitStep step, UtxoSplitViewModel viewModel) {
    if (!_optionPickerTransitionController.markObserved(step)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncOptionPickerAnimation(step, viewModel);
    });
  }

  void _syncOptionPickerAnimation(UtxoSplitStep step, UtxoSplitViewModel viewModel) {
    _optionPickerTransitionController.pendingStep = step;
    final nextVisibleSteps = _visiblePickerStepsFor(step);

    _autoOpenUtxoPickerScheduler.cancel();
    _autoOpenMethodPickerScheduler.cancel();

    if (_optionPickerTransitionController.displayedStep == null) {
      _setScreenState(() {
        _optionPickerTransitionController.displayedStep = step;
        _visibleOptionPickerSteps.clear();
        _visibleOptionPickerSteps.addAll(nextVisibleSteps);
      });
      if (step == UtxoSplitStep.selectUtxo) {
        _scheduleAutoOpenUtxoSelectionBottomSheet(viewModel);
      }
      return;
    }

    if (_optionPickerTransitionController.displayedStep == step &&
        listEquals(_visibleOptionPickerSteps, nextVisibleSteps)) {
      return;
    }

    _optionPickerTransitionController.bumpNonce();
    _setScreenState(() {
      _optionPickerTransitionController.displayedStep = _optionPickerTransitionController.pendingStep;
      _visibleOptionPickerSteps.clear();
      _visibleOptionPickerSteps.addAll(nextVisibleSteps);
    });
    if (step == UtxoSplitStep.selectSplitMethod) {
      _scheduleAutoOpenMethodBottomSheet(viewModel);
    }
  }
}
