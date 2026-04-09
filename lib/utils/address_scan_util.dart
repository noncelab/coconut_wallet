import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/widgets/body/address_qr_scanner_body.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Future<String?> showAddressScannerBottomSheet(
  BuildContext context, {
  required String title,
}) async {
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
    child: Builder(
      builder:
          (sheetContext) => Scaffold(
            backgroundColor: CoconutColors.black,
            appBar: CoconutAppBar.build(
              title: title,
              context: sheetContext,
              actionButtonList: [
                IconButton(
                  icon: SvgPicture.asset('assets/svg/arrow-reload.svg', width: 20, height: 20),
                  color: CoconutColors.white,
                  onPressed: () {
                    qrViewController?.switchCamera();
                  },
                ),
              ],
              onBackPressed: () {
                qrViewController = null;
                isQrDataHandling = false;
                Navigator.of(sheetContext).pop<String?>(null);
              },
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
  );

  qrViewController = null;
  isQrDataHandling = false;
  return scannedData;
}
