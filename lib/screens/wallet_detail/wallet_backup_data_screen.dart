import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/common/qr_with_copy_text_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class WalletBackupDataScreen extends StatefulWidget {
  final int id;
  final String walletName;

  final Map<String, String> qrDataMap;
  final Map<String, String> textDataMap;

  const WalletBackupDataScreen({
    super.key,
    required this.id,
    required this.walletName,
    required this.qrDataMap,
    required this.textDataMap,
  });

  @override
  State<WalletBackupDataScreen> createState() => _WalletBackupDataScreenState();
}

class _WalletBackupDataScreenState extends State<WalletBackupDataScreen> {
  @override
  Widget build(BuildContext context) {
    String defaultQrData =
        widget.qrDataMap['BSMS'] ?? (widget.qrDataMap.isNotEmpty ? widget.qrDataMap.values.first : '');

    return QrWithCopyTextScreen(
      qrData: defaultQrData,
      title: t.wallet_info_screen.view_wallet_backup_data,

      qrDataMap: widget.qrDataMap,
      textDataMap: widget.textDataMap,
      showPulldownMenu: true,

      tooltipDescription: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 16),
        child: CoconutToolTip(
          backgroundColor: CoconutColors.gray800,
          borderColor: CoconutColors.gray800,
          icon: SvgPicture.asset(
            'assets/svg/circle-info.svg',
            width: 20,
            colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
          ),
          tooltipType: CoconutTooltipType.fixed,
          richText: RichText(text: TextSpan(text: t.wallet_info_screen.tooltip.wallet_backup_data)),
        ),
      ),
    );
  }
}
