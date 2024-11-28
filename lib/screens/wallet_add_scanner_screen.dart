import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/model/enums.dart';
import 'package:coconut_wallet/model/wallet_sync.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/custom_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../widgets/appbar/custom_appbar.dart';

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
          title: '보기 전용 지갑 추가',
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
              padding: const EdgeInsets.only(top: 20),
              child: CustomTooltip(
                  backgroundColor: MyColors.white.withOpacity(0.9),
                  richText: RichText(
                    text: const TextSpan(
                      text: '새로운 지갑을 추가하거나 이미 추가한 지갑의 정보를 업데이트할 수 있어요. ',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.normal,
                        fontSize: 15,
                        height: 1.4,
                        letterSpacing: 0.5,
                        color: MyColors.black,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: '볼트',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: '에서 사용하시려는 지갑을 선택하고, ',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        TextSpan(
                          text: '내보내기 ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: '화면에 나타나는 QR 코드를 스캔해 주세요.',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  showIcon: true,
                  type: TooltipType.info)),
        ]));
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    Logger.log('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('no Permission')),
      );
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (_isProcessing || scanData.code == null) return;
      _isProcessing = true;
      context.loaderOverlay.show();

      final model = Provider.of<AppStateModel>(context, listen: false);
      WalletSync syncObject;
      try {
        // 2. 유효한 데이터인지 확인 (WalletSyncObject)
        Map<String, dynamic> jsonData = jsonDecode(scanData.code!);
        syncObject = WalletSync.fromJson(jsonData);

        model.syncFromVault(syncObject).then((value) {
          switch (value.result) {
            case SyncResult.newWalletAdded:
              {
                {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/', (Route<dynamic> route) => false);
                  break;
                }
              }
            case SyncResult.existingWalletNoUpdate:
              {
                Navigator.pushReplacementNamed(context, '/wallet-detail',
                    arguments: {
                      'id': value.walletId,
                      'syncResult': value.result,
                    });
                break;
              }
            case SyncResult.existingWalletUpdated:
              {
                Navigator.pushReplacementNamed(context, '/wallet-detail',
                    arguments: {
                      'id': value.walletId,
                      'syncResult': value.result,
                    });
                break;
              }
            case SyncResult.existingName:
              vibrateLightDouble();
              CustomDialogs.showCustomAlertDialog(context,
                  title: '이름 중복',
                  message: "같은 이름을 가진 지갑이 있습니다.\n이름을 변경한 후 동기화 해주세요.",
                  onConfirm: () {
                Navigator.pop(context);
              });
          }
        }).catchError((error) {
          vibrateLightDouble();

          CustomDialogs.showCustomAlertDialog(context,
              title: '보기 전용 지갑 추가 실패',
              message: error.toString(), onConfirm: () {
            _isProcessing = false;
            Navigator.pop(context);
          });
        }).whenComplete(() {
          vibrateMedium();
          context.loaderOverlay.hide();
        });
      } catch (error) {
        vibrateLightDouble();
        context.loaderOverlay.hide();
        Logger.log('Exception while QR Processing : $error');
        CustomDialogs.showCustomAlertDialog(context,
            title: '보기 전용 지갑 추가 실패', message: "잘못된 지갑 정보입니다.", onConfirm: () {
          _isProcessing = false;
          Navigator.pop(context);
        });
      }
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
