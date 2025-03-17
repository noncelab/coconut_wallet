import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/send_address_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/body/send_address/send_address_body.dart';
import 'package:coconut_wallet/widgets/body/send_address/send_address_amount_body_for_batch.dart';
import 'package:coconut_wallet/widgets/overlays/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
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
  bool _isBatchMode = false;

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
        return GestureDetector(
          onTap: _isBatchMode
              ? () {
                  FocusScope.of(context).unfocus(); // 현재 포커스를 해제 (키보드 내리기)
                }
              : null,
          child: Scaffold(
              backgroundColor: MyColors.black,
              appBar: CoconutAppBar.build(
                  title: t.send,
                  context: context,
                  actionButtonList: [
                    Padding(
                      padding: const EdgeInsets.all(2),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: IconButton(
                          icon: SvgPicture.asset(_isBatchMode
                              ? 'assets/svg/user.svg'
                              : 'assets/svg/users-group.svg'),
                          onPressed: _changeIsBatchMode,
                          padding: const EdgeInsets.all(0),
                        ),
                      ),
                    ),
                    CoconutLayout.spacing_200w,
                    Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: IconButton(
                          iconSize: 24,
                          icon: SvgPicture.asset('assets/svg/arrow-reload.svg',
                              colorFilter: ColorFilter.mode(
                                _isBatchMode
                                    ? CoconutColors.gray800
                                    : CoconutColors.white,
                                BlendMode.srcIn,
                              )),
                          onPressed: _isBatchMode
                              ? null
                              : () {
                                  if (controller != null) {
                                    controller!.flipCamera();
                                  }
                                },
                          padding: const EdgeInsets.all(0),
                        ),
                      ),
                    )
                  ],
                  onBackPressed: () {
                    _stopCamera();
                    controller = null;
                    Navigator.of(context).pop();
                  }),
              body: !_isBatchMode
                  ? SendAddressBody(
                      qrKey: qrKey,
                      onQRViewCreated: _onQRViewCreated,
                      address: viewModel.address,
                      pasteAddress: _setClipboardAddressAsRecipient,
                    )
                  : SendAddressAmountBodyForBatch(
                      validateAddress: _viewModel.validateAddress,
                      checkSendAvailable: (int totalSendAmount) => viewModel
                          .isSendAmountValid(widget.id, totalSendAmount),
                      onRecipientsConfirmed: _onRecipientsConfirmed)),
        );
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
        Provider.of<ConnectivityProvider>(context, listen: false).isNetworkOn,
        Provider.of<WalletProvider>(context, listen: false));
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

  /// --- batch transaction
  void _changeIsBatchMode() {
    _viewModel.clearSendInfoProvider();
    setState(() {
      _isBatchMode = !_isBatchMode;
    });
  }

  void _onRecipientsConfirmed(Map<String, double> recipients) {
    _viewModel.saveWalletIdAndBatchRecipients(widget.id, recipients);
    if (_viewModel.isNetworkOn) {
      Navigator.pushNamed(context, "/fee-selection");
    } else {
      CustomToast.showWarningToast(
          context: context, text: ErrorCodes.networkError.message);
    }
  }
}
