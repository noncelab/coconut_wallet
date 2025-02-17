import 'dart:convert';
import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../../widgets/appbar/custom_appbar.dart';

class WalletAddScannerScreen extends StatefulWidget {
  const WalletAddScannerScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: CustomAppBar.build(
          title: t.wallet_add_scanner_screen.text,
          context: context,
          hasRightIcon: true,
          isBottom: true,
          backgroundColor: MyColors.black.withOpacity(0.95),
          rightIconButton: IconButton(
            onPressed: () {
              if (controller != null) {
                controller!.flipCamera();
              }
            },
            icon: const Icon(CupertinoIcons.camera_rotate, size: 20),
            color: MyColors.white,
          ),
          showTestnetLabel: false,
        ),
        body: Stack(children: [
          Container(
            color: MyColors.black,
            child: Column(
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: QRView(
                    key: qrKey,
                    onQRViewCreated: _onQRViewCreated,
                    overlay: QrScannerOverlayShape(
                        borderColor: MyColors.white,
                        borderRadius: 8,
                        borderLength:
                            (MediaQuery.of(context).size.width < 400 ||
                                    MediaQuery.of(context).size.height < 400)
                                ? 160.0
                                : MediaQuery.of(context).size.width * 0.9 / 2,
                        borderWidth: 8,
                        cutOutSize: (MediaQuery.of(context).size.width < 400 ||
                                MediaQuery.of(context).size.height < 400)
                            ? 320.0
                            : MediaQuery.of(context).size.width * 0.9),
                    onPermissionSet: (ctrl, p) =>
                        _onPermissionSet(context, ctrl, p),
                  ),
                ),
              ],
            ),
          ),
          Padding(
              padding: const EdgeInsets.only(
                top: 20,
                left: 16,
                right: 16,
              ),
              child: Stack(children: [
                CoconutToolTip(
                    brightness: Brightness.dark,
                    tooltipType: CoconutTooltipType.fixed,
                    backgroundColor:
                        CoconutColors.colorPalette[4].withOpacity(0.18),
                    baseBackgroundColor: CoconutColors.white,
                    richText: RichText(
                      text: TextSpan(
                        text: t.tooltip.wallet_add1,
                        style: CoconutTypography.body2_14.setColor(
                          CoconutColors.black,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: t.tooltip.wallet_add2,
                            style: CoconutTypography.body2_14_Bold.setColor(
                              CoconutColors.black,
                            ),
                          ),
                          TextSpan(
                            text: t.tooltip.wallet_add3,
                            style: CoconutTypography.body2_14.setColor(
                              CoconutColors.black,
                            ),
                          ),
                          TextSpan(
                            text: t.tooltip.wallet_add4,
                            style: CoconutTypography.body2_14_Bold.setColor(
                              CoconutColors.black,
                            ),
                          ),
                          TextSpan(
                            text: t.tooltip.wallet_add5,
                            style: CoconutTypography.body2_14.setColor(
                              CoconutColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    showIcon: true,
                    borderColor: CoconutColors.colorPalette[4],
                    tooltipState: CoconutTooltipState.info),
              ])),
        ]));
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    Logger.log('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.snackbar.no_permission)),
      );
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (_isProcessing || scanData.code == null) return;
      _isProcessing = true;
      context.loaderOverlay.show();

      final model = Provider.of<WalletProvider>(context, listen: false);
      WatchOnlyWallet watchOnlyWallet;
      try {
        // 2. 유효한 데이터인지 확인 (WalletSyncObject)
        Map<String, dynamic> jsonData = jsonDecode(scanData.code!);
        watchOnlyWallet = WatchOnlyWallet.fromJson(jsonData);

        model
            .syncFromVault(watchOnlyWallet)
            .then((ResultOfSyncFromVault value) {
          switch (value.result) {
            case WalletSyncResult.newWalletAdded:
            case WalletSyncResult.existingWalletUpdated:
              {
                Navigator.pop(context, value);
                break;
              }
            case WalletSyncResult.existingWalletNoUpdate:
              {
                CustomDialogs.showCustomDialog(
                  context,
                  title: t.alert.wallet_add.update_failed,
                  description: t.alert.wallet_add.update_failed_description(
                    name: TextUtils.ellipsisIfLonger(
                      model.getWalletById(value.walletId!).name,
                      maxLength: 15,
                    ),
                  ),
                  rightButtonColor: CoconutColors.white,
                  onTapRight: () {
                    _isProcessing = false;
                    Navigator.pop(context);
                  },
                );

                break;
              }
            case WalletSyncResult.existingName:
              vibrateLightDouble();
              CustomDialogs.showCustomDialog(
                context,
                title: t.alert.wallet_add.duplicate_name,
                description: t.alert.wallet_add.duplicate_name_description,
                rightButtonColor: CoconutColors.white,
                onTapRight: () {
                  _isProcessing = false;
                  Navigator.pop(context);
                },
              );
          }
        }).catchError((error) {
          vibrateLightDouble();
          CustomDialogs.showCustomDialog(
            context,
            title: t.alert.wallet_add.add_failed,
            description: error.toString(),
            rightButtonColor: CoconutColors.white,
            onTapRight: () {
              _isProcessing = false;
              Navigator.pop(context);
            },
          );
        }).whenComplete(() {
          vibrateMedium();
          context.loaderOverlay.hide();
        });
      } catch (error) {
        vibrateLightDouble();
        context.loaderOverlay.hide();
        Logger.log('Exception while QR Processing : $error');
        CustomDialogs.showCustomDialog(
          context,
          title: t.alert.wallet_add.add_failed,
          description: t.alert.wallet_add.add_failed_description,
          rightButtonColor: CoconutColors.white,
          onTapRight: () {
            _isProcessing = false;
            Navigator.pop(context);
          },
        );
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
