import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/safety/home_safety_banner.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_score_gauge.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_health_cards.dart' show safetyCheckName;
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// Safety Status 위젯 본문(2×2·4×2). W1 정상 / W2 확인 필요 / W3 위급. 잔액·금액은 보이지 않는다.
/// 데이터는 앱 전역 [SafetyProvider]에서 읽고, 첫 평가 전에는 스켈레톤. provider가 없으면 아무것도 그리지 않는다.
class SafetyStatusWidgetView extends StatelessWidget {
  const SafetyStatusWidgetView({super.key, required this.span});

  final HomeSpan span;

  @override
  Widget build(BuildContext context) {
    final wide = span == HomeSpan.wide;
    final hasProvider = context.select<SafetyProvider?, bool>((safety) => safety != null);
    if (!hasProvider) return const SizedBox.shrink();
    // 보고서 비교는 evaluatedAt을 빼므로(결과가 같으면 같은 보고서) "마지막 검사" 시각이 바뀌어도 다시 그리게 시각을 같이 고른다
    final (report, _) = context.select<SafetyProvider?, (WalletHealthReport?, DateTime?)>(
      (safety) => (safety?.report, safety?.report?.evaluatedAt),
    );
    if (report == null) return HomeWidgetSkeleton(wide: wide);

    final colors = context.coconutColors;
    final wallets = context.watch<WalletProvider?>()?.walletItemList ?? const <WalletItemBase>[];
    final walletName = walletNameLookup(wallets);
    final critical = safetyCriticalAlertOf(report, walletName);
    final issues = report.attentionCount;
    final lastChecked = t.wallet_health.summary.last_checked(
      time: formatHomeRelativeTime(report.evaluatedAt, DateTime.now()),
    );

    final String title;
    final String iconPath;
    final Color iconColor, titleColor;
    final List<Widget> details;
    final detailStyle = CoconutTypography.body3_12.copyWith(color: colors.secondaryText);
    final actionStyle = CoconutTypography.body3_12_Bold.copyWith(color: colors.dangerText);
    Text line(String text, TextStyle style) => Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);

    if (critical != null) {
      title = report.criticalIncidents.isEmpty ? critical.title : t.wallet_health.widget.outgoing_short;
      (iconPath, iconColor, titleColor) = (CommonStateIconPath.siren, colors.danger, colors.dangerText);
      final incident = report.criticalIncidents.length == 1 ? report.criticalIncidents.single : null;
      final txState =
          incident?.txState == IncidentTxState.confirmed
              ? t.wallet_health.incident.tx_state.confirmed
              : t.wallet_health.incident.tx_state.unconfirmed;
      details = [
        if (wide) line(incident == null ? critical.body : '${walletName(incident.walletId)} · $txState', detailStyle),
        if (wide) const SizedBox(height: 6),
        line('${t.wallet_health.incident.review_now} ›', actionStyle),
      ];
    } else if (issues > 0) {
      title = t.wallet_health.summary.items_need_attention(n: issues);
      (iconPath, iconColor, titleColor) = (CommonStateIconPath.triangleWarning, colors.warningText, colors.warningText);
      final first = ([...report.reviewItems]..sort((a, b) => a.severity.index.compareTo(b.severity.index))).first;
      details = [
        if (wide)
          line(
            issues > 1
                ? '${safetyCheckName(first.id)} ${t.wallet_health.widget.more_items(n: issues - 1)}'
                : safetyCheckName(first.id),
            detailStyle,
          ),
        line(lastChecked, detailStyle),
      ];
    } else {
      final scored = report.score != null;
      title = scored ? t.wallet_health.summary.no_issues_found : t.wallet_health.status_chip.up_to_date;
      (iconPath, iconColor, titleColor) = (
        scored ? CommonStateIconPath.shieldCheck : CommonFormIconPath.circleCheck,
        colors.success,
        colors.primaryText,
      );
      final noWallet = report.status == WalletHealthStatus.noWallet;
      details = [
        if (noWallet)
          line(t.wallet_health.widget.no_wallet, detailStyle)
        else ...[
          if (wide)
            line(
              t.wallet_health.widget.checks_count(n: report.allGoodItems.length + report.reviewItems.length),
              detailStyle,
            ),
          line(lastChecked, detailStyle),
        ],
      ];
    }

    Widget icon(double size) => SvgPicture.asset(
      iconPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
    );
    final body =
        wide
            ? Row(
              children: [
                HealthGauge.compact(report: report),
                CoconutLayout.spacing_400w,
                Expanded(
                  child: _ScaleDownColumn(
                    alignment: Alignment.centerLeft,
                    children: [
                      Row(
                        children: [
                          icon(16),
                          CoconutLayout.spacing_150w,
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: CoconutTypography.body2_14_Bold.copyWith(color: titleColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...details,
                    ],
                  ),
                ),
              ],
            )
            : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  // 지갑 카드 2×2의 잔액 자리와 같은 세로 위치
                  child: _ScaleDownColumn(
                    alignment: const Alignment(-1, 0.2),
                    children: [
                      icon(24),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CoconutTypography.body1_16_Bold.copyWith(color: titleColor),
                      ),
                    ],
                  ),
                ),
                details.last,
              ],
            );

    final reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    return Semantics(
      label: t.wallet_health.widget.a11y(status: title),
      excludeSemantics: true,
      child: HomeWidgetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeWidgetHeader(
              iconPath: CommonStateIconPath.shieldCheck,
              title: t.wallet_health.widget.name,
              style: wide ? CoconutTypography.body2_14_Bold : CoconutTypography.body3_12_Bold,
            ),
            SizedBox(height: wide ? 12 : 8),
            Expanded(
              // 동작 줄이기면 전환 없이 바로(켜고 끌 때 새로 그려 이전 전환 시간이 남지 않게)
              child:
                  reduceMotion
                      ? body
                      : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        layoutBuilder:
                            (current, previous) =>
                                Stack(fit: StackFit.expand, children: [...previous, if (current != null) current]),
                        child: KeyedSubtree(key: ValueKey((iconPath, title)), child: body),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 글자 배율·좁은 폭에서 넘치면 통째로 조금 줄인다(줄바꿈은 실제 폭 기준).
class _ScaleDownColumn extends StatelessWidget {
  const _ScaleDownColumn({required this.alignment, required this.children});

  final Alignment alignment;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder:
        (context, constraints) => Align(
          alignment: alignment,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: SizedBox(
              width: constraints.maxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ),
  );
}
