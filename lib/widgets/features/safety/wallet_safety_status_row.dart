import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/screens/safety/incident_sheets.dart';
import 'package:coconut_wallet/screens/safety/rescue/rescue_ready_screen.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_screen.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_sheets.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// 지갑 하나의 안전 상태. 지갑 정보 행과 지갑 상세 알약이 같은 판정을 쓴다
enum WalletSafetyState { critical, caution, needsAttention, noIssues, waiting }

typedef WalletSafetyStatus = ({WalletSafetyState state, int count, SafetyIncident? incident});

WalletSafetyStatus walletSafetyStatusOf(SafetyProvider provider, int walletId) {
  final report = provider.report;
  final issues = report?.reviewItems.where((item) => item.walletId == walletId).toList() ?? const [];
  SafetyIncident? incident;
  for (final candidate in report?.criticalIncidents ?? const <SafetyIncident>[]) {
    if (candidate.walletId == walletId) {
      incident = candidate;
      break;
    }
  }
  final count =
      issues
          .where((item) => item.severity == SafetySeverity.actionNeeded || item.severity == SafetySeverity.warning)
          .length;
  final checked =
      (report?.recovery.any((item) => item.walletId == walletId) ?? false) ||
      (report?.allGoodItems.any((item) => item.walletId == walletId) ?? false);
  final state =
      incident != null || issues.any((item) => item.severity == SafetySeverity.critical)
          ? WalletSafetyState.critical
          : provider.isCaution(walletId)
          ? WalletSafetyState.caution
          : count > 0
          ? WalletSafetyState.needsAttention
          : checked
          ? WalletSafetyState.noIssues
          : WalletSafetyState.waiting;
  return (state: state, count: count, incident: incident);
}

String walletSafetyStatusText(WalletSafetyStatus status) {
  final copy = t.wallet_health.wallet_info;
  return switch (status.state) {
    WalletSafetyState.critical => copy.critical,
    WalletSafetyState.caution => copy.caution,
    WalletSafetyState.needsAttention => copy.needs_attention(n: status.count),
    WalletSafetyState.noIssues => copy.no_issues,
    WalletSafetyState.waiting => copy.waiting,
  };
}

class WalletSafetyStatusRow extends StatelessWidget {
  const WalletSafetyStatusRow({super.key, required this.walletId});

  final int walletId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SafetyProvider?>();
    if (provider == null) return const SizedBox.shrink();
    final colors = context.coconutColors;
    final status = walletSafetyStatusOf(provider, walletId);
    final color = switch (status.state) {
      WalletSafetyState.critical || WalletSafetyState.caution => colors.dangerText,
      WalletSafetyState.needsAttention => colors.warningText,
      WalletSafetyState.noIssues => colors.success,
      WalletSafetyState.waiting => colors.secondaryText,
    };
    return _WalletInfoStatusRow(
      key: const Key('wallet-safety-status-row'),
      title: t.wallet_health.wallet_info.safety_status,
      value: walletSafetyStatusText(status),
      valueColor: color,
      onPressed: () => showWalletContributionSheet(context, walletId),
    );
  }
}

/// 지갑 상세 잔액 아래 안전 상태 알약(POLISH §3). 위 간격을 함께 그리고, SafetyProvider가 없으면 둘 다 없다.
/// 위급 사건이면 사건 상세, 위급 점검이면 Wallet Health, 그 밖에는 이 지갑 시트를 연다(마지막 판정을 그대로 보인다)
class WalletSafetyStatusPill extends StatelessWidget {
  const WalletSafetyStatusPill({super.key, required this.walletId, this.onPressed});

  final int walletId;

