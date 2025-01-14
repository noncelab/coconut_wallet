import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:coconut_wallet/providers/app_sub_state_model.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/pin/pin_input.dart';
import 'package:provider/provider.dart';

// TODO: ViewModel - 위젯 내부 Provider 제거
class PinCheckBottomSheet extends StatefulWidget {
  final bool appEntrance;
  final Function? onComplete;
  const PinCheckBottomSheet(
      {super.key, this.appEntrance = false, this.onComplete});

  @override
  State<PinCheckBottomSheet> createState() => _PinCheckBottomSheetState();
}

class _PinCheckBottomSheetState extends State<PinCheckBottomSheet>
    with WidgetsBindingObserver {
  late String pin;
  late String errorMessage;
  // when widget.appEntrance is true
  int attempt = 0;
  static const MAX_NUMBER_OF_ATTEMPTS = 3;
  final GlobalKey<PinInputState> _pinInputScreenKey =
      GlobalKey<PinInputState>();

  late AppSubStateModel _subModel;
  bool _isPause = false;

  @override
  void initState() {
    super.initState();
    pin = '';
    errorMessage = '';

    _subModel = Provider.of<AppSubStateModel>(context, listen: false);
    if (_subModel.isSetBiometrics && _subModel.canCheckBiometrics) {
      _verifyBiometric();
    }

    /// appEntrance인 경우 AppGuard가 위젯트리에 없으므로 추가
    if (widget.appEntrance) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (AppLifecycleState.paused == state) {
      _isPause = true;
    } else if (AppLifecycleState.resumed == state && _isPause) {
      _isPause = false;
      _subModel.checkDeviceBiometrics();
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
    _subModel.authenticateWithBiometrics().then((value) {
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
    _subModel.verifyPin(pin).then((value) {
      if (value) {
        if (!widget.appEntrance) {
          Navigator.pop(context, true);
        }
        widget.onComplete?.call();
      } else {
        if (widget.appEntrance) {
          attempt += 1;
          if (attempt < 3) {
            errorMessage = '${MAX_NUMBER_OF_ATTEMPTS - attempt}번 다시 시도할 수 있어요';
            _subModel.shuffleNumbers();
            vibrateLightDouble();
          } else {
            errorMessage = '더 이상 시도할 수 없어요\n앱을 종료해 주세요';
          }
        } else {
          errorMessage = '비밀번호가 일치하지 않아요';
          _subModel.shuffleNumbers();
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
      await _subModel.resetPassword();
      widget.onComplete?.call();
      Navigator.of(context).pop();
    }, onCancel: () {
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PinInput(
      key: _pinInputScreenKey,
      appBarVisible: widget.appEntrance ? false : true,
      title: widget.appEntrance ? '' : '비밀번호를 눌러주세요',
      initOptionVisible: widget.appEntrance ? true : false,
      pin: pin,
      errorMessage: errorMessage,
      onKeyTap: _onKeyTap,
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
