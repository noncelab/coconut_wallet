import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class AddressQrScannerBody extends StatelessWidget {
  final Key qrKey;
  final void Function(BarcodeCapture) onDetect;
  final String? address;
  final void Function()? pasteAddress;

  const AddressQrScannerBody(
      {super.key, required this.qrKey, required this.onDetect, this.address, this.pasteAddress});

  Widget _buildQrView(BuildContext context) {
    return Stack(children: [
      MobileScanner(
        key: qrKey,
        onDetect: onDetect,
      ),
      _buildOverlay(context),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned(
          left: 0,
          right: 0,
          top: -110,
          // Adjust this value to move the QRView up or down
          height: MediaQuery.of(context).size.height +
              MediaQuery.of(context).padding.top +
              MediaQuery.of(context).padding.bottom,
          child: _buildQrView(context)),
      Positioned(
          top: kToolbarHeight - 25,
          left: 0,
          right: 0,
          child: Container(
              padding: const EdgeInsets.only(top: 32),
              child: Text(
                pasteAddress != null ? t.send_address_screen.text1 : t.send_address_screen.text2,
                textAlign: TextAlign.center,
                style: Styles.label.merge(const TextStyle(color: CoconutColors.white)),
              ))),
      if (pasteAddress != null)
        Align(
            alignment: Alignment.bottomCenter,
            child: Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 60),
                child: TextButton(
                    onPressed: pasteAddress,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: address != null ? MyColors.darkgrey : CoconutColors.white,
                      backgroundColor:
                          address != null ? CoconutColors.white : MyColors.transparentBlack_50,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(8),
                        ),
                      ),
                    ),
                    child: address != null
                        ? Text.rich(TextSpan(
                            text: '${t.address} ',
                            style: Styles.label.merge(const TextStyle(color: MyColors.darkgrey)),
                            children: [
                                TextSpan(
                                    text: shortenAddress(address!),
                                    style: TextStyle(
                                        fontFamily: CustomFonts.number.getFontFamily,
                                        fontWeight: FontWeight.bold)),
                                TextSpan(text: ' ${t.paste}')
                              ]))
                        : Text(t.paste,
                            style: Styles.label
                                .merge(const TextStyle(color: MyColors.transparentWhite_20))))))
    ]);
  }
}

Widget _buildOverlay(BuildContext context) {
  final scanAreaSize =
      (MediaQuery.of(context).size.width < 400 || MediaQuery.of(context).size.height < 400)
          ? 320.0
          : MediaQuery.of(context).size.width * 0.85;
  final overlayColor = Colors.black.withOpacity(0.4);

  final statusBarHeight = MediaQuery.of(context).padding.top;
  final totalTopHeight = statusBarHeight - kToolbarHeight + 56;
  final availableHeight = MediaQuery.of(context).size.height - totalTopHeight;
  final scanAreaTop = totalTopHeight + (availableHeight - scanAreaSize) / 2;
  final scanAreaBottom = scanAreaTop + scanAreaSize;
  final scanAreaLeft = (MediaQuery.of(context).size.width - scanAreaSize) / 2;
  final scanAreaRight = scanAreaLeft + scanAreaSize;

  return Stack(children: [
    // 상단 반투명 영역
    Positioned(
      top: statusBarHeight,
      left: 0,
      right: 0,
      height: scanAreaTop + 2,
      child: Container(color: overlayColor),
    ),
    // 하단 반투명 영역
    Positioned(
      top: scanAreaBottom - 2,
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(color: overlayColor),
    ),
    // 왼쪽 반투명 영역
    Positioned(
      top: scanAreaTop + 2,
      left: 0,
      width: scanAreaLeft + 4,
      height: scanAreaSize - 4,
      child: Container(color: overlayColor),
    ),
    // 오른쪽 반투명 영역
    Positioned(
      top: scanAreaTop + 2,
      right: 0,
      width: MediaQuery.of(context).size.width - scanAreaRight + 4,
      height: scanAreaSize - 4,
      child: Container(color: overlayColor),
    ),
    // 스캔 영역 테두리
    Center(
      child: Container(
        width: scanAreaSize,
        height: scanAreaSize,
        decoration: BoxDecoration(
          border: Border.all(color: CoconutColors.gray400, width: 4),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  ]);
}
