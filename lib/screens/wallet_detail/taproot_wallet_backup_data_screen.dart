import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutToolTip, CoconutTooltipType, CoconutTooltipState, CoconutToast, CoconutToastLevel, CoconutPopup;
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/taproot_wallet_backup_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/common/qr_with_copy_text_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

class TaprootWalletBackupDataScreen extends StatelessWidget {
  final int id;
  final String walletName;

  const TaprootWalletBackupDataScreen({super.key, required this.id, required this.walletName});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TaprootWalletBackupViewModel>(
      create: (_) => TaprootWalletBackupViewModel(Provider.of<WalletProvider>(context, listen: false), id),
      child: Consumer<TaprootWalletBackupViewModel>(
        builder: (context, viewModel, child) {
          final qrDataMap = viewModel.walletQrDataMap;
          final textDataMap = viewModel.walletTextDataMap;

          String defaultQrData = qrDataMap['Wallet Info'] ?? (qrDataMap.isNotEmpty ? qrDataMap.values.first : '');

          return QrWithCopyTextScreen(
            qrData: defaultQrData,
            title: t.wallet_info_screen.view_wallet_backup_data,
            qrDataMap: qrDataMap,
            textDataMap: textDataMap,
            showPulldownMenu: false,
            qrInternalPadding: 24,
            tooltipDescription: Container(
              margin: const EdgeInsets.only(top: 4, bottom: 16),
              child: CoconutToolTip(
                backgroundColor: context.coconutColors.surface,
                borderColor: context.coconutColors.surface,
                icon: SvgPicture.asset(
                  CommonStateIconPath.circleInfo,
                  width: 20,
                  colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
                ),
                tooltipType: CoconutTooltipType.fixed,
                richText: RichText(
                  text: TextSpan(
                    text: t.wallet_info_screen.tooltip.taproot_wallet_backup_data,
                    style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
