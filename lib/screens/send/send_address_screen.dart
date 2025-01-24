import 'dart:io';

import 'package:coconut_wallet/model/app/error/app_error.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/send_address_view_model.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  late SendAddressViewModel _viewModel;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<ConnectivityProvider,
        SendAddressViewModel>(
      create: (_) => _viewModel,
      update: (_, connectivityProvider, viewModel) {
        Logger.log(
            '--> connectivityProvider: ${connectivityProvider.isNetworkOn}');
        if (connectivityProvider.isNetworkOn != viewModel!.isNetworkOn) {
          viewModel.setIsNetworkOn(connectivityProvider.isNetworkOn);
        }
        return viewModel;
      },
      child:
          Consumer<SendAddressViewModel>(builder: (context, viewModel, child) {
        return Scaffold(
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
                Navigator.of(context).pop();
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
              Positioned(
                  top: kToolbarHeight - 75,
                  left: 0,
                  right: 0,
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
                          onPressed: () => _setClipboardAddressAsRecipient(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: viewModel.address != null
                                ? MyColors.darkgrey
                                : MyColors.white,
                            backgroundColor: viewModel.address != null
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
                          child: viewModel.address != null
                              ? Text.rich(TextSpan(
                                  text: '주소 ',
                                  style: Styles.label.merge(const TextStyle(
                                      color: MyColors.darkgrey)),
                                  children: [
                                      TextSpan(
                                          text:
                                              '${viewModel.address?.substring(0, 10)}...${viewModel.address?.substring(35)}',
                                          style: TextStyle(
                                              fontFamily: CustomFonts
                                                  .number.getFontFamily,
                                              fontWeight: FontWeight.bold)),
                                      const TextSpan(text: ' 붙여넣기')
                                    ]))
                              : Text('붙여넣기',
                                  style: Styles.label.merge(const TextStyle(
                                      color: MyColors.transparentWhite_20))))))
            ]));
      }),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _viewModel = SendAddressViewModel(
        Provider.of<SendInfoProvider>(context, listen: false),
        Provider.of<ConnectivityProvider>(context, listen: false).isNetworkOn);
    _viewModel.clearSendInfoProvider();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.loadDataFromClipboardIfValid();
    });
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

  void _goNext() async {
    await _stopCamera();

    if (!mounted) return;
    if (Platform.isAndroid) {
      Navigator.pushReplacementNamed(context, "/send-amount").then((o) {
        _isProcessing = false;
      });
    } else if (Platform.isIOS) {
      Navigator.pushNamed(context, "/send-amount").then((o) {
        _isProcessing = false;
      }).then((_) {
        controller?.resumeCamera();
      });
    }
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
      if (scanData.code!.isEmpty) return;

      _isProcessing = true;

      _viewModel.validateAddress(scanData.code!).then((_) {
        _viewModel.saveWalletIdAndRecipientAddress(widget.id, scanData.code!);
        if (_viewModel.isNetworkOn) {
          _goNext();
        } else {
          CustomToast.showWarningToast(
              context: context, text: ErrorCodes.networkError.message);
          _isProcessing = false;
        }
      }).catchError((e) {
        CustomToast.showToast(context: context, text: e.toString());
        _isProcessing = false;
      });
    });
  }

  Future<void> _setClipboardAddressAsRecipient() async {
    if (_viewModel.address == null) return;

    if (_viewModel.isNetworkOn) {
      _viewModel.saveWalletIdAndRecipientAddress(
          widget.id, _viewModel.address!);
      _goNext();
    } else {
      CustomToast.showWarningToast(
          context: context, text: ErrorCodes.networkError.message);
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
}
