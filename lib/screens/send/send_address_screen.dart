import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:coconut_wallet/model/app_error.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class SendAddressScreen extends StatefulWidget {
  final int id;

  const SendAddressScreen({super.key, required this.id});

  @override
  State<SendAddressScreen> createState() => _SendAddressScreenState();
}

class _SendAddressScreenState extends State<SendAddressScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;
  bool _isProcessing = false;
  String? _address;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    Future.delayed(Duration.zero, () async {
      ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      final clipboardText = data?.text ?? '';
      setState(() {
        if (clipboardText.isNotEmpty &&
            BitcoinNetwork.currentNetwork == BitcoinNetwork.regtest &&
            clipboardText.startsWith('bcrt1') &&
            WalletUtility.validateAddress(clipboardText)) {
          _address = clipboardText;
        } else {
          _address = null;
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant SendAddressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 현재의 라우트 경로를 가져옴
    String? currentRoute = ModalRoute.of(context)?.settings.name;

    if (currentRoute != null && currentRoute.startsWith('/send-address')) {
      _isProcessing = false;
      controller?.resumeCamera();
    }
  }

  Future<void> _stopCamera() async {
    if (controller != null) {
      try {
        await controller?.pauseCamera();
        Logger.log('Camera paused successfully');
      } catch (e) {
        Logger.log('Failed to pause camera: $e');
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
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
            title: '보내기',
            context: context,
            hasRightIcon: true,
            rightIconButton: IconButton(
              onPressed: () {
                if (controller != null) {
                  controller!.flipCamera();
                }
              },
              icon: const Icon(CupertinoIcons.camera_rotate, size: 20),
              color: MyColors.white,
            ),
            onBackPressed: () {
              _stopCamera();
              controller = null;
            },
            backgroundColor: MyColors.black.withOpacity(0.95),
          ),
          body: Stack(children: [
            Positioned(
                left: 0,
                right: 0,
                top: -110, // Adjust this value to move the QRView up or down
                height: MediaQuery.of(context).size.height +
                    MediaQuery.of(context).padding.top +
                    MediaQuery.of(context).padding.bottom,
                child: _buildQrView(context)),
            Align(
                alignment: Alignment.topCenter,
                child: Container(
                    padding: const EdgeInsets.only(top: 32),
                    child: Text(
                      'QR을 스캔하거나\n복사한 주소를 붙여넣어 주세요',
                      textAlign: TextAlign.center,
                      style: Styles.label
                          .merge(const TextStyle(color: MyColors.white)),
                    ))),
            Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 60),
                    child: TextButton(
                        onPressed: _getClipboardText,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _address != null
                              ? MyColors.darkgrey
                              : MyColors.white,
                          backgroundColor: _address != null
                              ? MyColors.white
                              : MyColors.transparentBlack_50,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 20),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(8),
                            ),
                          ),
                        ),
                        child: _address != null
                            ? Text.rich(TextSpan(
                                text: '주소 ',
                                style: Styles.label.merge(
                                    const TextStyle(color: MyColors.darkgrey)),
                                children: [
                                    TextSpan(
                                        text:
                                            '${_address?.substring(0, 10)}...${_address?.substring(35)}',
                                        style: TextStyle(
                                            fontFamily: CustomFonts
                                                .number.getFontFamily,
                                            fontWeight: FontWeight.bold)),
                                    const TextSpan(text: ' 붙여넣기')
                                  ]))
                            : Text('붙여넣기',
                                style: Styles.label.merge(const TextStyle(
                                    color: MyColors.transparentWhite_20))))))
          ])),
    );
  }

  Widget _buildQrView(BuildContext context) {
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
          borderColor: MyColors.white,
          borderRadius: 8,
          borderLength: (MediaQuery.of(context).size.width < 400 ||
                  MediaQuery.of(context).size.height < 400)
              ? 160
              : MediaQuery.of(context).size.width * 0.9 / 2,
          borderWidth: 8,
          cutOutSize: (MediaQuery.of(context).size.width < 400 ||
                  MediaQuery.of(context).size.height < 400)
              ? 320.0
              : MediaQuery.of(context).size.width * 0.9),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  Future<void> _getClipboardText() async {
    if (_address == null) return;

    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    _validateAddress(data?.text);
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

      _validateAddress(scanData.code);
    });
  }

  void _validateAddress(String? recipient) async {
    if (recipient == null || (recipient.isEmpty || recipient.length < 26)) {
      Fluttertoast.showToast(
          msg: "올바른 주소가 아니에요",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: MyColors.warningRed,
          textColor: Colors.white,
          fontSize: 16.0);
      _isProcessing = false;
      return;
    }

    if (BitcoinNetwork.currentNetwork == BitcoinNetwork.testnet) {
      if (recipient.startsWith('1') ||
          recipient.startsWith('3') ||
          recipient.startsWith('bc1')) {
        Fluttertoast.showToast(
          msg: "테스트넷 주소가 아니에요",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.white,
          textColor: MyColors.darkgrey,
          fontSize: 16.0,
        );
        _isProcessing = false;
        return;
      }
    } else if (BitcoinNetwork.currentNetwork == BitcoinNetwork.mainnet) {
      if (recipient.startsWith('m') ||
          recipient.startsWith('n') ||
          recipient.startsWith('2') ||
          recipient.startsWith('tb1')) {
        Fluttertoast.showToast(
          msg: "메인넷 주소가 아니에요",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.white,
          textColor: MyColors.darkgrey,
          fontSize: 16.0,
        );
        _isProcessing = false;
        return;
      }
    } else if (BitcoinNetwork.currentNetwork == BitcoinNetwork.regtest) {
      if (!recipient.startsWith('bcrt1')) {
        Fluttertoast.showToast(
          msg: "레그테스트넷 주소가 아니에요",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.white,
          textColor: MyColors.darkgrey,
          fontSize: 16.0,
        );
        _isProcessing = false;
        return;
      }
    }

    bool result = false;
    try {
      result = WalletUtility.validateAddress(recipient);
    } catch (e) {
      Fluttertoast.showToast(
        msg: "올바른 주소가 아니에요 ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.white,
        textColor: MyColors.darkgrey,
        fontSize: 16.0,
      );
      _isProcessing = false;
      return;
    }

    if (!result) {
      // showAlertDialog(context: context, content: "유효하지 않은 주소입니다.", onClosed: () => _isProcessing = false);
      Fluttertoast.showToast(
        msg: "올바른 주소가 아니에요",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.white,
        textColor: MyColors.darkgrey,
        fontSize: 16.0,
      );
      _isProcessing = false;
      return;
    }

    // 올바른 주소여서 다음 화면으로 넘어가기 전에 네트워크 상태 확인하기
    var appState = Provider.of<AppStateModel>(context, listen: false);
    if (appState.isNetworkOn == false) {
      CustomToast.showWarningToast(
          context: context, text: ErrorCodes.networkError.message);
      _isProcessing = false;
      return;
    }
    controller?.pauseCamera();
    await _stopCamera();
    if (mounted) {
      /// Go-router 제거 이후로 ios에서는 정상 작동하지만 안드로이드에서는 pushNamed로 화면 이동 시 카메라 컨트롤러 남아있는 이슈
      if (Platform.isAndroid) {
        Navigator.pushReplacementNamed(context, "/send-amount",
            arguments: {'id': widget.id, 'recipient': recipient}).then((o) {
          _isProcessing = false;
        });
      } else if (Platform.isIOS) {
        Navigator.pushNamed(context, "/send-amount",
            arguments: {'id': widget.id, 'recipient': recipient}).then((o) {
          _isProcessing = false;
        });
      }
    }
  }
}
