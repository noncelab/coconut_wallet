import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/common/qr_with_copy_text_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class WalletBackupDataScreen extends StatefulWidget {
  final int id;
  final String backupData;
  final String walletName;
  const WalletBackupDataScreen({super.key, required this.id, required this.backupData, required this.walletName});

  @override
  State<WalletBackupDataScreen> createState() => _WalletBackupDataScreenState();
}

class _WalletBackupDataScreenState extends State<WalletBackupDataScreen> {
  @override
  Widget build(BuildContext context) {
    return QrWithCopyTextScreen(
      qrData: widget.backupData,
      title: t.wallet_info_screen.wallet_backup_data,
      actionButton: IconButton(
        onPressed: () {
          Navigator.pushReplacementNamed(
            context,
            '/confirm-backup-data',
            arguments: {'id': widget.id, 'walletName': widget.walletName},
          );
        },
        icon: SvgPicture.asset('assets/svg/scan.svg'),
      ),
      tooltipDescription: CoconutToolTip(
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
    );
  }
}
