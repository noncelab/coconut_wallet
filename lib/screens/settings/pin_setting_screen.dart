import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/utils/hash_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/animated_dialog.dart';
import 'package:coconut_wallet/widgets/pin/pin_input_pad.dart';
import 'package:coconut_wallet/widgets/pin/pin_length_toggle_button.dart';
import 'package:provider/provider.dart';

class PinSettingScreen extends StatefulWidget {
  final bool useBiometrics;
  const PinSettingScreen({super.key, this.useBiometrics = false});

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

  void _shufflePinNumbers() {
    setState(() {
      _shuffledPinNumbers = _authProvider.getShuffledNumberPad(isSettings: true);
    });
  }

  Future<void> _showPinSetSuccessLottie() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation) {
        Future.delayed(const Duration(milliseconds: 1300), () {
          if (buildContext.mounted) {
            Navigator.of(buildContext).pop();
          }
        });

        return AnimatedDialog(
          context: buildContext,
          lottieAddress: 'assets/lottie/pin-locked-success.json',
          duration: 400,
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

  Future<bool> _comparePin(String input) async {
    bool isSamePin = await _authProvider.verifyPin(input);
    return isSamePin;
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

      if (_authProvider.isSetPin && pin.length == _pinLength) {
        try {
          bool isSameAsOldPin = await _comparePin(pin);

          if (isSameAsOldPin) {
            returnToBackSequence(t.errors.pin_setting_error.already_in_use, firstSequence: true);
            return;
          }
        } catch (error) {
          returnToBackSequence(t.errors.pin_setting_error.process_failed, isError: true);
          return;
        }
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

        try {
          var hashedPin = generateHashString(pin);
          Logger.log('hashedPin: $hashedPin');
          await _authProvider.savePinSet(hashedPin, pin.length);

          if (widget.useBiometrics && _authProvider.canCheckBiometrics) {
            await _authProvider.authenticateWithBiometrics(isSave: true);
            await _authProvider.checkDeviceBiometrics();
          }

          vibrateLight();
          await _showPinSetSuccessLottie();

          if (mounted) {
            Navigator.pop(context); // Close success dialog
            Navigator.pop(context); // Close PIN setting screen
          }
        } catch (e) {
          returnToBackSequence(t.errors.pin_setting_error.save_failed, isError: true, firstSequence: true);
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

    return Scaffold(
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
    );
  }
}
