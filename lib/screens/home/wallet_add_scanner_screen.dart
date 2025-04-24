import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_add_scanner_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/animated_qr/coconut_qr_scanner.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class WalletAddScannerScreen extends StatefulWidget {
  final WalletImportSource importSource;
  const WalletAddScannerScreen({super.key, required this.importSource});

  @override
  State<WalletAddScannerScreen> createState() => _WalletAddScannerScreenState();
}

class _WalletAddScannerScreenState extends State<WalletAddScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;
  Timer? _failedScanningTimer;
  late WalletAddScannerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = WalletAddScannerViewModel(
        widget.importSource, Provider.of<WalletProvider>(context, listen: false));
  }

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pauseCamera();
    } else if (Platform.isIOS) {
      controller!.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: CustomAppBar.build(
          title: t.wallet_add_scanner_screen.text,
          context: context,
          hasRightIcon: true,
          isBottom: true,
          backgroundColor: CoconutColors.black.withOpacity(0.95),
          rightIconButton: IconButton(
            onPressed: () {
              if (controller != null) {
                controller!.flipCamera();
              }
            },
            icon: const Icon(CupertinoIcons.camera_rotate, size: 20),
            color: CoconutColors.white,
          ),
          showTestnetLabel: false,
        ),
        body: Stack(children: [
          CoconutQrScanner(
            setQRViewController: (QRViewController qrViewcontroller) {
              controller = qrViewcontroller;
            },
            onComplete: _onCompletedScanning,
            onFailed: _onFailedScanning,
            qrDataHandler: _viewModel.qrDataHandler,
          ),
          Padding(
              padding: const EdgeInsets.only(
                  top: 20, left: CoconutLayout.defaultPadding, right: CoconutLayout.defaultPadding),
              child: CoconutToolTip(
                  baseBackgroundColor: CoconutColors.white.withOpacity(0.95),
                  tooltipType: CoconutTooltipType.fixed,
                  richText: RichText(
                    text: TextSpan(
                      text: t.tooltip.wallet_add1,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.normal,
                        fontSize: 15,
                        height: 1.4,
                        letterSpacing: 0.5,
                        color: CoconutColors.black,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: t.tooltip.wallet_add2,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: t.tooltip.wallet_add3,
                          style: const TextStyle(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        TextSpan(
                          text: t.tooltip.wallet_add4,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: t.tooltip.wallet_add5,
                          style: const TextStyle(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ))),
        ]));
  }

  Future<void> _onCompletedScanning(dynamic additionInfo) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      ResultOfSyncFromVault addResult = await _viewModel.addWallet(additionInfo);
      if (!mounted) return;
      switch (addResult.result) {
        case WalletSyncResult.newWalletAdded:
        case WalletSyncResult.existingWalletUpdated:
          {
            Navigator.pop(context, addResult);
            break;
          }
        case WalletSyncResult.existingWalletNoUpdate:
          {
            vibrateLightDouble();
            CustomDialogs.showCustomAlertDialog(context,
                title: t.alert.wallet_add.update_failed,
                message: t.alert.wallet_add.update_failed_description(
                    name: TextUtils.ellipsisIfLonger(
                  _viewModel.getWalletName(addResult.walletId!),
                  maxLength: 15,
                )), onConfirm: () {
              _isProcessing = false;
              Navigator.pop(context);
            });
            break;
          }
        case WalletSyncResult.existingName:
          vibrateLightDouble();
          if (mounted) {
            CustomDialogs.showCustomAlertDialog(context,
                title: t.alert.wallet_add.duplicate_name,
                message: t.alert.wallet_add.duplicate_name_description, onConfirm: () {
              _isProcessing = false;
              Navigator.pop(context);
            });
          }
        case WalletSyncResult.existingWalletUpdateImpossible:
          vibrateLightDouble();
          if (mounted) {
            CustomDialogs.showCustomAlertDialog(context,
                title: t.alert.wallet_add.already_exist,
                message: t.alert.wallet_add.already_exist_description(
                    name: TextUtils.ellipsisIfLonger(_viewModel.getWalletName(addResult.walletId!),
                        maxLength: 15)), onConfirm: () {
              _isProcessing = false;
              Navigator.pop(context);
            });
          }
      }
    } catch (e) {
      vibrateLightDouble();
      if (mounted) {
        CustomDialogs.showCustomAlertDialog(context,
            title: t.alert.wallet_add.add_failed, message: e.toString(), onConfirm: () {
          _isProcessing = false;
          Navigator.pop(context);
        });
      }
      // TODO:
      rethrow;
    } finally {
      vibrateMedium();
      if (mounted) {
        context.loaderOverlay.hide();
      }
    }
  }

  // TODO:
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
      errorMessage = t.alert.scan_failed_description(error: message);
    }

    CustomDialogs.showCustomAlertDialog(context, title: t.alert.scan_failed, message: errorMessage,
        onConfirm: () {
      _isProcessing = false;
      Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
