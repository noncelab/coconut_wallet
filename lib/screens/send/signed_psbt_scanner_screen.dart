import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/signed_psbt_scanner_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/alert_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/animated_qr/animated_qr_scanner.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class SignedPsbtScannerScreen extends StatefulWidget {
  const SignedPsbtScannerScreen({super.key});

  @override
  State<SignedPsbtScannerScreen> createState() => _SignedPsbtScannerScreenState();
}

class _SignedPsbtScannerScreenState extends State<SignedPsbtScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  bool _isProcessing = false;
  QRViewController? controller;
  Timer? _failedScanningTimer;

  late SignedPsbtScannerViewModel _viewModel;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        _stopCamera();
        controller = null;
      },
      child: Scaffold(
        backgroundColor: MyColors.black,
        appBar: CustomAppBar.build(
          title: t.signed_psbt_scanner_screen.title,
          context: context,
          hasRightIcon: false,
          backgroundColor: MyColors.black.withOpacity(0.95),
        ),
        body: Stack(children: [
          AnimatedQrScanner(
            setQRViewController: (QRViewController qrViewcontroller) {
              controller = qrViewcontroller;
            },
            onComplete: _onCompletedScanning,
            onFailed: _onFailedScanning,
          ),
          Padding(
              padding: const EdgeInsets.only(
                  top: 20, left: CoconutLayout.defaultPadding, right: CoconutLayout.defaultPadding),
              child: CoconutToolTip(
                tooltipType: CoconutTooltipType.fixed,
                baseBackgroundColor: MyColors.white.withOpacity(0.9),
                richText: RichText(
                  text: TextSpan(
                    text: '[5] ',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      height: 1.4,
                      letterSpacing: 0.5,
                      color: MyColors.black,
                    ),
                    children: [
                      TextSpan(
                        text: t.tooltip.scan_signed_psbt,
                        style: const TextStyle(
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                showIcon: true,
              )),
        ]),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant SignedPsbtScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    String? currentRoute = ModalRoute.of(context)?.settings.name;

    if (currentRoute != null && currentRoute.startsWith('/signed-psbt-scanner')) {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _viewModel = SignedPsbtScannerViewModel(Provider.of<SendInfoProvider>(context, listen: false),
        Provider.of<WalletProvider>(context, listen: false));
  }

  void _onCompletedScanning(String signedPsbt) async {
    if (_isProcessing) return;
    _isProcessing = true;

    Psbt psbt;
    try {
      psbt = _viewModel.parseBase64EncodedToPsbt(signedPsbt);
    } catch (e) {
      _showAlert(t.alert.signed_psbt.invalid_qr);
      return;
    }

    try {
      if (!_viewModel.isPsbtAmountAndTxHashEqualTo(psbt)) {
        _showAlert(t.alert.signed_psbt.wrong_send_info);
        return;
      }

      if (_viewModel.isMultisig) {
        int missingCount = _viewModel.getMissingSignaturesCount(psbt);
        if (missingCount > 0) {
          _showAlert(t.alert.signed_psbt.need_more_sign(count: missingCount), isBack: true);
          controller?.pauseCamera();
          await _stopCamera();
          return;
        }
      }

      _viewModel.setSignedPsbt(signedPsbt);

      controller?.pauseCamera();
      await _stopCamera();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/broadcasting');
      }
    } catch (e) {
      _showAlert(t.alert.scan_failed_description(error: e));
    }
  }

  void _onFailedScanning(String message) {
    if (_isProcessing) return;
    _isProcessing = true;

    // _isProcessing 상관 없이 2번 연속 호출되는 현상으로 추가됨
    if (_failedScanningTimer?.isActive ?? false) {
      return;
    }
    _failedScanningTimer = Timer(const Duration(milliseconds: 500), () {});

    Logger.log("[SignedPsbtScannerScreen] onFailed: $message");

    String errorMessage;
    if (message.contains('Invalid Scheme')) {
      errorMessage = t.alert.signed_psbt.invalid_signature;
    } else {
      errorMessage = t.alert.scan_failed(error: message);
    }

    showAlertDialog(
        context: context,
        content: errorMessage,
        onClosed: () {
          _isProcessing = false;
        });
  }

  void _showAlert(String errorMessage, {bool isBack = false}) {
    showAlertDialog(
      context: context,
      content: errorMessage,
      dismissible: false,
      onClosed: () {
        _isProcessing = false;
        if (isBack) {
          Navigator.pop(context);
        }
      },
    );
  }

  Future<void> _stopCamera() async {
    if (controller != null) {
      await controller?.pauseCamera();
    }
  }
}
