import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/widgets/qrcode_info.dart';

// Usage:
// address_list_screen.dart
// wallet_info_screen.dart
class QrWithCopyTextScreen extends StatelessWidget {
  const QrWithCopyTextScreen({
    super.key,
    required this.qrData,
    this.tooltipDescription,
    this.qrcodeTopWidget,
    this.title,
    this.isAddress = false,
    this.isBottom = false,
    this.actionButton,
  });

  final String qrData;
  final Widget? tooltipDescription;
  final Widget? qrcodeTopWidget;
  final Widget? actionButton;
  final String? title;
  final bool isAddress;
  final bool isBottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.build(
        title: title ?? '',
        context: context,
        isBottom: isBottom,
        onBackPressed: () {
          Navigator.pop(context);
        },
        actionButtonList: [actionButton ?? const SizedBox.shrink()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (tooltipDescription != null) ...[tooltipDescription!, CoconutLayout.spacing_400h],
              CoconutLayout.spacing_300h,
              QrCodeInfo(qrData: qrData, qrcodeTopWidget: qrcodeTopWidget, isAddress: isAddress),
              CoconutLayout.spacing_1500h,
            ],
          ),
        ),
      ),
    );
  }
}
