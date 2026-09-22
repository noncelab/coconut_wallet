import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/utils/app_settings_util.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:coconut_wallet/widgets/features/qr/qr_scanner_view.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

class AddressQrScannerBody extends StatefulWidget {
  final Key qrKey;
  final void Function(BarcodeCapture) onDetect;
  final String? address;
  final Function(MobileScannerController)? setMobileScannerController;

  const AddressQrScannerBody({
    super.key,
    required this.qrKey,
    required this.onDetect,
    this.address,
    this.setMobileScannerController,
  });

  @override
  State<AddressQrScannerBody> createState() => _AddressQrScannerBodyState();
}

class _AddressQrScannerBodyState extends State<AddressQrScannerBody> {
  late final MobileScannerController _controller;
  bool _isShowedCameraPermissionDialog = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
    widget.setMobileScannerController?.call(_controller);
  }

  Widget _buildQrView(BuildContext context) {
    // 스캔 영역을 상단으로 이동 (상단 여백 120px 추가)
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isFoldScreen = MediaQuery.of(context).size.width > 600;
    final topMargin = statusBarHeight + (isFoldScreen ? 0 : 100.0);
    return QrScannerView(
      scannerKey: widget.qrKey,
      controller: _controller,
      onDetect: widget.onDetect,
      errorBuilder: (context, error) {
        if (error.errorCode == MobileScannerErrorCode.permissionDenied && !_isShowedCameraPermissionDialog) {
          _isShowedCameraPermissionDialog = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await _showCameraPermissionDialog(context);
            if (!context.mounted) return;
            Navigator.pop(context);
          });
        }
        return Center(child: Text(error.errorCode.message));
      },
      overlayBuilder:
          (context, scanWindow) => Positioned(
            top: topMargin,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 32),
              child: Text(
                t.send_address_screen.text2,
                textAlign: TextAlign.center,
                style: CoconutTypography.body1_16.setColor(CoconutColors.white),
              ),
            ),
          ),
    );
  }

  Future<void> _showCameraPermissionDialog(BuildContext context) async {
    await showConfirmDialog(
      context,
      context.read<PreferenceProvider>().language,
      t.coconut_qr_scanner.camera_error.title,
      t.coconut_qr_scanner.camera_error.need_camera_permission,
      rightButtonText: t.go_to_settings,
      onTapRight: () {
        openAppSettings();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildQrView(context);
  }
}
