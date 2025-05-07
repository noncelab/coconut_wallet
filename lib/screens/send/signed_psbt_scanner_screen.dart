import 'dart:async';
import 'dart:convert';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/signed_psbt_scanner_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/print_util.dart';
import 'package:coconut_wallet/widgets/animated_qr/animated_qr_scanner.dart';
import 'package:coconut_wallet/widgets/animated_qr/coconut_qr_scanner.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/bc_ur_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:ur/ur.dart';
import 'package:cbor/cbor.dart';

class SignedPsbtScannerScreen extends StatefulWidget {
  const SignedPsbtScannerScreen({super.key});

  @override
  State<SignedPsbtScannerScreen> createState() => _SignedPsbtScannerScreenState();
}

class _SignedPsbtScannerScreenState extends State<SignedPsbtScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  bool _isProcessing = false;
  QRViewController? controller;

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
        backgroundColor: CoconutColors.black,
        appBar: CustomAppBar.build(
          title: t.signed_psbt_scanner_screen.title,
          context: context,
          hasRightIcon: false,
          backgroundColor: CoconutColors.black.withOpacity(0.95),
        ),
        body: Stack(children: [
          /// TODO: CoconutVault도 BC_UR 타입으로 변경 후 AnimatedQrScanner를 CoconutQrScanner로 대체할 수 있습니다.
          /// CoconutQrScanner가 AnimatedQrScanner로 renaming 되는 형태
          if (_viewModel.walletImportSource == WalletImportSource.coconutVault) ...[
            AnimatedQrScanner(
              setQrViewController: _setQRViewController,
              onComplete: _onCompletedScanningForCoconut,
              onFailed: _onFailedScanning,
            )
          ] else ...[
            CoconutQrScanner(
                setQrViewController: _setQRViewController,
                onComplete: _onCompletedScanningForBcUr,
                onFailed: _onFailedScanning,
                qrDataHandler: BcUrQrScanDataHandler())
          ],
          Padding(
              padding: const EdgeInsets.only(
                  top: 20, left: CoconutLayout.defaultPadding, right: CoconutLayout.defaultPadding),
              child: _buildToolTip()),
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

  /// TODO: CoconutVault도 BC_UR 타입으로 변경 후 AnimatedQrScanner가 제거되면 아래 함수가 제거될 예정입니다.
  /// 중복 코드 양해바랍니다.
  Future<void> _onCompletedScanningForCoconut(String signedPsbt) async {
    if (_isProcessing) return;
    _isProcessing = true;

    Psbt psbt;
    try {
      psbt = _viewModel.parseBase64EncodedToPsbt(signedPsbt);
      printLongString('--> coconut psbt: ${psbt.serialize()}');
    } catch (e) {
      await _showErrorDialog(t.alert.signed_psbt.invalid_qr);
      return;
    }

    try {
      if (!_viewModel.isSignedPsbtMatchingUnsignedPsbt(psbt)) {
        await _showErrorDialog(t.alert.signed_psbt.wrong_send_info);
        return;
      }

      if (_viewModel.isMultisig) {
        int missingCount = _viewModel.getMissingSignaturesCount(psbt);
        if (missingCount > 0) {
          await _showErrorDialog(t.alert.signed_psbt.need_more_sign(count: missingCount));
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
      await _showErrorDialog(t.alert.scan_failed_description(error: e));
    }
  }

  Future<void> _onCompletedScanningForBcUr(dynamic signedPsbt) async {
    assert(signedPsbt is UR);
    if (_isProcessing) return;
    _isProcessing = true;

    final ur = signedPsbt as UR;
    final cborBytes = ur.cbor;
    final decodedCbor = cbor.decode(cborBytes) as CborBytes;

    Psbt psbt;
    try {
      printLongString('--> _onCompletedScanningForBcUr: ${base64Encode(decodedCbor.bytes)}');
      psbt = _viewModel.parseBase64EncodedToPsbt(base64Encode(decodedCbor.bytes));
    } catch (e) {
      await _showErrorDialog(t.alert.signed_psbt.invalid_qr);
      return;
    }

    try {
      if (!_viewModel.isSignedPsbtMatchingUnsignedPsbt(psbt)) {
        await _showErrorDialog(t.alert.signed_psbt.wrong_send_info);
        return;
      }

      if (_viewModel.isMultisig) {
        int missingCount = _viewModel.getMissingSignaturesCount(psbt);
        if (missingCount > 0) {
          await _showErrorDialog(t.alert.signed_psbt.need_more_sign(count: missingCount));
          controller?.pauseCamera();
          await _stopCamera();
          return;
        }
      }

      _viewModel.setSignedPsbt(psbt.serialize());

      controller?.pauseCamera();
      await _stopCamera();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/broadcasting');
      }
    } catch (e) {
      await _showErrorDialog(t.alert.scan_failed_description(error: e));
    }
  }

  void _onFailedScanning(String message) async {
    if (_isProcessing) return;
    _isProcessing = true;

    Logger.error("[SignedPsbtScannerScreen] onFailed: $message");

    String errorMessage;
    if (message.contains('Invalid Scheme')) {
      errorMessage = t.alert.signed_psbt.invalid_signature;
    } else {
      errorMessage = t.alert.scan_failed_description(error: message);
    }

    await _showErrorDialog(errorMessage);
  }

  Future<void> _showErrorDialog(String errorMessage) async {
    await CustomDialogs.showCustomAlertDialog(context,
        title: t.alert.scan_failed, message: errorMessage, onConfirm: () {
      _isProcessing = false;
      Navigator.pop(context);
    });
  }

  Future<void> _stopCamera() async {
    if (controller != null) {
      await controller?.pauseCamera();
    }
  }

  void _setQRViewController(QRViewController qrViewcontroller) {
    controller = qrViewcontroller;
  }

  Widget _buildToolTip() {
    // TODO: 코코넛 지갑인 경우 UI는 볼트와 한꺼번에 수정합니다.
    if (_viewModel.walletImportSource == WalletImportSource.coconutVault) {
      return CoconutToolTip(
        tooltipType: CoconutTooltipType.fixed,
        baseBackgroundColor: CoconutColors.white.withOpacity(0.9),
        richText: RichText(
          text: TextSpan(
            text: '[5] ',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.bold,
              fontSize: 15,
              height: 1.4,
              letterSpacing: 0.5,
              color: CoconutColors.black,
            ),
            children: [
              TextSpan(
                text: t.tooltip.scan_signed_psbt(hardware_wallet: t.vault_app),
                style: const TextStyle(
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        showIcon: true,
      );
    } else {
      return CoconutToolTip(
        backgroundColor: CoconutColors.gray900,
        borderColor: CoconutColors.gray900,
        icon: SvgPicture.asset(
          'packages/coconut_design_system/assets/svg/info_circle.svg',
          colorFilter: const ColorFilter.mode(
            CoconutColors.white,
            BlendMode.srcIn,
          ),
        ),
        tooltipType: CoconutTooltipType.fixed,
        richText: RichText(
          text: TextSpan(
            style: CoconutTypography.body3_12,
            children: _getGuideTextSpan(),
          ),
        ),
      );
    }
  }

  List<TextSpan> _getGuideTextSpan() {
    return [
      TextSpan(text: t.tooltip.scan_signed_psbt(hardware_wallet: _getHardwareWalletWords())),
    ];
  }

  String _getHardwareWalletWords() {
    switch (_viewModel.walletImportSource) {
      case WalletImportSource.coconutVault:
        return t.vault_app;
      case WalletImportSource.keystone:
        return t.third_party.keystone;
      case WalletImportSource.seedSigner:
        return t.third_party.seedSigner;
      default:
        return t.hardware_wallet;
    }
  }
}
