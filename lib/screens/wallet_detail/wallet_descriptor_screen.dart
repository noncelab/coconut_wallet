import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/common/qr_with_copy_text_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class WalletDescriptorScreen extends StatefulWidget {
  final int id;
  final String descriptor;
  final String walletName;
  const WalletDescriptorScreen({super.key, required this.id, required this.descriptor, required this.walletName});

  @override
  State<WalletDescriptorScreen> createState() => _WalletDescriptorScreenState();
}

class _WalletDescriptorScreenState extends State<WalletDescriptorScreen> {
  @override
  Widget build(BuildContext context) {
    return QrWithCopyTextScreen(
      qrData: widget.descriptor,
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
