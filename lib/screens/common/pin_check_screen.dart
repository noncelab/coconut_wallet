import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/pin/pin_input_pad.dart';
import 'package:provider/provider.dart';

class PinCheckScreen extends StatefulWidget {
  final bool appEntrance;
  final Function? onComplete;
  const PinCheckScreen({
    super.key,
    this.appEntrance = false,
    this.onComplete,
  });

  @override
  State<PinCheckScreen> createState() => _PinCheckScreenState();
}

class _PinCheckScreenState extends State<PinCheckScreen>
    with WidgetsBindingObserver {
  static const kMaxNumberOfAttempts = 3;
  late String pin;
  late String errorMessage;
  // when widget.appEntrance is true
  int attempt = 0;
  final GlobalKey<PinInputPadState> _pinInputScreenKey =
      GlobalKey<PinInputPadState>();
  late List<String> _shuffledPinNumbers;
  late AuthProvider _authProvider;
  //late AppSubStateModel _subModel;
  bool _isPause = false;

  @override
  void initState() {
    super.initState();
    pin = '';
    errorMessage = '';

    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _shuffledPinNumbers = _authProvider.getShuffledNumberPad();
    if (_authProvider.isSetBiometrics && _authProvider.canCheckBiometrics) {
      _verifyBiometric();
    }
    //_subModel = Provider.of<AppSubStateModel>(context, listen: false);
    // if (_subModel.isSetBiometrics && _subModel.canCheckBiometrics) {
    //   _verifyBiometric();
    // }

    /// appEntrance인 경우 AppGuard가 위젯트리에 없으므로 추가
    if (widget.appEntrance) {
      WidgetsBinding.instance.addObserver(this);
    }
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
      //_subModel.checkDeviceBiometrics();
    }
  }

  @override
  void dispose() {
    super.dispose();
    if (widget.appEntrance) {
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  void _verifyBiometric() async {
    context.loaderOverlay.show();
    _authProvider.authenticateWithBiometrics().then((value) {
      if (value) {
        if (!widget.appEntrance) {
          Navigator.pop(context, true);
        }
        widget.onComplete?.call();
      }
    }).whenComplete(() {
      if (context.mounted) context.loaderOverlay.hide();
    });
  }

  void _verifyPin() async {
    context.loaderOverlay.show();
    _authProvider.verifyPin(pin).then((value) {
      if (value) {
        if (!widget.appEntrance) {
          Navigator.pop(context, true);
        }
        widget.onComplete?.call();
      } else {
        if (widget.appEntrance) {
          attempt += 1;
          if (attempt < 3) {
            errorMessage = '${kMaxNumberOfAttempts - attempt}번 다시 시도할 수 있어요';
            _shufflePinNumbers();
            vibrateLightDouble();
          } else {
            errorMessage = '더 이상 시도할 수 없어요\n앱을 종료해 주세요';
          }
        } else {
          errorMessage = '비밀번호가 일치하지 않아요';
          _shufflePinNumbers();
          vibrateLightDouble();
        }
        pin = '';
      }

      setState(() {});
    }).whenComplete(() => context.loaderOverlay.hide());
  }

  void _onKeyTap(String value) {
    if (value == 'bio') {
      _verifyBiometric();
      return;
    }

    if (widget.appEntrance && attempt == 3) {
      return;
    }

    setState(() {
      if (value == '<') {
        if (pin.isNotEmpty) {
          pin = pin.substring(0, pin.length - 1);
        }
      } else if (pin.length < 4) {
        pin += value;
      }
    });

    if (pin.length == 4) {
      _verifyPin();
    }
  }

  void _showDialog() {
    vibrateMedium();

    CustomDialogs.showCustomAlertDialog(context,
        title: '비밀번호를 잊으셨나요?',
        message: '[다시 설정]을 눌러 비밀번호를 초기화할 수 있어요. 비밀번호를 바꾸면 동기화된 지갑 목록이 초기화 돼요.',
        confirmButtonText: '다시 설정',
        confirmButtonColor: MyColors.warningRed,
        cancelButtonText: '닫기', onConfirm: () async {
      await _authProvider.resetPassword();
      widget.onComplete?.call();
      Navigator.of(context).pop();
    }, onCancel: () {
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PinInputPad(
      key: _pinInputScreenKey,
      appBarVisible: widget.appEntrance ? false : true,
      title: widget.appEntrance ? '' : '비밀번호를 눌러주세요',
      initOptionVisible: widget.appEntrance ? true : false,
      pin: pin,
      errorMessage: errorMessage,
      onKeyTap: _onKeyTap,
      pinShuffleNumbers: _shuffledPinNumbers,
      onClosePressed: () {
        Navigator.pop(context);
      },
      onReset: widget.appEntrance
          ? () {
              _showDialog();
            }
          : null,
      step: 0,
    );
  }
}
