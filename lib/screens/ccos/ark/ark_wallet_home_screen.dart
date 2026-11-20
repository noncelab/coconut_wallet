import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutToast;

import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_backup_flow.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_backup_nudge.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_expiry_text.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_onboarding_flow.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_renew_sheet.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_progress_view.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_settings_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_welcome_view.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/common/amount/animated_balance.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_movement_labels.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_navigation.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:coconut_wallet/widgets/common/text/section_header.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_shortcut_tile.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class ArkWalletHomeScreen extends StatelessWidget {
  const ArkWalletHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final wallet = context.watch<ArkWalletProvider>();
    final flow = ArkOnboardingFlow(context);
    final step = wallet.step;
    return Scaffold(
      backgroundColor: colors.homeBackground,
      appBar: CoconutAppBar.build(
        context: context,
        backgroundColor: colors.homeBackground,
        title: '',
        actionButtonList: [
          if (wallet.hasWallet && !ArkWalletProgressView.isInProgress(step))
            CoconutAppBarActionButton(
              key: const Key('ark-wallet-settings'),
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletSettings),
                      builder: (_) => const ArkWalletSettingsScreen(),
                    ),
                  ),
              icon: SvgPicture.asset(
                FeatureSettingsIconPath.settings,
                colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
              ),
            ),
        ],
      ),
      body:
          ArkWalletProgressView.isInProgress(step)
              ? ArkWalletProgressView(step: step!)
              : !wallet.hasWallet
              ? ArkWalletWelcomeView(onCreateNew: flow.createNew, onRestore: flow.restore)
              : wallet.state == ArkWalletState.failed
              ? _ArkOpenFailedView(onRetry: wallet.openAfterAppEntrance)
              : _ArkWalletBody(wallet: wallet),
    );
  }
}

/// 지갑을 열지 못했을 때. 보내기 실패와 같은 경고, 복원 중 화면과 같은 높이
class _ArkOpenFailedView extends StatelessWidget {
  const _ArkOpenFailedView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Stack(
      children: [
        Align(
          alignment: const Alignment(0, -0.45),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  CommonStateIconPath.circleWarning,
                  key: const Key('ark-open-failed-icon'),
                  width: 56,
                  height: 56,
                  colorFilter: ColorFilter.mode(colors.danger, BlendMode.srcIn),
                ),
                CoconutLayout.spacing_500h,
                Text(t.ark_wallet.open_failed, style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText)),
                CoconutLayout.spacing_200h,
                Text(
                  t.ark_wallet.open_failed_desc,
                  textAlign: TextAlign.center,
                  style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                ),
              ],
            ),
          ),
        ),
        FixedBottomButton(text: t.retry, onButtonClicked: onRetry),
      ],
    );
  }
}

class _ArkWalletBody extends StatefulWidget {
  const _ArkWalletBody({required this.wallet});

  final ArkWalletProvider wallet;

  @override
  State<_ArkWalletBody> createState() => _ArkWalletBodyState();
}

class _ArkWalletBodyState extends State<_ArkWalletBody> {
  static const _sectionHeaderHeight = 36.0;
  static const _bottomPadding = 24.0;

  final GlobalKey _topKey = GlobalKey();
  double? _topHeight;
  StreamSubscription<ArkMovement>? _received;

  @override
  void initState() {
    super.initState();
    _received = widget.wallet.received.listen((movement) {
      if (!mounted) return;
      final unit = context.read<ArkWalletProvider>().unit;
      CoconutToast.showToast(
        context: context,
        text: t.ark_wallet.received(amount: unit.displayBitcoinAmount(movement.effectiveBalanceSats, withUnit: true)),
        isVisibleIcon: true,
      );
    });
  }

  @override
  void dispose() {
    _received?.cancel();
    super.dispose();
  }

  int _rowsFor(double viewportHeight) {
    final top = _topHeight;
    if (top == null) return RecentTransactionsView.defaultRows;
    final available = viewportHeight - top - _sectionHeaderHeight - _bottomPadding;
    final rows = ((available - 16 + 1) / 67).floor();
    return rows.clamp(RecentTransactionsView.defaultRows, 5);
  }

