import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/common/qr_with_copy_text_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class WalletBackupViewModel extends ChangeNotifier {
  final String _qrData;
  final String _walletName;

  WalletBackupViewModel({required String qrData, required String walletName})
    : _qrData = qrData,
      _walletName = walletName;

  String get qrData => _qrData;
  String get walletName => _walletName;

  Map<String, String> get qrDataMap => {'1/1': _qrData};
}

class WalletBackupDataScreen extends StatelessWidget {
  final int id;
  final String backupData;
  final String walletName;

  const WalletBackupDataScreen({super.key, required this.id, required this.backupData, required this.walletName});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WalletBackupViewModel(qrData: backupData, walletName: walletName),
      child: Consumer<WalletBackupViewModel>(
        builder: (context, viewModel, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: CoconutColors.white,
            child: QrWithCopyTextScreen(
              title: t.wallet_info_screen.wallet_backup_data,
              qrData: viewModel.qrData,
              qrDataMap: viewModel.qrDataMap,
              showPulldownMenu: false,
              actionButton: null,
              tooltipDescription: _buildDescription(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDescription() {
    return Container(
      decoration: BoxDecoration(color: CoconutColors.gray150, borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(top: 4, bottom: 16),
      padding: const EdgeInsets.all(16),
      child: Column(children: [_buildTooltipRow(t.wallet_info_screen.tooltip.wallet_backup_data)]),
    );
  }

  Widget _buildTooltipRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          'assets/svg/circle-info.svg',
          width: 20,
          colorFilter: const ColorFilter.mode(CoconutColors.gray800, BlendMode.srcIn),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: CoconutColors.gray800, fontSize: 14, height: 1.5))),
      ],
    );
  }
}
