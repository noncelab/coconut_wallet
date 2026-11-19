import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

/// 만드는 중·복원 중. 문구는 실제 진행 단계를 따름
class ArkWalletProgressView extends StatelessWidget {
  const ArkWalletProgressView({super.key, required this.step});

  final ArkCreateStep step;

  static bool isInProgress(ArkCreateStep? step) => step != null && step != ArkCreateStep.ready;

  String get _label => switch (step) {
    ArkCreateStep.keys => t.ark_wallet.step_keys,
    ArkCreateStep.connecting => t.ark_wallet.step_connecting,
    ArkCreateStep.restoring => t.ark_wallet.step_restoring,
    ArkCreateStep.findingFunds => t.ark_wallet.step_finding_funds,
    ArkCreateStep.ready => '',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Align(
      alignment: const Alignment(0, -0.45),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: colors.primaryText),
          CoconutLayout.spacing_500h,
          Text(_label, style: CoconutTypography.body1_16.setColor(colors.primaryText)),
        ],
      ),
    );
  }
}
