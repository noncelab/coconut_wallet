import 'dart:async';
import 'package:coconut_wallet/services/security/pin_auth_service.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/widgets/common/overlays/coconut_loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/features/auth/pin/pin_input_pad.dart';
import 'package:provider/provider.dart';

class PinCheckScreen extends StatefulWidget {
  final bool appEntrance;
  final Function? onComplete;
  final bool allowBiometrics;
  const PinCheckScreen({super.key, this.appEntrance = false, this.onComplete, this.allowBiometrics = true});

  @override
  State<PinCheckScreen> createState() => _PinCheckScreenState();
}

class _PinCheckScreenState extends State<PinCheckScreen> with WidgetsBindingObserver {
  late String pin;
  late String errorMessage;
  DateTime? _unlockAvailableAt;
  bool _authUnavailable = false;
  Timer? _cooldownTimer;
  int get _remainingSeconds => ((_unlockAvailableAt?.difference(DateTime.now()).inMilliseconds ?? 0) / 1000).ceil();
  final GlobalKey<PinInputPadState> _pinInputScreenKey = GlobalKey<PinInputPadState>();
  late List<String> _shuffledPinNumbers;
  late AuthProvider _authProvider;
  bool _isPause = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    pin = '';
    errorMessage = '';
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _shuffledPinNumbers = _authProvider.getShuffledNumberPad();

    WidgetsBinding.instance.addObserver(this);
    _isLoading = true;
    unawaited(_refreshStatus());
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isLoading || _unlockAvailableAt == null) return;
      if (_remainingSeconds <= 0) {
        _unlockAvailableAt = null;
        unawaited(_refreshStatus());
      } else {
        setState(() => errorMessage = t.pin_check_screen.retry_after(time: _formatRemainingTime(_remainingSeconds)));
      }
    });
  }

  Future<void> _refreshStatus() async {
    _setLoading(true);
    try {
      final status = await _authProvider.getPinAuthStatus();
      if (!mounted) return;
      _authUnavailable = false;
      _applyStatus(status);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authUnavailable = true;
        errorMessage = t.pin_check_screen.authentication_unavailable;
      });
    } finally {
      _setLoading(false);
    }
  }

  void _applyStatus(PinAuthStatus status) {
    _unlockAvailableAt = status.isBlocked ? status.unlockAvailableAt ?? DateTime.now().add(status.remaining) : null;
    setState(
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

  void _shufflePinNumbers() {
    setState(() {
      _shuffledPinNumbers = _authProvider.getShuffledNumberPad();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (AppLifecycleState.paused == state) {
      _isPause = true;
    } else if (AppLifecycleState.resumed == state && _isPause) {
      _isPause = false;
      _authProvider.checkDeviceBiometrics();
      if (!_isLoading) unawaited(_refreshStatus());
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    pin = '';
    super.dispose();
  }

  void _verifyBiometric() async {
    _setLoading(true);
    _authProvider
        .authenticateWithBiometrics()
        .then((value) {
          if (!mounted) return;
          if (value) {
            if (!widget.appEntrance && mounted) {
              Navigator.pop(context, true);
            }
            widget.onComplete?.call();
          }
        })
        .whenComplete(() {
          _setLoading(false);
        });
  }

  void _verifyPin() async {
    if (_isLoading || _authUnavailable || _remainingSeconds > 0) return;
    _setLoading(true);
    var isClosing = false;
    try {
      final result = await _authProvider.verifyPinResult(pin);
      if (!mounted) return;
      pin = '';
      if (result.outcome == PinVerificationOutcome.success) {
        _setLoading(false);
        isClosing = true;
        if (!widget.appEntrance) Navigator.pop(context, true);
        widget.onComplete?.call();
        return;
      }
      _applyStatus(result.status);
      if (result.outcome == PinVerificationOutcome.unavailable) {
        _authUnavailable = true;
        errorMessage = t.pin_check_screen.authentication_unavailable;
      } else if (result.outcome == PinVerificationOutcome.busy) {
        errorMessage = t.pin_check_screen.authentication_busy;
      } else if (!result.status.isBlocked) {
        errorMessage = t.errors.pin_check_error.trial_count(count: result.status.remainingAttempts);
      }
      _shufflePinNumbers();
      vibrateLightDouble();
      setState(() {});
    } finally {
      if (mounted && !isClosing) _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    if (!mounted || _isLoading == value) return;
    setState(() => _isLoading = value);
  }

  void _onKeyTap(String value) {
    if (_isLoading) return;
    if (value == 'bio' && widget.allowBiometrics) {
      _verifyBiometric();
      return;
    }

    if (_authUnavailable || _remainingSeconds > 0) return;

    setState(() {
      if (value == '<') {
        if (pin.isNotEmpty) {
          pin = pin.substring(0, pin.length - 1);
        }
      } else if (pin.length < _authProvider.pinLength) {
        pin += value;
        vibrateExtraLight();
      }
    });

    if (pin.length == _authProvider.pinLength) {
      _verifyPin();
    }
  }

  void _showResetConfirmDialog() async {
    vibrateMedium();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.alert.forgot_password.title,
          description: t.alert.forgot_password.description,
          onTapRight: () async {
            await _authProvider.resetPassword(resetWallets: Provider.of<RealmManager>(context, listen: false).reset);
            if (!context.mounted) return;
            widget.onComplete?.call();
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
          onTapLeft: () {
            Navigator.of(context).pop();
          },
          rightButtonText: t.alert.forgot_password.btn_reset,
          rightButtonColor: context.coconutColors.danger,
          leftButtonText: t.cancel,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PinInputPad(
          key: _pinInputScreenKey,
          appBarVisible: !widget.appEntrance,
          title: widget.appEntrance ? '' : t.pin_check_screen.text,
          initOptionVisible: widget.appEntrance,
          pin: pin,
          errorMessage: errorMessage,
          onKeyTap: _onKeyTap,
          pinShuffleNumbers:
              widget.allowBiometrics
                  ? _shuffledPinNumbers
                  : _shuffledPinNumbers.map((value) => value == 'bio' ? '' : value).toList(),
          onClosePressed: () {
            Navigator.pop(context);
          },
          onReset:
              widget.appEntrance
                  ? () {
                    _showResetConfirmDialog();
                  }
                  : null,
          step: 0,
          pinLength: _authProvider.pinLength,
        ),
        if (_isLoading) const Positioned.fill(child: CoconutLoadingOverlay(applyFullScreen: true)),
      ],
    );
  }
}
