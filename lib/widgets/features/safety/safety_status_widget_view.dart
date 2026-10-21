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
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_score_gauge.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_state_icon.dart';
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
    final time = formatHomeRelativeTime(report.evaluatedAt, DateTime.now());
    final detailStyle = CoconutTypography.body3_12.copyWith(color: colors.secondaryText);
    final health = context.walletHealthColors;
    final actionStyle = CoconutTypography.body3_12_Bold.copyWith(color: health.critical);
    Text line(String text) => Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: detailStyle);
    // 2×2 아래 줄은 좁아서 시간만, 4×2는 "마지막 검사 · 시간"
    final checked = line(wide ? t.wallet_health.summary.last_checked(time: time) : time);

    // 지갑 없음 안내는 여러 줄이 될 수 있어, 2×2에서는 아래 고정 줄이 아니라 제목과 함께 줄어드는 열에 둔다
    // (아래 줄은 높이가 고정이라 320dp·긴 언어에서 넘친다)
    Widget? noWalletLine;
    final String title;
    final String iconPath;
    final Color iconColor, titleColor;
    final List<Widget> details;
    if (critical != null) {
      final incidents = report.criticalIncidents.length;
      final incident = incidents == 1 ? report.criticalIncidents.single : null;
      // 사건 밖 위급은 칩과 같은 말(긴 제목은 4×2 첫 상세 줄로), 4×2의 여러 사건은 건수가 든 제목
      title =
          incidents == 0
              ? t.wallet_health.status_chip.critical
              : wide && incidents > 1
              ? t.wallet_health.incident.outgoing_multiple_title(n: incidents)
              : t.wallet_health.widget.outgoing_short;
      (iconPath, iconColor, titleColor) = (
        FeatureWalletHealthIconPath.lightEmergencyOn,
        health.critical,
        health.critical,
      );
      final txState =
          incident?.txState == IncidentTxState.confirmed
              ? t.wallet_health.incident.tx_state.confirmed
              : t.wallet_health.incident.tx_state.unconfirmed;
      details = [
        if (wide) ...[
          line(
            incidents == 0
                ? critical.title
                : incident == null
                ? critical.body
                : '${walletName(incident.walletId)} · $txState',
          ),
          const SizedBox(height: 6),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                t.wallet_health.incident.review_now,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: actionStyle,
              ),
            ),
            CoconutLayout.spacing_100w,
            SvgPicture.asset(
              CommonNavigationIconPath.arrowRight,
              width: 6,
              height: 10,
              colorFilter: ColorFilter.mode(health.critical, BlendMode.srcIn),
            ),
          ],
        ),
      ];
    } else if (issues > 0) {
      title = t.wallet_health.status_chip.attention(n: issues);
      (iconPath, iconColor, titleColor) = (
        FeatureWalletHealthIconPath.triangleWarningFilled,
        health.warning,
        health.warning,
      );
      final first = ([...report.reviewItems]..sort((a, b) => a.severity.index.compareTo(b.severity.index))).first;
      details = [
        if (wide)
          line(
            issues > 1
                ? '${safetyCheckName(first.id)} ${t.wallet_health.widget.more_items(n: issues - 1)}'
                : safetyCheckName(first.id),
          ),
        checked,
      ];
    } else {
      final scored = report.score != null;
      final noWallet = report.status == WalletHealthStatus.noWallet;
      title = scored ? t.wallet_health.summary.no_issues_found : t.wallet_health.status_chip.up_to_date;
      (iconPath, iconColor, titleColor) = (
        FeatureWalletHealthIconPath.checkCircleFilled,
        // 지갑이 없으면 초록 "정상"이 아니라 중립
        noWallet
            ? colors.iconSecondary
            : report.label == WalletHealthLabel.excellent
            ? health.excellent
            : health.good,
        colors.primaryText,
      );
      if (noWallet) noWalletLine = Text(safetyKoText(t.wallet_health.widget.no_wallet), style: detailStyle);
      details = [
        // 지갑 없음 안내는 말줄임 없이 줄바꿈
        if (noWalletLine != null)
          noWalletLine
        else ...[
          if (wide)
            line(t.wallet_health.widget.checks_count(n: report.allGoodItems.length + report.reviewItems.length)),
          checked,
        ],
      ];
    }

    final body =
        wide
            ? Row(
              children: [
                Expanded(flex: 2, child: Center(child: HealthGauge.compact(report: report, size: 88))),
                CoconutLayout.spacing_300w,
                Expanded(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // 위급이면 게이지 가운데에 이미 사이렌이 있다
                            if (critical == null) ...[
                              safetyStateIcon(iconPath, 20, iconColor),
                              CoconutLayout.spacing_150w,
                            ],
                            Text(
                              safetyKoText(title),
                              maxLines: 1,
                              style: CoconutTypography.body2_14_Bold.copyWith(color: titleColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ...details,
                      ],
                    ),
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
                      safetyStateIcon(iconPath, 32, iconColor),
                      const SizedBox(height: 6),
                      // 한 줄에 안 들어가는 제목은 열 전체를 줄이지 않고 제목만 한 단계 작은 글로 두 줄까지
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final large = CoconutTypography.body1_16_Bold.copyWith(color: titleColor);
                          final fits = measureHomeText(context, title, large) <= constraints.maxWidth;
                          return Text(
                            safetyKoText(title),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: fits ? large : CoconutTypography.body2_14_Bold.copyWith(color: titleColor),
                          );
                        },
                      ),
                      if (noWalletLine != null) ...[const SizedBox(height: 4), noWalletLine],
                    ],
                  ),
                ),
                if (noWalletLine == null) details.last,
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
              iconPath: FeatureWalletHealthIconPath.walletCheck,
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