  /// 열기 전에 부른다(분석 기록)
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SafetyProvider?>();
    if (provider == null) return const SizedBox.shrink();
    final colors = context.coconutColors;
    final status = walletSafetyStatusOf(provider, walletId);
    final text = walletSafetyStatusText(status);
    // 아이콘·글자색은 홈 상태칩과 같은 짝, 바탕만 알약용
    final (icon, iconColor, background, color) = switch (status.state) {
      WalletSafetyState.critical => (CommonStateIconPath.siren, colors.danger, colors.dangerSurface, colors.dangerText),
      WalletSafetyState.caution => (
        CommonStateIconPath.triangleWarning,
        colors.danger,
        colors.dangerSurface,
        colors.dangerText,
      ),
      WalletSafetyState.needsAttention => (
        CommonStateIconPath.triangleWarning,
        colors.warningText,
        colors.warningSurface,
        colors.warningText,
      ),
      WalletSafetyState.noIssues => (
        CommonStateIconPath.shieldCheck,
        colors.secondaryTextStrong,
        colors.surfaceInfoChip,
        colors.secondaryTextStrong,
      ),
      WalletSafetyState.waiting => (
        CommonStateIconPath.shieldCheck,
        colors.iconSecondary,
        colors.surfaceInfoChip,
        colors.secondaryTextStrong,
      ),
    };
    void open() {
      onPressed?.call();
      final incident = status.incident;
      if (status.state != WalletSafetyState.critical) {
        showWalletContributionSheet(context, walletId);
      } else if (incident != null) {
        openSafetyIncident(context, walletId: walletId, txid: incident.txid);
      } else {
        WalletHealthScreen.open(context);
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoconutLayout.spacing_300h,
        Center(
          child: Semantics(
            button: true,
            excludeSemantics: true,
            label: t.wallet_health.status_chip.a11y(status: text),
            onTap: open,
            // 알약 위아래 6도 누를 수 있게 해 누르는 높이를 44 이상으로(POLISH R7). 알약 위의 탭은 알약 버튼이 받는다
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: open,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ShrinkAnimationButton(
                  key: const Key('wallet-safety-status-pill'),
                  defaultColor: background,
                  pressedOverlayColor: colors.surfacePressOverlay,
                  pressedOverlayOpacity: colors.surfacePressOverlayOpacity,
                  borderRadius: 16,
                  onPressed: open,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // TODO(E7): 홈 칩과 같은 safetyStateIcon으로 바꾸기(triangle 광학 크기)
                        SvgPicture.asset(
                          icon,
                          width: 16,
                          height: 16,
                          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                        ),
                        CoconutLayout.spacing_150w,
                        Text(
                          '${t.wallet_health.wallet_info.safety_status} · ',
                          style: CoconutTypography.body3_12.setColor(color),
                        ),
                        Flexible(
                          child: Text(
                            text,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: CoconutTypography.body3_12_Bold.setColor(color),
                          ),
                        ),
                        CoconutLayout.spacing_100w,
                        SvgPicture.asset(
                          CommonNavigationIconPath.arrowRight,
                          width: 6,
                          height: 10,
                          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class WalletRescueDestinationRow extends StatelessWidget {
  const WalletRescueDestinationRow({super.key, required this.walletId});

  final int walletId;

  @override
  Widget build(BuildContext context) {
    final entitlement = context.watch<EntitlementService?>();
    final rescue = context.watch<RescueReadyProvider?>();
    if (entitlement == null || rescue == null) return const SizedBox.shrink();
    return ValueListenableBuilder<PremiumState>(
      valueListenable: entitlement.state,
      builder: (context, state, _) {
        if (!state.isActive && rescue.destinationOf(walletId) == null) return const SizedBox.shrink();
        return _WalletInfoStatusRow(
          key: const Key('wallet-rescue-destination-row'),
          title: t.premium.rescue.destination,
          value: rescue.destinationLabel(walletId) ?? t.premium.rescue.not_set,
          valueColor: context.coconutColors.secondaryText,
          onPressed: () => RescueReadyScreen.open(context, walletId: walletId),
        );
      },
    );
  }
}

class _WalletInfoStatusRow extends StatelessWidget {
  const _WalletInfoStatusRow({
    super.key,
    required this.title,
    required this.value,
    required this.valueColor,
    required this.onPressed,
  });

  final String title, value;
  final Color valueColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return ShrinkAnimationButton(
      defaultColor: Colors.transparent,
      pressedOverlayColor: colors.primaryText,
      pressedOverlayOpacity: 0.08,
      borderRadius: 12,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            Expanded(child: Text(title, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText))),
            CoconutLayout.spacing_200w,
            // 값과 화살표는 위 니모닉 백업 행처럼 오른쪽 끝(느슨한 Flexible이면 줄 가운데에 멈춘다)
            Expanded(
              child: Text(value, textAlign: TextAlign.end, style: CoconutTypography.body2_14.setColor(valueColor)),
            ),
            CoconutLayout.spacing_100w,
            Icon(Icons.keyboard_arrow_right_rounded, color: colors.iconSecondary),
          ],
        ),
      ),
    );
  }
}
