import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_view_model.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/features/wallet/signer/multisig_signer_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 지갑 정보의 정족수 행에서 들어오는 다중서명 구성(서명자 목록) 화면.
class MultisigSetupScreen extends StatelessWidget {
  static const String routeName = '/wallet-multisig-setup';

  const MultisigSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WalletInfoViewModel>();
    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(context: context, title: t.wallet_info_screen.multisig_setup),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        itemCount: viewModel.multisigTotalSignerCount,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder:
            (context, index) => MultisigSignerCard(
              index: index,
              signer: viewModel.getSigner(index),
              masterFingerprint: viewModel.getSignerMasterFingerprint(index),
              derivationPath: viewModel.getSignerBsms(index).derivationPath,
            ),
      ),
    );
  }
}
