import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

/// 지갑이 업데이트 중임을 알리는 스피너와 문구
class WalletSyncingLabel extends StatelessWidget {
  const WalletSyncingLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.coconutColors.primaryText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            strokeAlign: CircularProgressIndicator.strokeAlignInside,
            color: color,
          ),
        ),
        CoconutLayout.spacing_100w,
        Text(t.status_updating, style: CoconutTypography.body3_12_Bold.setColor(color)),
      ],
    );
  }
}
