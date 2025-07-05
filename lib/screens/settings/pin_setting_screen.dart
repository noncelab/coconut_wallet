import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/utils/hash_util.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/animated_dialog.dart';
import 'package:coconut_wallet/widgets/pin/pin_input_pad.dart';
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
  late bool _showNextButton;
  late List<String> _shuffledPinNumbers;
  late AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    pin = '';
    pinConfirm = '';
    errorMessage = '';
    _pinLength = 4;
    _showNextButton = false;
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _shuffledPinNumbers = _authProvider.getShuffledNumberPad(isSettings: true);
  }

  void _shufflePinNumbers() {
    setState(() {
      _shuffledPinNumbers = _authProvider.getShuffledNumberPad(isSettings: true);
    });
  }

  void _showPinSetSuccessLottie() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: MyColors.transparentBlack_50,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation) {
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
          ).drive(Tween<Offset>(
            begin: const Offset(0, 1),
            end: const Offset(0, 0),
          )),
          child: child,
        );
      },
    );
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

  Future<bool> _comparePin(String input) async {
    bool isSamePin = await _authProvider.verifyPin(input);
    return isSamePin;
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
      }
      setState(() {
        _showNextButton = (pin.length == _pinLength);
      });
    } else if (step == 1) {
      if (value == '<') {
        if (pinConfirm.isNotEmpty) {
          setState(() =>
              pinConfirm = pinConfirm.substring(0, pinConfirm.length - 1));
        }
      } else if (pinConfirm.length < pin.length) {
        setState(() => pinConfirm += value);
      }

      if (pinConfirm.length == pin.length) {
        if (pinConfirm == pin) {
          try {
            var hashedPin = generateHashString(pin);
            await _authProvider.savePinSet(hashedPin, pin.length);
            vibrateLightDouble();
            _showPinSetSuccessLottie();
            
            // Close the success dialog and the PIN setting screen
            await Future.delayed(const Duration(milliseconds: 1000));
            if (mounted) {
              Navigator.pop(context); // Close success dialog
              Navigator.pop(context); // Close PIN setting screen
            }
          } catch (e) {
            returnToBackSequence(t.errors.pin_setting_error.save_failed,
                isError: true, firstSequence: true);
          }
        } else {
          returnToBackSequence(t.errors.pin_setting_error.incorrect,
              isError: true, firstSequence: true);
        }
      }
    }
  }

  void _onNextPressed() async {
    if (_authProvider.isSetPin) {
      final isSamePin = await _comparePin(pin);
      if (isSamePin) {
        setState(() {
          errorMessage = t.errors.pin_setting_error.already_in_use;
        });
        vibrateMedium();
        return;
      }
    }
    setState(() {
      step = 1;
      pinConfirm = '';
      _showNextButton = false;
      _shufflePinNumbers();
    });
  }

  @override
  Widget build(BuildContext context) {
    String title = step == 0
        ? t.pin_setting_screen.new_password
        : t.pin_setting_screen.enter_again;

    Widget? centerWidget;
    if (step == 0) {
      centerWidget = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: OutlinedButton(
          onPressed: () {
            setState(() {
              _pinLength = _pinLength == 4 ? 6 : 4;
              pin = '';
              _showNextButton = false;
            });
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: CoconutColors.gray600,
            backgroundColor: Colors.transparent,
            side: BorderSide(color: CoconutColors.gray300, width: 1.0),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(8),
              ),
            ),
          ),
          child: Text(
            _pinLength == 4
                ? t.pin_setting_screen.set_to_6_digit
                : t.pin_setting_screen.set_to_4_digit,
            style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.gray300),
          ),
        ),
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
            _showNextButton = false;
          });
        },
        step: step,
        pinLength: _pinLength,
        appBarVisible: true,
        initOptionVisible: false,
        centerWidget: centerWidget,
      ),
      bottomSheet: _showNextButton
          ? Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _onNextPressed,
                  child: Text(t.next),
                ),
              ),
            )
          : null,
    );
  }
}
