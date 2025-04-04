import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';
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
      borderRadius: MyBorder.defaultRadius,
      child: Scaffold(
        backgroundColor: MyColors.black,
        appBar: AppBar(
          title: Text(title ?? ''),
          centerTitle: true,
          backgroundColor: MyColors.black,
          titleTextStyle: Styles.h3,
          toolbarTextStyle: Styles.h3,
          leading: IconButton(
            color: MyColors.white,
            focusColor: MyColors.transparentGrey,
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
              padding: Paddings.container,
              color: MyColors.black,
              child: QRCodeInfo(qrData: qrData, qrcodeTopWidget: qrcodeTopWidget),
            ),
          ),
        ),
      ),
    );
  }
}