  void _measureTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final height = _topKey.currentContext?.size?.height;
      if (!mounted || height == null || height == _topHeight) return;
      setState(() => _topHeight = height);
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;
    final colors = context.coconutColors;
    final navigation = ArkWalletNavigation(context);
    final balance = wallet.balance.total;
    final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
    final recent = wallet.movements;
    final canFill = context.select<WalletProvider, bool>(
      (wallets) => ArkWalletNavigation.fillWalletIds(wallets).isNotEmpty,
    );
    _measureTop();
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = recent.isEmpty ? 1 : recent.length.clamp(1, _rowsFor(constraints.maxHeight));
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                key: _topKey,
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      key: const Key('ark-wallet-balance'),
                      behavior: HitTestBehavior.opaque,
                      onTap: wallet.toggleUnit,
                      child: Column(
                        children: [
                          BitcoinAmountUnit(
                            currentUnit: unit,
                            unitStyle: CoconutTypography.heading4_18_Number.setColor(colors.primaryText),
                            spacing: CoconutLayout.spacing_100w,
                            child: AnimatedBalance(
                              prevValue: balance,
                              value: balance,
                              currentUnit: unit,
                              textStyle: CoconutTypography.heading2_28_NumberBold.setColor(colors.primaryText),
                            ),
                          ),
                          FiatPrice(satoshiAmount: balance, textColor: colors.secondaryText),
                        ],
                      ),
                    ),
                    if (wallet.isRecoveryPending) ...[
                      CoconutLayout.spacing_200h,
                      Text(
                        t.ark_wallet.recovery_pending,
                        textAlign: TextAlign.center,
                        style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                      ),
                    ],
                    CoconutLayout.spacing_500h,
                    Row(
                      children: [
                        for (final (index, tile)
                            in [
                              (
                                id: 'ark-wallet-fill',
                                icon: CommonActionIconPath.plus,
                                scale: 14 / 24,
                                label: t.ark_wallet.fill,
                                onPressed: canFill ? navigation.openFill : null,
                              ),
                              (
                                id: 'ark-wallet-export',
                                icon: CommonActionIconPath.removeMinus,
                                scale: 1.0,
                                label: t.ark_wallet.export,
                                onPressed: balance > 0 ? navigation.openExport : null,
                              ),
                              (
                                id: 'ark-wallet-receive',
                                icon: FeatureArkIconPath.receive,
                                scale: 1.0,
                                label: t.receive,
                                onPressed: navigation.openReceive,
                              ),
                              (
                                id: 'ark-wallet-send',
                                icon: FeatureArkIconPath.send,
                                scale: 1.0,
                                label: t.send,
                                onPressed: balance > 0 ? navigation.openSend : null,
                              ),
                            ].indexed) ...[
                          if (index > 0) const SizedBox(width: HomeItemsView.gap),
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: switch (tile.onPressed) {
                                final onPressed? => HomePressableRow(
                                  key: Key(tile.id),
                                  onTap: onPressed,
                                  borderRadius: 16,
                                  overlayInFront: true,
                                  child: HomeShortcutTile(
                                    id: tile.id,
                                    label: tile.label,
                                    iconPath: tile.icon,
                                    iconScale: tile.scale,
                                    onPressed: null,
                                  ),
                                ),
                                null => Opacity(
                                  key: Key(tile.id),
                                  opacity: 0.35,
                                  child: HomeShortcutTile(
                                    id: tile.id,
                                    label: tile.label,
                                    iconPath: tile.icon,
                                    iconScale: tile.scale,
                                    onPressed: null,
                                  ),
                                ),
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (wallet.canRenewDue) ...[
                      CoconutLayout.spacing_500h,
                      ArkNudgeCard(
                        key: const Key('ark-renew-nudge'),
                        title: t.ark_wallet.renew_title(
                          amount: unit.displayBitcoinAmount(wallet.renewAmount, withUnit: true),
                        ),
                        line:
                            wallet.hasExpiredToRenew
                                ? t.ark_wallet.renew_line_expired
                                : t.ark_wallet.renew_line(
                                  time: arkExpiryText(
                                    wallet.vtxosToRenew.first.blocksLeft(wallet.tipHeight) ??
                                        ArkWalletProvider.renewWindowBlocks,
                                  ),
                                ),
                        buttonText: t.ark_wallet.renew_button,
                        onPressed: () => showArkRenewSheet(context, wallet.vtxosToRenew),
                      ),
                    ] else if (wallet.needsBackup) ...[
                      CoconutLayout.spacing_500h,
                      ArkBackupNudge(onBackup: () => startArkWalletBackup(context, wallet)),
                    ] else if (wallet.remindersOff && wallet.vtxos.isNotEmpty) ...[
                      CoconutLayout.spacing_500h,
                      ArkNudgeCard(
                        key: const Key('ark-reminder-nudge'),
                        title: t.ark_wallet.reminder_off_title,
                        line: t.ark_wallet.reminder_off_line,
                        buttonText: t.ark_wallet.reminder_off_button,
                        onPressed: wallet.allowReminders,
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, _bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: t.wallet_detail_screen.recent_transactions,
                      onMore: navigation.openActivity,
                      moreEnabled: recent.isNotEmpty,
                    ),
                    SizedBox(
                      height: RecentTransactionsView.heightFor(rows),
                      child: RecentTransactionsView(
                        rows: rows,
                        transactions:
                            recent
                                .take(rows)
                                .map((movement) => arkMovementAsRecent(movement, memo: wallet.memoOf(movement.id)))
                                .toList(),
                        amountText: (sats) => unit.displayBitcoinAmount(sats, withUnit: true),
                        now: DateTime.now(),
                        emptyMessage: t.ark_wallet.no_activity,
                        monochrome: true,
                        iconPathOf: (tx) => arkMovementIconPath(recent, tx),
                        timeDetailOf: (tx) => arkMovementTimeDetail(recent, tx),
                        statusTextOf: (tx) => arkMovementStatusTextOf(recent, tx),
                        onTransactionSelected: (tx) {
                          final movement = recent.where((movement) => '${movement.id}' == tx.txHash).firstOrNull;
                          if (movement != null) navigation.openMovement(movement);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
