import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/coordinator_bsms_qr_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/common/qr_with_copy_text_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class WalletBackupDataScreen extends StatelessWidget {
  final int id;
  final String walletName;

  const WalletBackupDataScreen({super.key, required this.id, required this.walletName});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CoordinatorBsmsQrViewModel>(
      create: (_) => CoordinatorBsmsQrViewModel(Provider.of<WalletProvider>(context, listen: false), id),
      child: Consumer<CoordinatorBsmsQrViewModel>(
        builder: (context, viewModel, child) {
          final qrDataMap = viewModel.walletQrDataMap;
          final textDataMap = viewModel.walletTextDataMap;

          String defaultQrData = qrDataMap['BSMS'] ?? (qrDataMap.isNotEmpty ? qrDataMap.values.first : '');

          return QrWithCopyTextScreen(
            qrData: defaultQrData,
            title: t.wallet_info_screen.view_wallet_backup_data,

            qrDataMap: qrDataMap,
            textDataMap: textDataMap,
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
        },
      ),
    );
  }
}
