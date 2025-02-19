import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/qrcode_info.dart';

// Usage:
// address_list_screen.dart
// wallet_info_screen.dart
class QrcodeBottomSheet extends StatelessWidget {
  const QrcodeBottomSheet({
    super.key,
    required this.qrData,
    this.heightRatio = 0.95,
    this.qrcodeTopWidget,
    this.title,
  });

  final String qrData;
  final double heightRatio;
  final Widget? qrcodeTopWidget;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return CoconutBottomSheet(
      heightRatio: heightRatio,
      appBar: CoconutAppBar.build(
          context: context,
          title: title ?? '',
          hasRightIcon: false,
          isBottom: true),
      body: SingleChildScrollView(
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height * 0.9,
          padding: Paddings.container,
          color: MyColors.black,
          child: QRCodeInfo(qrData: qrData, qrcodeTopWidget: qrcodeTopWidget),
        ),
      ),
    );
  }
}
