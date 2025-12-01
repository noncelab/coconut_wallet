import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/overlays/scanner_overlay.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class AddressQrScannerBody extends StatelessWidget {
  final Key qrKey;
  final void Function(BarcodeCapture) onDetect;
  final String? address;

  const AddressQrScannerBody({super.key, required this.qrKey, required this.onDetect, this.address});

  Widget _buildQrView(BuildContext context) {
    // 스캔 영역을 상단으로 이동 (상단 여백 120px 추가)
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isFoldScreen = MediaQuery.of(context).size.width > 600;
    final topMargin = statusBarHeight + (isFoldScreen ? 0 : 120.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size layoutSize = constraints.biggest;

        // ScannerOverlay와 동일한 크기의 정사각형 스캔 영역 계산
        final scanAreaSize = (layoutSize.width < 400 || layoutSize.height < 400) ? 320.0 : layoutSize.width * 0.85;

        final Rect scanWindow = Rect.fromCenter(
          center: layoutSize.center(Offset.zero),
          width: scanAreaSize,
          height: scanAreaSize,
        );

        return Stack(
          children: [
            MobileScanner(key: qrKey, onDetect: onDetect, scanWindow: scanWindow),
            const ScannerOverlay(),
            Positioned(
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
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildQrView(context);
    // return Stack(
    //   children: [
    //     Positioned(
    //       left: 0,
    //       right: 0,
    //       // Adjust this value to move the QRView up or down
    //       height:
    //           MediaQuery.of(context).size.height +
    //           MediaQuery.of(context).padding.top +
    //           MediaQuery.of(context).padding.bottom,
    //       child: _buildQrView(context),
    //     ),
    //     Positioned(
    //       top: 0,
    //       left: 0,
    //       right: 0,
    //       child: Container(
    //         padding: const EdgeInsets.only(top: 32),
    //         child: Text(
    //           pasteAddress != null ? t.send_address_screen.text1 : t.send_address_screen.text2,
    //           textAlign: TextAlign.center,
    //           style: CoconutTypography.body1_16.setColor(CoconutColors.white),
    //         ),
    //       ),
    //     ),
    //     if (pasteAddress != null)
    //       Align(
    //         alignment: Alignment.bottomCenter,
    //         child: Container(
    //           padding: const EdgeInsets.fromLTRB(16, 0, 16, 60),
    //           child: TextButton(
    //             onPressed: pasteAddress,
    //             style: OutlinedButton.styleFrom(
    //               foregroundColor: address != null ? MyColors.darkgrey : CoconutColors.white,
    //               backgroundColor:
    //                   address != null ? CoconutColors.white : MyColors.transparentBlack_50,
    //               padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
    //               shape: const RoundedRectangleBorder(
    //                 borderRadius: BorderRadius.all(Radius.circular(8)),
    //               ),
    //             ),
    //             child:
    //                 address != null
    //                     ? Text.rich(
    //                       TextSpan(
    //                         text: '${t.address} ',
    //                         style: Styles.label.merge(const TextStyle(color: MyColors.darkgrey)),
    //                         children: [
    //                           TextSpan(
    //                             text: shortenAddress(address!),
    //                             style: TextStyle(
    //                               fontFamily: CustomFonts.number.getFontFamily,
    //                               fontWeight: FontWeight.bold,
    //                             ),
    //                           ),
    //                           TextSpan(text: ' ${t.paste}'),
    //                         ],
    //                       ),
    //                     )
    //                     : Text(
    //                       t.paste,
    //                       style: Styles.label.merge(
    //                         const TextStyle(color: MyColors.transparentWhite_20),
    //                       ),
    //                     ),
    //           ),
    //         ),
    //       ),
    //   ],
    // );
  }
}
