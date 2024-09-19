import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/widgets/animatedQR/animated_qr_scanner.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/alert_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/custom_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class SignedPsbtScannerScreen extends StatefulWidget {
  final int id;
  //final AddressType addressType;

  const SignedPsbtScannerScreen({super.key, required this.id});

  @override
  State<SignedPsbtScannerScreen> createState() =>
      _SignedPsbtScannerScreenState();
}

class _SignedPsbtScannerScreenState extends State<SignedPsbtScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  late AppStateModel _model;
  bool _isProcessing = false;
  QRViewController? controller;

  @override
  void initState() {
    super.initState();
    _model = Provider.of<AppStateModel>(context, listen: false);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _stopCamera() async {
    if (controller != null) {
      await controller?.pauseCamera();
    }
  }

  void onCompletedScanning(String signedPsbt) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // signedPSBT는 Base64 인코딩 된 문자열입니다.
      PSBT.parse(signedPsbt);

      if (!validateSignedPsbt(signedPsbt)) {
        throw ('invalidSignedPsbt');
      }
      final model = Provider.of<AppStateModel>(context, listen: false);
      model.signedTransaction = signedPsbt;

      controller?.pauseCamera();
      await _stopCamera();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/broadcasting',
            arguments: {'id': widget.id});
      }
    } catch (e) {
      Logger.log('Exception while QR Processing : $e');
      if (context.mounted) {
        String errorMessage;
        if (e.toString().contains('FormatException: Invalid character') ||
            e.toString().contains('Invalid PSBT')) {
          errorMessage = '잘못된 QR코드예요.\n다시 확인해 주세요.';
        } else if (e.toString().contains('invalidSignedPsbt')) {
          // 처음에 보내기로 한 트랜잭션이 아닌 경우
          errorMessage = '전송 정보가 달라요.\n처음부터 다시 시도해 주세요.';
        } else {
          errorMessage = 'QR코드 스캔에 실패했어요. 다시 시도해 주세요.';
        }
        showAlertDialog(
            context: context,
            content: errorMessage,
            dismissible: false,
            onClosed: () {
              _isProcessing = false;
            });
      }
    }
  }

  void onFailedScanning(String message) {
    if (_isProcessing) return;
    _isProcessing = true;
    Logger.log("[SignedPsbtScannerScreen] onFailed: $message");

    String errorMessage;
    if (message.contains('Invalid Scheme')) {
      errorMessage = '잘못된 서명 정보에요. 다시 시도해 주세요.';
    } else {
      errorMessage = '[스캔 실패] $message';
    }

    showAlertDialog(
        context: context,
        content: errorMessage,
        onClosed: () {
          _isProcessing = false;
        });
  }

  bool validateSignedPsbt(String signedPsbtBase64) {
    try {
      var unsignedPsbt = PSBT.parse(_model.txWaitingForSign!);
      var signedPsbt = PSBT.parse(signedPsbtBase64);

      return unsignedPsbt.sendingAmount == signedPsbt.sendingAmount &&
          unsignedPsbt.unsignedTransaction?.transactionHash ==
              signedPsbt.unsignedTransaction?.transactionHash;
    } catch (e) {
      return false;
    }
  }

  @override
  void didUpdateWidget(covariant SignedPsbtScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    String? currentRoute = ModalRoute.of(context)?.settings.name;

    if (currentRoute != null &&
        currentRoute.startsWith('/signed-psbt-scanner')) {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        _stopCamera();
        controller = null;
      },
      child: Scaffold(
        backgroundColor: MyColors.black,
        appBar: CustomAppBar.build(
          title: '서명 트랜잭션 읽기',
          context: context,
          hasRightIcon: false,
          backgroundColor: MyColors.black.withOpacity(0.95),
        ),
        body: Stack(children: [
          AnimatedQrScanner(
            setQRViewController: (QRViewController qrViewcontroller) {
              controller = qrViewcontroller;
            },
            onComplete: onCompletedScanning,
            onFailed: onFailedScanning,
          ),
          Padding(
              padding: const EdgeInsets.only(top: 20),
              child: CustomTooltip(
                  backgroundColor: MyColors.white.withOpacity(0.9),
                  richText: RichText(
                    text: const TextSpan(
                      text: '[5] ',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        height: 1.4,
                        letterSpacing: 0.5,
                        color: MyColors.black,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text:
                              '볼트 앱에서 생성된 서명 트랜잭션이 보이시나요? 이제, QR 코드를 스캔해 주세요.',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  showIcon: true,
                  type: TooltipType.info)),
        ]),
      ),
    );
  }
}
