import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/widgets/qrcode_info.dart';

// Usage:
// address_list_screen.dart
// wallet_info_screen.dart
class QrcodeBottomSheet extends StatelessWidget {
  const QrcodeBottomSheet({super.key, required this.qrData, this.qrcodeTopWidget, this.title});

  final String qrData;
  final Widget? qrcodeTopWidget;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(CoconutStyles.radius_400),
      child: Scaffold(
        backgroundColor: CoconutColors.black,
        appBar: AppBar(
          title: Text(title ?? ''),
          centerTitle: true,
          backgroundColor: CoconutColors.black,
          titleTextStyle: CoconutTypography.heading4_18,
          toolbarTextStyle: CoconutTypography.body3_12,
          leading: IconButton(
            color: CoconutColors.white,
            focusColor: CoconutColors.gray400,
            icon: const Icon(CupertinoIcons.xmark, size: 20),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.9,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              color: CoconutColors.black,
              child: QRCodeInfo(qrData: qrData, qrcodeTopWidget: qrcodeTopWidget),
            ),
          ),
        ),
      ),
    );
  }
}
