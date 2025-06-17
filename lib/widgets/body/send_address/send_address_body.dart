import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class SendAddressBody extends StatelessWidget {
  final Key qrKey;
  final void Function(QRViewController) onQrViewCreated;
  final String? address;
  final void Function()? pasteAddress;

  const SendAddressBody(
      {super.key,
      required this.qrKey,
      required this.onQrViewCreated,
      this.address,
      this.pasteAddress});

  Widget _buildQrView(BuildContext context) {
    return QRView(
      key: qrKey,
      onQRViewCreated: onQrViewCreated,
      overlay: QrScannerOverlayShape(
          borderColor: CoconutColors.white,
          borderRadius: 8,
          borderLength:
              (MediaQuery.of(context).size.width < 400 || MediaQuery.of(context).size.height < 400)
                  ? 160
                  : MediaQuery.of(context).size.width * 0.9 / 2,
          borderWidth: 8,
          cutOutSize:
              (MediaQuery.of(context).size.width < 400 || MediaQuery.of(context).size.height < 400)
                  ? 320.0
                  : MediaQuery.of(context).size.width * 0.9),
    );
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
          top: kToolbarHeight - 75,
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
                                    text: address!.length > 20
                                        ? '${address!.substring(0, 10)}...${address!.substring(address!.length - 10)}'
                                        : address!,
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
