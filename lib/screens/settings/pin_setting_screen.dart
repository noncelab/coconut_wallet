import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/constants/lottie_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/services/security/pin_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/dialogs/animated_dialog.dart';
import 'package:coconut_wallet/widgets/common/overlays/coconut_loading_overlay.dart';
import 'package:coconut_wallet/widgets/features/auth/pin/pin_input_pad.dart';
import 'package:coconut_wallet/widgets/features/auth/pin/pin_length_toggle_button.dart';
import 'package:provider/provider.dart';

class PinSettingScreen extends StatefulWidget {
  final bool useBiometrics;
  final bool popParentOnComplete;
  const PinSettingScreen({super.key, this.useBiometrics = false, this.popParentOnComplete = true});

  @override
  State<PinSettingScreen> createState() => _PinSettingScreenState();
}

class _PinSettingScreenState extends State<PinSettingScreen> {
  int step = 0;
  late String pin;
  late String pinConfirm;
  late String errorMessage;
  late int _pinLength;
  late List<String> _shuffledPinNumbers;
  late AuthProvider _authProvider;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    pin = '';
    pinConfirm = '';
    errorMessage = '';
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _pinLength = _authProvider.pinLength == 0 ? 4 : _authProvider.pinLength;
    _shuffledPinNumbers = _authProvider.getShuffledNumberPad(isSettings: true);
  }

  @override
  void dispose() {
    pin = '';
    pinConfirm = '';
    super.dispose();
  }

  void _shufflePinNumbers() {
    setState(() {
      _shuffledPinNumbers = _authProvider.getShuffledNumberPad(isSettings: true);
    });
  }

  Future<void> _showPinSetSuccessLottie() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: context.coconutColors.dimOverlay.withValues(alpha: 0.54),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation) {
        return AnimatedDialog(
          context: buildContext,
          lottieAddress: AuthLottiePath.pinLockedSuccess,
          duration: 400,
          onAnimationCompleted: () {
            if (buildContext.mounted) {
              Navigator.of(buildContext).pop();
            }
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ).drive(Tween<Offset>(begin: const Offset(0, 1), end: const Offset(0, 0))),
          child: child,
        );
      },
    );
  }

  void _setLoading(bool value) {
    if (!mounted || _isLoading == value) return;
    setState(() => _isLoading = value);
  }

  void returnToBackSequence(String message, {bool isError = false, bool firstSequence = false}) {
    setState(() {
      errorMessage = message;
      pinConfirm = '';
      _shufflePinNumbers();
      if (firstSequence) {
        step = 0;
        pin = '';
      }
    });
    if (isError) {
      vibrateMedium();
      return;
    }

    vibrateLightDouble();
  }

  void _onKeyTap(String value) async {
    if (_isLoading) return;
    setState(() {
      errorMessage = '';
    });

    if (step == 0) {
      if (value == '<') {
        if (pin.isNotEmpty) {
          setState(() => pin = pin.substring(0, pin.length - 1));
        }
      } else if (pin.length < _pinLength) {
        setState(() => pin += value);
        vibrateExtraLight();
      }

      setState(() {
        if (pin.length == _pinLength) {
          step = 1;
          errorMessage = '';
          _shufflePinNumbers();
        }
      });
    } else if (step == 1) {
      if (value == '<') {
        if (pinConfirm.isNotEmpty) {
          setState(() => pinConfirm = pinConfirm.substring(0, pinConfirm.length - 1));
        }
      } else if (pinConfirm.length < pin.length) {
        setState(() => pinConfirm += value);
        vibrateExtraLight();
      }

      if (pinConfirm.length == pin.length) {
        if (pinConfirm != pin) {
          returnToBackSequence(t.errors.pin_setting_error.incorrect, isError: true, firstSequence: true);
          return;
        }

        _setLoading(true);
        try {
          await _authProvider.savePin(pin);
          if (!mounted) return;
          pin = '';
          pinConfirm = '';

          if (widget.useBiometrics && _authProvider.canCheckBiometrics) {
            await _authProvider.authenticateWithBiometrics(isSave: true);
            await _authProvider.checkDeviceBiometrics();
          }

          if (!mounted) return;
          vibrateLight();
          _setLoading(false);
          await _showPinSetSuccessLottie();

          if (mounted) {
            final navigator = Navigator.of(context);
            navigator.pop();
            if (widget.popParentOnComplete) {
              navigator.pop();
            }
          }
        } catch (e) {
          if (!mounted) return;
          _setLoading(false);
          final message = switch (e) {
            PinAuthException(code: PinAuthError.alreadyInUse) => t.errors.pin_setting_error.already_in_use,
            PinAuthException(code: PinAuthError.unauthorized) => t.errors.pin_setting_error.authentication_required,
            PinAuthException(code: PinAuthError.stateUncertain) => t.errors.pin_setting_error.state_uncertain,
            _ => t.errors.pin_setting_error.save_failed,
          };
          returnToBackSequence(message, isError: true, firstSequence: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = step == 0 ? t.pin_setting_screen.new_password : t.pin_setting_screen.enter_again;

    Widget? centerWidget;
    if (step == 0) {
      centerWidget = PinLengthToggleButton(
        currentPinLength: _pinLength,
        onToggle: () {
          setState(() {
            _pinLength = _pinLength == 4 ? 6 : 4;
            pin = '';
          });
        },
      );
    }

    return Stack(
      children: [
        Scaffold(
          body: PinInputPad(
            title: title,
            pin: step == 0 ? pin : pinConfirm,
            errorMessage: errorMessage,
            onKeyTap: _onKeyTap,
            pinShuffleNumbers: _shuffledPinNumbers,
            onClosePressed: () => Navigator.pop(context),
            onBackPressed: () {
              setState(() {
                step = 0;
                pin = '';
                pinConfirm = '';
                errorMessage = '';
              });
            },
            step: step,
            pinLength: _pinLength,
            appBarVisible: true,
            initOptionVisible: false,
            centerWidget: centerWidget,
          ),
        ),
        if (_isLoading) const Positioned.fill(child: CoconutLoadingOverlay(applyFullScreen: true)),
      ],
    );
  }
}
