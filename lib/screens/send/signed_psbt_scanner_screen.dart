import 'dart:async';
import 'dart:convert';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/signed_psbt_scanner_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/animated_qr/coconut_qr_scanner.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/signed_psbt_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
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
  MobileScannerController? controller;

  late SignedPsbtScannerViewModel _viewModel;
  late SignedPsbtScanDataHandler _qrScanDataHandler;
  bool _isHandlerInitialized = false;
  final int _qrScannerKey = 0; // QR 스캐너 재생성을 위한 key

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
        appBar: CoconutAppBar.build(
          title: _viewModel.isSendingDonation ? t.donation.donate : t.signed_psbt_scanner_screen.title,
          context: context,
          backgroundColor: CoconutColors.black.withOpacity(0.95),
          actionButtonList: [
            IconButton(
              icon: const Icon(CupertinoIcons.camera_rotate, size: 22),
              color: CoconutColors.white,
              onPressed: () {
                controller?.switchCamera();
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            // TODO: CoconutQrScanner -> AnimatedQrScanner로 Rename
            CoconutQrScanner(
              key: ValueKey(_qrScannerKey),
              setMobileScannerController: _setQRViewController,
              onComplete: _onCompletedScanning,
              onFailed: _onFailedScanning,
              qrDataHandler: _qrScanDataHandler,
            ),
            Padding(
              padding: const EdgeInsets.only(
                top: 20,
                left: CoconutLayout.defaultPadding,
                right: CoconutLayout.defaultPadding,
              ),
              child: _buildToolTip(),
            ),
          ],
        ),
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
    _viewModel = SignedPsbtScannerViewModel(
      Provider.of<SendInfoProvider>(context, listen: false),
      Provider.of<WalletProvider>(context, listen: false),
    );
    _initializeQrScanDataHandler();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isHandlerInitialized) {
      _initializeQrScanDataHandler();
    }
  }

  void _initializeQrScanDataHandler() {
    // 통합 핸들러로 변경
    _qrScanDataHandler = SignedPsbtScanDataHandler();
    _isHandlerInitialized = true;

    // ColdCard는 BBQR 핸들러로 시작 (Raw 데이터와 BBQR 모두 처리 가능)
    // if (_viewModel.walletImportSource == WalletImportSource.coldCard) {
    //   _qrScanDataHandler = BbQrScanDataHandler();
    //   _isHandlerInitialized = true;
    // } else {
    //   // 다른 하드웨어 지갑은 BcUr 핸들러 사용
    //   _qrScanDataHandler = BcUrQrScanDataHandler(expectedUrType: [UrType.cryptoPsbt, UrType.psbt]);
    //   _isHandlerInitialized = true;
    // }
  }

  Future<void> _onCompletedScanning(dynamic signedPsbt) async {
    assert(_qrScanDataHandler.isCompleted() && _qrScanDataHandler.scanDataType != null);

    switch (_qrScanDataHandler.scanDataType) {
      case SignedPsbtScanDataType.ur:
        await _onCompletedScanningForBcUr(signedPsbt);
      case SignedPsbtScanDataType.bbqr:
        await _onCompletedScanningForBbQr(signedPsbt);
      case SignedPsbtScanDataType.raw:
        _onCompleteScanningRawSignedTx(signedPsbt);
      default:
        throw ArgumentError('Invalid scan data type');
    }
  }

  Future<void> _onCompletedScanningForBcUr(dynamic signedPsbt) async {
    assert(signedPsbt is UR);
    if (_isProcessing) return;
    _isProcessing = true;

    Psbt psbt;
    try {
      final ur = signedPsbt as UR;
      final cborBytes = ur.cbor;
      final decodedCbor = cbor.decode(cborBytes) as CborBytes;

      psbt = _viewModel.parseBase64EncodedToPsbt(base64Encode(decodedCbor.bytes));
    } catch (e) {
      await _showErrorDialog(t.alert.invalid_qr);
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
          return;
        }
      }

      _viewModel.setSignedPsbt(psbt.serialize());

      await _stopCamera();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/broadcasting');
      }
    } catch (e) {
      await _showErrorDialog(t.alert.scan_failed_description(error: e));
    }
  }

  Future<void> _onCompletedScanningForBbQr(dynamic signedPsbt) async {
    if (_isProcessing) return;
    _isProcessing = true;

    String? encodedSignedPsbt;
    if (signedPsbt is Map) {
      final String jsonString = jsonEncode(signedPsbt);
      debugPrint(jsonString);
      encodedSignedPsbt = jsonString;
    } else if (signedPsbt is String) {
      encodedSignedPsbt = signedPsbt;
    }

    assert(encodedSignedPsbt != null);

    try {
      _viewModel.setSignedPsbt(encodedSignedPsbt!);
      await _stopCamera();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/broadcasting');
      }
    } catch (e) {
      await _showErrorDialog(t.alert.scan_failed_description(error: e));
    }
  }

  Future<void> _onCompleteScanningRawSignedTx(String rawSignedTx) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      _viewModel.setRawSignedTransaction(rawSignedTx);

      await _stopCamera();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/broadcasting');
      }
    } catch (e) {
      await _showErrorDialog(t.alert.scan_failed_description(error: e));
    }
  }

  void _onFailedScanning(String message, String? scannedData) async {
    if (_isProcessing) return;
    _isProcessing = true;

    if (!_isHandlerInitialized) {
      _initializeQrScanDataHandler();
      _isProcessing = false;
      return;
    }

    String errorMessage;
    if (message == CoconutQrScanner.qrFormatErrorMessage) {
      errorMessage = '${t.alert.invalid_qr}${scannedData != null ? "\ndata: $scannedData" : null}';
    } else {
      errorMessage = t.alert.scan_failed_description(error: message);
    }

    await _showErrorDialog(errorMessage);
  }

  Future<void> _showErrorDialog(String errorMessage) async {
    await CustomDialogs.showCustomAlertDialog(
      context,
      title: t.alert.scan_failed,
      message: errorMessage,
      onConfirm: () {
        _isProcessing = false;
        controller?.start();
        Navigator.pop(context);
      },
    );
  }

  Future<void> _stopCamera() async {
    if (controller != null) {
      await controller!.stop();
    }
  }

  void _setQRViewController(MobileScannerController qrViewcontroller) {
    controller = qrViewcontroller;
  }

  Widget _buildToolTip() {
    // TODO: 코코넛 지갑인 경우 UI는 볼트와 한꺼번에 수정합니다.
    if (_viewModel.isSendingDonation == true) {
      return Padding(
        padding: const EdgeInsets.only(top: 30),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(t.donation.signed_qr_tooltip, style: CoconutTypography.body2_14_Bold),
        ),
      );
    } else {
      return CoconutToolTip(
        backgroundColor: CoconutColors.gray900,
        borderColor: CoconutColors.gray900,
        icon: SvgPicture.asset(
          'assets/svg/circle-info.svg',
          width: 20,
          colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
        ),
        tooltipType: CoconutTooltipType.fixed,
        richText: RichText(text: TextSpan(style: CoconutTypography.body2_14, children: _getGuideTextSpan())),
      );
    }
  }

  List<TextSpan> _getGuideTextSpan() {
    final hardwareWalletWords = _getHardwareWalletWords();
    return [
      // TODO: third party 추가 시 [5]가 갑자기 나와서 임시 주석 처리
      // TextSpan(
      //   text: '[5] ',
      //   style: CoconutTypography.body2_14_Bold.copyWith(height: 1),
      // ),
      TextSpan(
        text: t.tooltip.scan_signed_psbt.guide(
          by_hardware_wallet: hardwareWalletWords[0],
          hardware_wallet: hardwareWalletWords[1],
        ),
        style: CoconutTypography.body2_14.copyWith(height: 1.3),
      ),
    ];
  }

  List<String> _getHardwareWalletWords() {
    switch (_viewModel.walletImportSource) {
      case WalletImportSource.coconutVault:
        return [t.tooltip.scan_signed_psbt.by_vault_app, t.vault_app];
      case WalletImportSource.keystone:
        return [t.tooltip.scan_signed_psbt.by_keystone, t.third_party.keystone];
      case WalletImportSource.jade:
        return [t.tooltip.scan_signed_psbt.by_jade, t.third_party.jade];
      case WalletImportSource.seedSigner:
        return [t.tooltip.scan_signed_psbt.by_seed_signer, t.third_party.seed_signer];
      case WalletImportSource.coldCard:
        return [t.tooltip.scan_signed_psbt.by_coldcard, t.third_party.cold_card];
      case WalletImportSource.krux:
        return [t.tooltip.scan_signed_psbt.by_krux, t.third_party.krux];
      default:
        return [t.tooltip.scan_signed_psbt.by_hardware_wallet, t.hardware_wallet];
    }
  }
}
