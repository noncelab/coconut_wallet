import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_activity_groups.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_movement_detail_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_movement_labels.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 아크 지갑 거래 내역. 진행 중 묶음 다음 날짜별 묶음
class ArkActivityScreen extends StatelessWidget {
  const ArkActivityScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletActivity),
      builder: (_) => const ArkActivityScreen(),
    ),
  );

  String _title(BuildContext context, ArkActivityGroup group) => switch (group.kind) {
    ArkActivityGroupKind.pending => t.ark_wallet.group_pending,
    ArkActivityGroupKind.today => t.home_widgets.today,
    ArkActivityGroupKind.yesterday => t.ark_wallet.group_yesterday,
    ArkActivityGroupKind.day => DateTimeUtil.formatTimestamp(group.day!).first,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final wallet = context.watch<ArkWalletProvider>();
    final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
    final now = DateTime.now();
    final groups = groupArkMovements(wallet.movements, now);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, title: t.ark_wallet.activity_title),
      body: RefreshIndicator(
        onRefresh: wallet.syncNow,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(
                  child: Text(
                    t.ark_wallet.no_activity,
                    style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                  ),
                ),
              ),
            for (final group in groups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
                child: Text(
                  _title(context, group),
                  style: CoconutTypography.body2_14_Bold.setColor(colors.secondaryText),
                ),
              ),
              RecentTransactionsView(
                key: ValueKey('ark-activity-${group.kind.name}-${group.day}'),
                transactions:
                    group.movements
                        .map((movement) => arkMovementAsRecent(movement, memo: wallet.memoOf(movement.id)))
                        .toList(),
                amountText: (sats) => unit.displayBitcoinAmount(sats, withUnit: true),
                now: now,
                showAllTransactions: true,
                monochrome: true,
                iconPathOf: (tx) => arkMovementIconPath(group.movements, tx),
                timeDetailOf: (tx) => arkMovementTimeDetail(group.movements, tx),
                onTransactionSelected: (tx) {
                  final movement = group.movements.where((movement) => '${movement.id}' == tx.txHash).firstOrNull;
                  if (movement != null) ArkMovementDetailScreen.open(context, movement);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
