import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/confirm_backup_data_view_model.dart';
import 'package:coconut_wallet/widgets/animated_qr/coconut_qr_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

class ConfirmBackupDataScreen extends StatefulWidget {
  final int id;
  final String walletName;
  const ConfirmBackupDataScreen({super.key, required this.id, required this.walletName});

  @override
  State<ConfirmBackupDataScreen> createState() => _ConfirmBackupDataScreenState();
}

class _ConfirmBackupDataScreenState extends State<ConfirmBackupDataScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  MobileScannerController? controller;
  bool _isProcessing = false;
  late ConfirmBackupDataViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ConfirmBackupDataViewModel();
  }

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pause();
    } else if (Platform.isIOS) {
      controller!.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CoconutAppBar.build(title: t.wallet_info_screen.confirm_backup_data, context: context),
      body: Stack(
        children: [
          CoconutQrScanner(
            setMobileScannerController: (MobileScannerController qrViewcontroller) {
              controller = qrViewcontroller;
            },
            onComplete: _onCompletedScanning,
            onFailed: _onFailedScanning,
            qrDataHandler: _viewModel.qrDataHandler,
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 20,
              left: CoconutLayout.defaultPadding,
              right: CoconutLayout.defaultPadding,
            ),
            child: CoconutToolTip(
              backgroundColor: CoconutColors.white,
              borderColor: CoconutColors.white,
              icon: SvgPicture.asset(
                'assets/svg/circle-info.svg',
                width: 20,
                colorFilter: const ColorFilter.mode(CoconutColors.black, BlendMode.srcIn),
              ),
              tooltipType: CoconutTooltipType.fixed,
              richText: RichText(
                text: TextSpan(
                  style: CoconutTypography.body2_14.setColor(CoconutColors.black),
                  children: _getGuideTextSpan(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _em(String text) => TextSpan(text: text, style: CoconutTypography.body2_14_Bold.copyWith(height: 1.3));

  List<TextSpan> _getGuideTextSpan() {
    final isEnglish = Provider.of<PreferenceProvider>(context, listen: false).isEnglish;

    if (!isEnglish) {
      return [
        _em(t.wallet_info_screen.tooltip.confirm_backup_data.step1_em(name: widget.walletName)),
        const TextSpan(text: '\n'),
        _em(t.wallet_info_screen.tooltip.confirm_backup_data.step2_em),
        TextSpan(text: t.wallet_info_screen.tooltip.confirm_backup_data.select),
        const TextSpan(text: '\n'),
        _em(t.wallet_info_screen.tooltip.confirm_backup_data.step3_em),
        TextSpan(text: t.wallet_info_screen.tooltip.confirm_backup_data.select),
        const TextSpan(text: '\n'),
        TextSpan(text: t.wallet_info_screen.tooltip.confirm_backup_data.step4),
      ];
    } else {
      return [
        _em(t.wallet_info_screen.tooltip.confirm_backup_data.step1_em(name: widget.walletName)),
        const TextSpan(text: '\n'),
        _em(t.wallet_info_screen.tooltip.confirm_backup_data.step2_preposition),
        TextSpan(text: t.wallet_info_screen.tooltip.confirm_backup_data.select),
        _em(t.wallet_info_screen.tooltip.confirm_backup_data.step2_em),
        const TextSpan(text: '\n'),
        _em(t.wallet_info_screen.tooltip.confirm_backup_data.step3_preposition),
        TextSpan(text: t.wallet_info_screen.tooltip.confirm_backup_data.select),
        _em(t.wallet_info_screen.tooltip.confirm_backup_data.step3_em),
        const TextSpan(text: '\n'),
        TextSpan(text: t.wallet_info_screen.tooltip.confirm_backup_data.step4),
      ];
    }
  }

  Future<void> _onCompletedScanning(dynamic additionInfo) async {
    if (_isProcessing) return;

    _isProcessing = true;
    try {
      throw Exception('그냥 에러');
    } catch (e) {
      _onFailedScanning(e.toString(), null);
      Navigator.pop(context);
    }
  }

  void _onFailedScanning(String message, String? scannedData) async {
    if (_isProcessing) {
      return;
    }
    _isProcessing = true;

    String errorMessage;
    if (message == CoconutQrScanner.qrFormatErrorMessage) {
      errorMessage = '${t.alert.invalid_qr}${scannedData != null ? "\ndata: $scannedData" : null}';
    } else {
      errorMessage = t.alert.scan_failed_description(error: message);
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CoconutPopup(
          title: t.alert.scan_failed,
          description: errorMessage,
          rightButtonText: t.confirm,
          rightButtonColor: CoconutColors.white,
          onTapRight: () {
            _isProcessing = false;
            Navigator.pop(context);
          },
        );
      },
    );
  }
}
