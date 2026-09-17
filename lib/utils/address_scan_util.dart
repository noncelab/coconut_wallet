import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/features/qr/body/address_qr_scanner_body.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

Future<String?> showAddressScannerBottomSheet(BuildContext context, {required String title}) async {
  MobileScannerController? qrViewController;
  bool isQrDataHandling = false;
  final qrKey = GlobalKey(debugLabel: 'QR');

  void onDetect(BarcodeCapture capture) {
    final codes = capture.barcodes;
    if (codes.isEmpty) return;

    final rawValue = codes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty || isQrDataHandling) return;

    isQrDataHandling = true;
    Navigator.pop(context, rawValue);
  }

  final scannedData = await CommonBottomSheets.showBottomSheet_100<String?>(
    context: context,
    screenName: AnalyticsScreenNames.addressScanQrSheet,
    backgroundColor: Colors.transparent,
    child: Builder(
      builder:
          (sheetContext) => ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            child: Material(
              color: sheetContext.coconutColors.surfaceBottomSheet,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                extendBodyBehindAppBar: true,
                // 앱바까지 투명하게 만든 후 아이콘, 화면 이름은 가독성을 위해 white로 색 고정
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  surfaceTintColor: Colors.transparent,
                  centerTitle: true,
                  leading: IconButton(
                    icon: SvgPicture.asset(
                      CommonNavigationIconPath.arrowBack,
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                    onPressed: () {
                      qrViewController = null;
                      isQrDataHandling = false;
                      Navigator.of(sheetContext).pop<String?>(null);
                    },
                  ),
                  title: title.isEmpty ? null : Text(title, style: CoconutTypography.body1_16.setColor(Colors.white)),
                  actions: [
                    IconButton(
                      icon: SvgPicture.asset(
                        CommonActionIconPath.arrowReload,
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                      onPressed: () {
                        qrViewController?.switchCamera();
                      },
                    ),
                  ],
                ),
                body: AddressQrScannerBody(
                  qrKey: qrKey,
                  onDetect: onDetect,
                  setMobileScannerController: (controller) {
                    qrViewController = controller;
                  },
                ),
              ),
            ),
          ),
    ),
  );

  qrViewController = null;
  isQrDataHandling = false;
  return scannedData;
}
