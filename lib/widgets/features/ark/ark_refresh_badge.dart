import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 지갑 카드 아이콘 모서리에 붙는 아크 만료 안내 점. 지갑 상세 배너가 있을 때만, 같은 색(만료 빨강, 그 외 노랑)
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
    final notice = ark.refreshNotice(walletId);
    if (notice == null) return const SizedBox.shrink();
    return Container(
      key: ValueKey('ark-refresh-badge-$walletId'),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: notice.isDanger ? context.coconutColors.danger : context.coconutColors.warning,
        shape: BoxShape.circle,
      ),
    );
  }
}
