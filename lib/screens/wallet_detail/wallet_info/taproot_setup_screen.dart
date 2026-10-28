import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_view_model.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/features/wallet/taproot/taproot_setup_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 지갑 정보의 참여 지갑 행에서 들어오는 탭루트 상속 구성(부모·자식 지갑과 상속 조건) 화면.
class TaprootSetupScreen extends StatelessWidget {
  static const String routeName = '/wallet-taproot-setup';

  const TaprootSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WalletInfoViewModel>();
    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(context: context, title: t.wallet_info_screen.inheritance_setup),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: TaprootSetupSummaryCard(
          itemList: viewModel.getTaprootParticipants(viewModel.taprootSpendTypeIndex),
          taprootSetupSummaryCardType: TaprootSetupSummaryCardType.column,
        ),
      ),
    );
  }
}
