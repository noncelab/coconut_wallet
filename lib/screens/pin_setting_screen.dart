import 'package:flutter/material.dart';
import 'package:coconut_wallet/providers/app_sub_state_model.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/animated_dialog.dart';
import 'package:coconut_wallet/widgets/pin/pin_input_screen.dart';
import 'package:provider/provider.dart';

class PinSettingScreen extends StatefulWidget {
  const PinSettingScreen({super.key});

  @override
  State<PinSettingScreen> createState() => _PinSettingScreenState();
}

class _PinSettingScreenState extends State<PinSettingScreen> {
  int step = 0;
  late String pin;
  late String pinConfirm;
  late String errorMessage;
  late AppSubStateModel _subModel;

  @override
  void initState() {
    super.initState();
    pin = '';
    pinConfirm = '';
    errorMessage = '';
    _subModel = Provider.of<AppSubStateModel>(context, listen: false);
  }

  void _showPinSetDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: MyColors.transparentBlack_50,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (BuildContext buildContext, Animation animation,
          Animation secondaryAnimation) {
        return AnimatedDialog(
          context: buildContext,
          lottieAddress: 'assets/lottie/pin-locked-success.json',
          // body: '비밀번호가 설정되었습니다.',
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

  void returnToBackSequence(String message,
      {bool isError = false, bool firstSequence = false}) {
    setState(() {
      errorMessage = message;
      pinConfirm = '';
      _subModel.shuffleNumbers(isSettings: true);
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
    bool isSamePin = await _subModel.verifyPin(input);
    return isSamePin;
  }

  void _onKeyTap(String value) async {
    if (step == 0) {
      if (value == '<') {
        if (pin.isNotEmpty) {
          setState(() {
            pin = pin.substring(0, pin.length - 1);
          });
        }
      } else if (pin.length < 4) {
        setState(() {
          pin += value;
        });
      }

      if (pin.length == 4) {
        try {
          bool isAlreadyUsingPin = await _comparePin(pin);

          if (isAlreadyUsingPin) {
            returnToBackSequence('이미 사용중인 비밀번호예요', firstSequence: true);
            return;
          }
        } catch (error) {
          returnToBackSequence('처리 중 문제가 발생했어요', isError: true);
          return;
        }
        setState(() {
          step = 1;
          errorMessage = '';
          _subModel.shuffleNumbers(isSettings: true);
        });
      }
    } else if (step == 1) {
      setState(() {
        if (value == '<') {
          if (pinConfirm.isNotEmpty) {
            pinConfirm = pinConfirm.substring(0, pinConfirm.length - 1);
          }
        } else if (pinConfirm.length < 4) {
          pinConfirm += value;
        }
      });

      if (pinConfirm.length == 4) {
        if (pin != pinConfirm) {
          returnToBackSequence('비밀번호가 일치하지 않아요');
          return;
        }

        vibrateLight();

        _subModel.savePinSet(pin).then((_) async {
          _showPinSetDialog();
          await Future.delayed(const Duration(seconds: 3));
          Navigator.pop(context);
          Navigator.pop(context);
        }).catchError((_) {
          returnToBackSequence('저장 중 문제가 발생했어요', isError: true);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PinInputScreen(
      title: step == 0 ? '새로운 비밀번호를 눌러주세요' : '다시 한번 확인할게요',
      pin: step == 0 ? pin : pinConfirm,
      errorMessage: errorMessage,
      onKeyTap: _onKeyTap,
      onClosePressed: step == 0
          ? () {
              Navigator.pop(context); // Pin 설정 취소
            }
          : () {
              setState(() {
                pin = '';
                pinConfirm = '';
                step = 0;
              });
            },
      onBackPressed: () {
        setState(() {
          pin = '';
          pinConfirm = '';
          errorMessage = '';
          step = 0;
        });
      },
      step: step,
    );
  }
}
