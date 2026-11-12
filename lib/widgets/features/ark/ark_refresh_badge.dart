import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// 지갑 카드에 붙는 아크 갱신 경고, 갱신이 급할 때만 보임
class ArkRefreshBadge extends StatelessWidget {
  const ArkRefreshBadge({super.key, required this.walletId});

  final int walletId;

  @override
  Widget build(BuildContext context) {
    final ArkProvider ark;
    try {
      ark = Provider.of<ArkProvider>(context);
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    if (!ark.needsRefreshAttention(walletId)) return const SizedBox.shrink();
    return SvgPicture.asset(
      CommonStateIconPath.triangleWarning,
      key: ValueKey('ark-refresh-badge-$walletId'),
      width: 14,
      height: 14,
      colorFilter: ColorFilter.mode(context.coconutColors.warning, BlendMode.srcIn),
    );
  }
}
