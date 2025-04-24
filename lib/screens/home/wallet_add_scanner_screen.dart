import 'dart:convert';
import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class WalletAddScannerScreen extends StatefulWidget {
  final WalletImportSource walletImportSource;
  const WalletAddScannerScreen({
    super.key,
    required this.walletImportSource,
  });

  @override
  State<WalletAddScannerScreen> createState() => _WalletAddScannerScreenState();
}

class _WalletAddScannerScreenState extends State<WalletAddScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;
  bool _isProcessing = false;

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

  List<TextSpan> _getGuideTextSpan() {
    switch (widget.walletImportSource) {
      case WalletImportSource.coconutVault:
        {
          return [
            TextSpan(
              text: t.wallet_add_scanner_screen.guide_vault,
            ),
          ];
        }
      case WalletImportSource.seedSigner:
        {
          return [
            TextSpan(text: t.wallet_add_scanner_screen.guide_keystone.step1),
            _em(t.wallet_add_scanner_screen.guide_keystone.step1_em),
            TextSpan(text: t.wallet_add_scanner_screen.select),
            const TextSpan(text: '\n'),
            TextSpan(text: t.wallet_add_scanner_screen.guide_keystone.step2),
            _em(t.wallet_add_scanner_screen.guide_keystone.step2_em),
            TextSpan(text: t.wallet_add_scanner_screen.select),
            const TextSpan(text: '\n'),
            TextSpan(text: t.wallet_add_scanner_screen.guide_keystone.step3),
            _em(t.wallet_add_scanner_screen.guide_keystone.step3_em),
            TextSpan(text: t.wallet_add_scanner_screen.select),
            const TextSpan(text: '\n'),
            TextSpan(text: t.wallet_add_scanner_screen.guide_keystone.step4),
            _em(t.wallet_add_scanner_screen.guide_keystone.step4_em1),
            TextSpan(text: t.wallet_add_scanner_screen.guide_keystone.next),
            _em(t.wallet_add_scanner_screen.guide_keystone.step4_em2),
            TextSpan(text: t.wallet_add_scanner_screen.select),
            const TextSpan(text: '\n'),
            TextSpan(text: t.wallet_add_scanner_screen.guide_keystone.step5),
            _em(t.wallet_add_scanner_screen.guide_keystone.step5_em),
            const TextSpan(text: '\n'),
            TextSpan(text: t.wallet_add_scanner_screen.guide_keystone.step6),
            _em(t.wallet_add_scanner_screen.guide_keystone.step6_em),
            TextSpan(text: t.wallet_add_scanner_screen.guide_keystone.step6_end),
          ];
        }
      case WalletImportSource.keystone:
        {
          return [
            TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.step1),
            _em(t.wallet_add_scanner_screen.guide_seedsigner.step1_em),
            TextSpan(text: t.wallet_add_scanner_screen.select),
            const TextSpan(text: '\n'),
            TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.step2),
            _em(t.wallet_add_scanner_screen.guide_seedsigner.step2_em),
            TextSpan(text: t.wallet_add_scanner_screen.select),
            const TextSpan(text: '\n'),
            TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.step3),
          ];
        }
      default:
        return [];
    }
  }

  TextSpan _em(String text) => TextSpan(
        text: text,
        style: CoconutTypography.body3_12_Bold,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CoconutAppBar.build(
        title: _getAppBarTitle(),
        context: context,
        isBottom: true,
        backgroundColor: CoconutColors.black.withOpacity(0.95),
        actionButtonList: [
          IconButton(
            onPressed: () {
              if (controller != null) {
                controller!.flipCamera();
              }
            },
            icon: const Icon(CupertinoIcons.camera_rotate, size: 22),
            color: CoconutColors.white,
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            color: CoconutColors.black,
            child: Column(
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: QRView(
                    key: qrKey,
                    onQRViewCreated: _onQRViewCreated,
                    overlay: QrScannerOverlayShape(
                        borderColor: CoconutColors.white,
                        borderRadius: 8,
                        borderLength: (MediaQuery.of(context).size.width < 400 ||
                                MediaQuery.of(context).size.height < 400)
                            ? 160.0
                            : MediaQuery.of(context).size.width * 0.9 / 2,
                        borderWidth: 8,
                        cutOutSize: (MediaQuery.of(context).size.width < 400 ||
                                MediaQuery.of(context).size.height < 400)
                            ? 320.0
                            : MediaQuery.of(context).size.width * 0.9),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
                top: 20, left: CoconutLayout.defaultPadding, right: CoconutLayout.defaultPadding),
            child: CoconutToolTip(
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
            ),
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() => switch (widget.walletImportSource) {
        WalletImportSource.coconutVault => t.wallet_add_scanner_screen.vault,
        WalletImportSource.keystone => t.wallet_add_scanner_screen.keystone,
        WalletImportSource.seedSigner => t.wallet_add_scanner_screen.seed_signer,
        _ => '',
      };

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (_isProcessing || scanData.code == null) return;
      _isProcessing = true;

      if (!mounted) return;

      context.loaderOverlay.show();
      final model = Provider.of<WalletProvider>(context, listen: false);
      WatchOnlyWallet watchOnlyWallet;
      try {
        // 2. 유효한 데이터인지 확인 (WalletSyncObject)
        Map<String, dynamic> jsonData = jsonDecode(scanData.code!);
        watchOnlyWallet = WatchOnlyWallet.fromJson(jsonData);

        model.syncFromVault(watchOnlyWallet).then((ResultOfSyncFromVault value) {
          if (!mounted) return;
          switch (value.result) {
            case WalletSyncResult.newWalletAdded:
            case WalletSyncResult.existingWalletUpdated:
              {
                Navigator.pop(context, value);
                break;
              }
            case WalletSyncResult.existingWalletNoUpdate:
              {
                vibrateLightDouble();
                CustomDialogs.showCustomAlertDialog(context,
                    title: t.alert.wallet_add.update_failed,
                    message: t.alert.wallet_add.update_failed_description(
                        name: TextUtils.ellipsisIfLonger(
                      model.getWalletById(value.walletId!).name,
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
          }
        }).catchError((error) {
          vibrateLightDouble();
          if (mounted) {
            CustomDialogs.showCustomAlertDialog(context,
                title: t.alert.wallet_add.add_failed, message: error.toString(), onConfirm: () {
              _isProcessing = false;
              Navigator.pop(context);
            });
          }
        }).whenComplete(() {
          vibrateMedium();
          if (mounted) {
            context.loaderOverlay.hide();
          }
        });
      } catch (error) {
        vibrateLightDouble();
        context.loaderOverlay.hide();
        Logger.log('Exception while QR Processing : $error');
        CustomDialogs.showCustomAlertDialog(context,
            title: t.alert.wallet_add.add_failed,
            message: t.alert.wallet_add.add_failed_description, onConfirm: () {
          _isProcessing = false;
          Navigator.pop(context);
        });
        rethrow;
      }
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
