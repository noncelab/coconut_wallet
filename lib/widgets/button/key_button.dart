import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:local_auth/local_auth.dart';
import 'package:coconut_wallet/styles.dart';

class KeyButton extends StatefulWidget {
  final String keyValue;
  final ValueChanged<String> onKeyTap;
  final bool isEnabled;

  const KeyButton({
    super.key,
    required this.keyValue,
    required this.onKeyTap,
    this.isEnabled = true,
  });

  @override
  State<KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<KeyButton> {
  bool _isPressed = false;
  bool _isFaceRecognition = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricType();
  }

  Future<void> _checkBiometricType() async {
    final LocalAuthentication auth = LocalAuthentication();

    try {
      final List<BiometricType> availableBiometrics = await auth.getAvailableBiometrics();

      if (Platform.isIOS) {
        if (availableBiometrics.contains(BiometricType.face)) {
          setState(() {
            _isFaceRecognition = true;
          });
        }
      } else {
        // aos fingerprint included case
        if (availableBiometrics.contains(BiometricType.strong) &&
            availableBiometrics.contains(BiometricType.weak)) {
          setState(() {
            _isFaceRecognition = false;
          });
        } else if (!availableBiometrics.contains(BiometricType.strong) &&
            availableBiometrics.contains(BiometricType.weak)) {
          setState(() {
            _isFaceRecognition = true;
          });
        }
      }
    } catch (e) {
      Logger.log('생체 인식 유형을 확인하는 중 오류 발생: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          if (!widget.isEnabled) return;
          widget.onKeyTap(widget.keyValue);
        },
        onTapDown: (_) {
          if (!widget.isEnabled) return;
          setState(() {
            _isPressed = true;
          });
        },
        onTapCancel: () {
          if (!widget.isEnabled) return;
          setState(() {
            _isPressed = false;
          });
        },
        onTapUp: (_) {
          if (!widget.isEnabled) return;
          setState(() {
            _isPressed = false;
          });
        },
        child: Container(
          width: 120,
          height: 60,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color:
                  _isPressed ? MyColors.defaultBackground : Colors.transparent // 버튼의 상태에 따라 색상 변경
              ),
          child: Center(
              child: widget.keyValue == '<'
                  ? Icon(Icons.backspace,
                      color: widget.isEnabled ? CoconutColors.white : CoconutColors.gray700,
                      size: 20)
                  : widget.keyValue == 'bio'
                      ? _isFaceRecognition
                          ? SvgPicture.asset('assets/svg/face-id.svg',
                              width: 20,
                              colorFilter: ColorFilter.mode(
                                  widget.isEnabled ? CoconutColors.white : CoconutColors.gray700,
                                  BlendMode.srcIn))
                          : SvgPicture.asset('assets/svg/fingerprint.svg',
                              width: 20,
                              colorFilter: ColorFilter.mode(
                                  widget.isEnabled ? CoconutColors.white : CoconutColors.gray700,
                                  BlendMode.srcIn))
                      : Text(
                          widget.keyValue,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: widget.isEnabled ? CoconutColors.white : CoconutColors.gray700,
                              fontFamily: 'SpaceGrotesk'),
                        )),
        ));
  }
}
