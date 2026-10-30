import 'dart:async';

import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/services/security/pin_auth_service.dart';
import 'package:flutter/foundation.dart';

class PinCheckViewModel extends ChangeNotifier {
  final AuthProvider _authProvider;
  final DateTime Function() _now;
  bool _disposed = false;
  bool _isLoading = false;
  bool _authUnavailable = false;
  DateTime? _unlockAvailableAt;
  Timer? _cooldownTimer;
  String pin = '';
  String errorMessage = '';
  late List<String> shuffledPinNumbers;

  PinCheckViewModel(this._authProvider, {DateTime Function()? now}) : _now = now ?? DateTime.now {
    shuffledPinNumbers = _authProvider.getShuffledNumberPad();
  }

  bool get isLoading => _isLoading;
  int get pinLength => _authProvider.pinLength;
  int get _remainingSeconds => ((_unlockAvailableAt?.difference(_now()).inMilliseconds ?? 0) / 1000).ceil();
  bool get canEnterPin => !_disposed && !_isLoading && !_authUnavailable && _remainingSeconds <= 0;
  bool get isPinComplete => pin.length == pinLength;

  void initialize() {
    unawaited(refreshStatus());
    _cooldownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || _isLoading || _unlockAvailableAt == null) return;
      if (_remainingSeconds <= 0) {
        _unlockAvailableAt = null;
        unawaited(refreshStatus());
      } else {
        errorMessage = t.pin_check_screen.retry_after(time: _formatRemainingTime(_remainingSeconds));
        notifyListeners();
      }
    });
  }

  void onResumed() {
    if (_disposed) return;
    unawaited(_authProvider.checkDeviceBiometrics());
    if (!_isLoading) unawaited(refreshStatus());
  }

  void _update(VoidCallback update) {
    if (_disposed) return;
    update();
    notifyListeners();
  }

  Future<void> refreshStatus() async {
    if (_disposed || _isLoading) return;
    _setLoading(true);
    try {
      final status = await _authProvider.getPinAuthStatus();
      if (_disposed) return;
      _authUnavailable = false;
      _applyStatus(status);
    } catch (_) {
      if (_disposed) return;
      _update(() {
        _authUnavailable = true;
        errorMessage = t.pin_check_screen.authentication_unavailable;
      });
    } finally {
      _setLoading(false);
    }
  }

  void _applyStatus(PinAuthStatus status) {
    _unlockAvailableAt = status.isBlocked ? status.unlockAvailableAt ?? _now().add(status.remaining) : null;
    _update(
      () =>
          errorMessage =
              status.isBlocked
                  ? t.pin_check_screen.retry_after(time: _formatRemainingTime(status.remainingSeconds))
                  : status.failures > 0
                  ? t.errors.pin_check_error.trial_count(count: status.remainingAttempts)
                  : '',
    );
  }

  String _formatRemainingTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return [
      if (hours > 0) '$hours${t.pin_check_screen.time_hour}',
      if (minutes > 0) '$minutes${t.pin_check_screen.time_minute}',
      if (seconds > 0 || totalSeconds == 0) '$seconds${t.pin_check_screen.time_second}',
    ].join(' ');
  }

  void _setLoading(bool value) {
    if (_disposed || _isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void enterKey(String value) {
    if (!canEnterPin) return;
    if (value == '<') {
      if (pin.isNotEmpty) pin = pin.substring(0, pin.length - 1);
    } else if (RegExp(r'^[0-9]$').hasMatch(value) && pin.length < pinLength) {
      pin += value;
    }
    notifyListeners();
  }

  Future<bool?> verifyPin() async {
    if (!canEnterPin || !isPinComplete) return null;
    _setLoading(true);
    try {
      final result = await _authProvider.verifyPinResult(pin);
      if (_disposed) return null;
      pin = '';
      if (result.outcome == PinVerificationOutcome.success) return true;
      _applyStatus(result.status);
      if (result.outcome == PinVerificationOutcome.unavailable) {
        _authUnavailable = true;
        errorMessage = t.pin_check_screen.authentication_unavailable;
      } else if (result.outcome == PinVerificationOutcome.busy) {
        errorMessage = t.pin_check_screen.authentication_busy;
      } else if (!result.status.isBlocked) {
        errorMessage = t.errors.pin_check_error.trial_count(count: result.status.remainingAttempts);
      }
      shuffledPinNumbers = _authProvider.getShuffledNumberPad();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyBiometric() async {
    if (_disposed || _isLoading) return false;
    _setLoading(true);
    try {
      final success = await _authProvider.authenticateWithBiometrics();
      return !_disposed && success;
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cooldownTimer?.cancel();
    pin = '';
    super.dispose();
  }
}
