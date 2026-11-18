import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_vtxo.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_expiry_text.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_renew_sheet.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_vtxo_detail_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_vtxo_groups.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_refresh_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:provider/provider.dart';

/// 아크 지갑의 VTXO. 곧 만료·사용 가능·사용 중으로 묶고, 하루 안에 만료되는 것이 있으면 갱신 버튼
class ArkVtxoListScreen extends StatefulWidget {
  const ArkVtxoListScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletVtxos),
      builder: (_) => const ArkVtxoListScreen(),
    ),
  );

  @override
  State<ArkVtxoListScreen> createState() => _ArkVtxoListScreenState();
}

class _ArkVtxoListScreenState extends State<ArkVtxoListScreen> {
  static const _minimumRefreshDuration = Duration(milliseconds: 700);

  Set<String>? _selected;
  bool _refreshing = false;

  /// 당겨서 새로 고침, 앱바에 업데이트 표시(코코넛 거래 상세와 같은 방식)
  Future<void> _refresh(ArkWalletProvider wallet) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final stopwatch = Stopwatch()..start();
    try {
      await wallet.syncNow();
    } finally {
      final remaining = _minimumRefreshDuration - stopwatch.elapsed;
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _startSelecting(ArkWalletProvider wallet) =>
      setState(() => _selected = {for (final vtxo in wallet.vtxosToRenew) vtxo.id});

  Future<void> _renew(ArkWalletProvider wallet, List<ArkVtxo> vtxos) async {
    await showArkRenewSheet(context, vtxos);
    if (mounted) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final wallet = context.watch<ArkWalletProvider>();
    final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
    final vtxos = wallet.vtxos;
    final selected = _selected;
    final total = vtxos.fold(0, (sum, vtxo) => sum + vtxo.amountSats);
    final groups = groupArkVtxos(vtxos, toRenew: wallet.vtxosToRenew, isRenewing: wallet.isRenewing);
    final first = vtxos.isEmpty ? null : vtxos.first.blocksLeft(wallet.tipHeight);
    bool canPick(ArkVtxo vtxo) => canRenewArkVtxo(vtxo, tipHeight: wallet.tipHeight, isRenewing: wallet.isRenewing);
    final toRenew = wallet.vtxosToRenew;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(
        context: context,
        title: t.ark_wallet.vtxos,
        actionButtonList: [
          WalletRefreshIndicator(isRefreshing: _refreshing),
          if (vtxos.any(canPick))
            CupertinoButton(
              key: const Key('ark-vtxo-select'),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              onPressed: () => selected == null ? _startSelecting(wallet) : setState(() => _selected = null),
              child: AnimatedSwitcher(
                duration: _selectAnimation,
                child: Text(
                  selected == null ? t.ark_wallet.vtxo_select : t.cancel,
                  key: ValueKey(selected == null),
                  style: CoconutTypography.body2_14.setColor(colors.primaryText),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () => _refresh(wallet),
                refreshTriggerPullDistance: 80,
                refreshIndicatorExtent: 0,
                builder: (_, _, _, _, _) => const SizedBox.shrink(),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverList.list(
                  children: [
                    CoconutToolTip(
                      key: const Key('ark-vtxo-about'),
                      backgroundColor: colors.surface,
                      borderColor: colors.surface,
                      icon: SvgPicture.asset(
                        CommonStateIconPath.circleInfo,
                        width: 20,
                        colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
                      ),
                      tooltipType: CoconutTooltipType.fixed,
                      richText: RichText(
                        text: TextSpan(
                          text: t.ark_wallet.vtxo_about,
                          style: CoconutTypography.body2_14.setColor(colors.primaryText),
                        ),
                      ),
                    ),
                    CoconutLayout.spacing_500h,
                    Center(
                      child: BitcoinAmountUnit(
                        currentUnit: unit,
                        unitStyle: CoconutTypography.heading4_18_Number.setColor(colors.primaryText),
                        spacing: CoconutLayout.spacing_100w,
                        child: Text(
                          unit.displayBitcoinAmount(total),
                          style: CoconutTypography.heading2_28_NumberBold.setColor(colors.primaryText),
                        ),
                      ),
                    ),
                    CoconutLayout.spacing_100h,
                    Text(
                      [
                        t.ark_wallet.vtxo_count(n: vtxos.length),
                        if (first != null && first > 0) t.ark_wallet.vtxo_next_expiry(time: arkDurationText(first)),
                      ].join(' · '),
                      key: const Key('ark-vtxo-summary'),
                      textAlign: TextAlign.center,
                      style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                    ),
                    if (vtxos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Center(
                          child: Text(
                            t.ark_wallet.no_vtxos,
                            style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                          ),
                        ),
                      ),
                    for (final group in groups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
                        child: Text(
                          '${switch (group.kind) {
                            ArkVtxoGroupKind.expiring => t.ark_wallet.group_expiring,
                            ArkVtxoGroupKind.spendable => t.ark_wallet.group_spendable,
                            ArkVtxoGroupKind.locked => t.ark_wallet.group_locked,
                          }} · ${group.vtxos.length}',
                          style: CoconutTypography.body2_14_Bold.setColor(colors.secondaryText),
                        ),
                      ),
                      SizedBox(
                        height: 16 + group.vtxos.length * 64 + group.vtxos.length - 1,
                        child: HomeWidgetCard(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final (index, vtxo) in group.vtxos.indexed) ...[
                                if (index > 0)
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 16),
                                    height: 1,
                                    color: colors.divider,
                                  ),
                                _VtxoRow(
                                  vtxo: vtxo,
                                  amount: unit.displayBitcoinAmount(vtxo.amountSats, withUnit: true),
                                  line:
                                      wallet.isRenewing(vtxo.id)
                                          ? t.ark_wallet.vtxo_renewing
                                          : t.ark_wallet.expires(
                                            time: arkExpiryText(vtxo.blocksLeft(wallet.tipHeight)),
                                          ),
                                  urgent: group.kind == ArkVtxoGroupKind.expiring,
                                  selected: selected == null ? null : selected.contains(vtxo.id),
                                  onTap: () {
                                    if (selected == null) {
                                      ArkVtxoDetailScreen.open(context, vtxo);
                                    } else if (canPick(vtxo)) {
                                      setState(
                                        () =>
                                            selected.contains(vtxo.id)
                                                ? selected.remove(vtxo.id)
                                                : selected.add(vtxo.id),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: _selectAnimation,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder:
                  (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
              child:
                  selected != null
                      ? FixedBottomButton(
                        key: const ValueKey('ark-vtxo-renew-picked'),
                        text: t.ark_wallet.renew_selected(n: selected.length),
                        isActive: selected.isNotEmpty,
                        onButtonClicked:
                            () => _renew(wallet, vtxos.where((vtxo) => selected.contains(vtxo.id)).toList()),
                      )
                      : toRenew.isNotEmpty
                      ? FixedBottomButton(
                        key: const ValueKey('ark-vtxo-renew-due'),
                        text: t.ark_wallet.renew_title(
                          amount: unit.displayBitcoinAmount(wallet.renewAmount, withUnit: true),
                        ),
                        onButtonClicked: () => _renew(wallet, toRenew),
                      )
                      : const SizedBox.shrink(key: ValueKey('ark-vtxo-renew-none')),
            ),
          ),
        ],
      ),
    );
  }
}

class _VtxoRow extends StatelessWidget {
  const _VtxoRow({
    required this.vtxo,
    required this.amount,
    required this.line,
    required this.urgent,
    required this.selected,
    required this.onTap,
  });

  final ArkVtxo vtxo;
  final String amount;
  final String line;
  final bool urgent;

  /// 고르는 중이 아니면 null
  final bool? selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final selected = this.selected;
    return HomePressableRow(
      key: ValueKey('ark-vtxo-${vtxo.id}'),
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: selected == null ? 0 : 1),
              duration: _selectAnimation,
              curve: Curves.easeInOut,
              builder:
                  (context, value, child) => ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: value,
                      child: Opacity(opacity: value, child: child),
                    ),
                  ),
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  selected ?? false ? CupertinoIcons.checkmark_square : CupertinoIcons.square,
                  key: ValueKey('ark-vtxo-check-${vtxo.id}-${selected ?? false}'),
                  size: 24,
                  color: colors.primaryText,
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line, style: CoconutTypography.body2_14.setColor(urgent ? colors.warning : colors.primaryText)),
                  CoconutLayout.spacing_100h,
                  Text(
                    t.ark_wallet.vtxo_row_detail(
                      block: arkBlockText(vtxo.expiryHeight),
                      id: '${vtxo.id.substring(0, vtxo.id.length < 6 ? vtxo.id.length : 6)}…',
                    ),
                    style: CoconutTypography.body3_12_Number.setColor(colors.secondaryText),
                  ),
                ],
              ),
            ),
            CoconutLayout.spacing_300w,
            Text(amount, style: CoconutTypography.body2_14_Number.setColor(colors.primaryText)),
          ],
        ),
      ),
    );
  }
}

/// 골라서 갱신을 켜고 끌 때 체크 칸이 나오고 글자가 옆으로 비키는 시간
const _selectAnimation = Duration(milliseconds: 250);
