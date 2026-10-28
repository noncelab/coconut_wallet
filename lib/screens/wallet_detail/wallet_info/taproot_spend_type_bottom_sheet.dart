import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_view_model.dart';
import 'package:coconut_wallet/widgets/features/wallet/taproot/taproot_spend_type_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 지갑 정보의 서명 방식 행에서 여는 시트. 고르는 즉시 기본 서명 경로가 바뀐다.
class TaprootSpendTypeBottomSheet extends StatelessWidget {
  const TaprootSpendTypeBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WalletInfoViewModel>();
    final selectedIndex = viewModel.taprootSpendTypeIndex;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TaprootSpendTypeSegmentedControl(selectedIndex: selectedIndex, onPressed: viewModel.updateTaprootSpendType),
            const SizedBox(height: 16),
            TaprootRoleDescriptionCard(isParent: selectedIndex == 0, hasSingleParent: viewModel.hasSingleTaprootParent),
          ],
        ),
      ),
    );
  }
}
