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
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_overview_filter_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 아크 지갑 거래 내역. 전체·온체인·아크·라이트닝 칩, 진행 중 묶음 다음 날짜별 묶음
class ArkActivityScreen extends StatefulWidget {
  const ArkActivityScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletActivity),
      builder: (_) => const ArkActivityScreen(),
    ),
  );

  @override
  State<ArkActivityScreen> createState() => _ArkActivityScreenState();
}

class _ArkActivityScreenState extends State<ArkActivityScreen> {
  ArkActivityRail _rail = ArkActivityRail.all;

  String _railLabel(ArkActivityRail rail) => switch (rail) {
    ArkActivityRail.all => t.all,
    ArkActivityRail.onchain => t.ark_wallet.route_onchain,
    ArkActivityRail.ark => t.ark_wallet.route_ark,
    ArkActivityRail.lightning => t.ark_wallet.route_lightning,
  };

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
    int countOf(ArkActivityRail rail) =>
        rail == ArkActivityRail.all
            ? wallet.movements.length
            : wallet.movements.where((movement) => arkMovementRail(movement) == rail).length;
    final groups = groupArkMovements([
      for (final movement in wallet.movements)
        if (_rail == ArkActivityRail.all || arkMovementRail(movement) == _rail) movement,
    ], now);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(
        context: context,
        backgroundColor: colors.background,
        title: t.ark_wallet.activity_title,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: wallet.syncNow,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: _ArkFilterBar.chipsHeight)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  sliver: SliverList.list(
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
                          statusTextOf: (tx) => arkMovementStatusTextOf(group.movements, tx),
                          onTransactionSelected: (tx) {
                            final movement =
                                group.movements.where((movement) => '${movement.id}' == tx.txHash).firstOrNull;
                            if (movement != null) ArkMovementDetailScreen.open(context, movement);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ArkFilterBar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 8,
                  children: [
                    for (final rail in ArkActivityRail.values)
                      KeyedSubtree(
                        key: Key('ark-activity-filter-${rail.name}'),
                        child: AnimatedUtxoFilterChip(
                          label: _railLabel(rail),
                          count: countOf(rail),
                          isSelected: _rail == rail,
                          onTap: () => setState(() => _rail = rail),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 목록 위에 겹쳐 앱바 아래에 고정되는 칩 줄. 배경이 위에서부터 옅어져 지나가는 내역이 자연스럽게 사라짐
class _ArkFilterBar extends StatelessWidget {
  const _ArkFilterBar({required this.child});

  static const double chipsHeight = 48;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return SizedBox(
      height: chipsHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                key: const Key('ark-activity-filter-bar'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.25, 0.6, 1],
                    colors: [
                      colors.background,
                      colors.background,
                      colors.background.withValues(alpha: 0.7),
                      colors.background.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: chipsHeight,
            child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: child),
          ),
        ],
      ),
    );
  }
}
