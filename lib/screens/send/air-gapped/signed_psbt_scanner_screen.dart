import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/air-gapped/signed_psbt_scanner_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/animated_qr/coconut_qr_scanner.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/signed_psbt_scan_data_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

class SignedPsbtScannerScreen extends StatefulWidget {
  const SignedPsbtScannerScreen({super.key});

  @override
  State<SignedPsbtScannerScreen> createState() => _SignedPsbtScannerScreenState();
}

class _SignedPsbtScannerScreenState extends State<SignedPsbtScannerScreen> {
  bool _isProcessing = false;
  MobileScannerController? _controller;

  late final SignedPsbtScannerViewModel _viewModel;
  final SignedPsbtScanDataHandler _qrScanDataHandler = SignedPsbtScanDataHandler();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _stopCamera();
        }
      },
      child: Scaffold(
        backgroundColor: context.coconutColors.background,
        appBar: CoconutAppBar.build(
          title: t.signed_psbt_scanner_screen.title,
          context: context,
          backgroundColor: context.coconutColors.background.withValues(alpha: 0.95),
          actionButtonList: [
            IconButton(
              icon: SvgPicture.asset(
                'assets/svg/arrow-reload.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
              ),
              color: context.coconutColors.primaryText,
              onPressed: () {
                _controller?.switchCamera();
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // TODO: CoconutQrScanner -> AnimatedQrScanner로 Rename
              CoconutQrScanner(
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
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _viewModel = SignedPsbtScannerViewModel(
      Provider.of<SendInfoProvider>(context, listen: false),
      Provider.of<WalletProvider>(context, listen: false),
    );
  }

  Future<void> _onCompletedScanning(dynamic signedPsbt) async {
    final scanDataType = _qrScanDataHandler.scanDataType;
    if (!_qrScanDataHandler.isCompleted() || scanDataType == null) return;

    switch (scanDataType) {
      case SignedPsbtScanDataType.ur:
        await _onCompletedScanningForBcUr(signedPsbt);
      case SignedPsbtScanDataType.bbqr:
        await _onCompletedScanningForBbQr(signedPsbt);
      case SignedPsbtScanDataType.raw:
        await _onCompleteScanningRawSignedTx(signedPsbt as String);
    }
  }

  Future<void> _onCompletedScanningForBcUr(dynamic signedPsbt) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      await _handleProcessingResult(_viewModel.processUrSigningResult(signedPsbt));
    } catch (e) {
      await _showErrorDialog(t.alert.scan_failed_description(error: e));
    }
  }

  Future<void> _onCompletedScanningForBbQr(dynamic signedPsbt) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      await _handleProcessingResult(_viewModel.processBbQrSigningResult(signedPsbt));
    } catch (e) {
      await _showErrorDialog(t.alert.scan_failed_description(error: e));
    }
  }

  Future<void> _onCompleteScanningRawSignedTx(String rawSignedTx) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      await _handleProcessingResult(_viewModel.processRawSigningResult(rawSignedTx));
    } catch (e) {
      await _showErrorDialog(t.alert.scan_failed_description(error: e));
    }
  }

  Future<void> _handleProcessingResult(SignedScanProcessingResult result) async {
    if (!result.isSuccess) {
      await _showErrorDialog(_getProcessingErrorMessage(result));
      return;
    }

    await _stopCamera();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/broadcasting');
    }
  }

  String _getProcessingErrorMessage(SignedScanProcessingResult result) {
    return switch (result.error) {
      SignedScanProcessingError.invalidPayload => t.alert.invalid_qr,
      SignedScanProcessingError.transactionIntentMismatch => t.alert.signed_psbt.wrong_send_info,
      SignedScanProcessingError.insufficientSignatures => t.alert.signed_psbt.need_more_sign(
        count: result.missingSignatureCount!,
      ),
      null => '',
    };
  }

  void _onFailedScanning(String message, String? _) async {
    if (_isProcessing) return;
    _isProcessing = true;

    String errorMessage;
    if (message == CoconutQrScanner.qrFormatErrorMessage) {
      errorMessage = t.alert.invalid_qr;
    } else {
      errorMessage = t.alert.scan_failed_description(error: message);
    }

    await _showErrorDialog(errorMessage);
  }

  Future<void> _showErrorDialog(String errorMessage) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.alert.scan_failed,
          description: errorMessage,
          onTapRight: () {
            if (!mounted) return;

            _isProcessing = false;
            _controller?.start();
            Navigator.pop(context);
          },
          rightButtonText: t.OK,
        );
      },
    );
  }

  Future<void> _stopCamera() async {
    if (_controller != null) {
      await _controller!.stop();
    }
  }

  void _setQRViewController(MobileScannerController qrViewController) {
    _controller = qrViewController;
  }

  Widget _buildToolTip() {
    return CoconutToolTip(
      backgroundColor: context.coconutColors.surface,
      borderColor: context.coconutColors.surface,
      icon: SvgPicture.asset(
        'assets/svg/circle-info.svg',
        width: 20,
        colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
      ),
      tooltipType: CoconutTooltipType.fixed,
      richText: RichText(
        text: TextSpan(
          style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
          children: _getGuideTextSpan(),
        ),
      ),
    );
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
        style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText).copyWith(height: 1.3),
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
