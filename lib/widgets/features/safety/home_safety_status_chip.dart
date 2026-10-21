import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/services/safety/home_safety_status_resolver.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_state_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter_svg/flutter_svg.dart';

/// 홈 앱바 왼쪽 상태칩(아이콘 + 문구 + 꺾쇠). 누르면 Wallet Health.
/// 글자 크기는 시스템 글꼴 배율과 관계없이 고정, 문구가 안 들어가면 짧은 꼴(아이콘·꺾쇠, 조치 필요는 건수만)로 바꾼다.
/// 의미 라벨은 늘 전체 문구.
class HomeSafetyStatusChip extends StatelessWidget {
  /// 아이콘 18 + 간격 4 + 8 + 꺾쇠 6
  static const _chromeWidth = 36.0;

  /// 앱바 leading 슬롯(56 - 위아래 8)을 꽉 채운 누름 높이. UI_SPEC의 44보다 작지만 더 키우면 글자 2배에서 앱바가 넘친다(WCAG 2.2 최소 24는 넘음, lead 확인)
  static const _tapHeight = 40.0;

  const HomeSafetyStatusChip({super.key, required this.status, required this.maxWidth, this.onTap});

  final HomeSafetyStatus status;
  final double maxWidth;
  final VoidCallback? onTap;

  String get _text => switch (status.kind) {
    HomeSafetyStatusKind.critical => t.wallet_health.status_chip.critical,
    // 긴 원문(errorMessage)은 Wallet Health 연결 안내에서 보여 주고, 칩에는 짧은 문구만
    HomeSafetyStatusKind.connectionProblem => switch (status.networkStatus) {
      NetworkStatus.offline => t.wallet_health.status_chip.offline,
      NetworkStatus.vpnBlocked => t.wallet_health.status_chip.vpn,
      _ => t.wallet_health.status_chip.connection_failed,
    },
    HomeSafetyStatusKind.actionNeeded => t.wallet_health.status_chip.attention(n: status.count),
    HomeSafetyStatusKind.reconnected => t.wallet_health.status_chip.reconnected,
    HomeSafetyStatusKind.updating => t.status_updating,
    HomeSafetyStatusKind.noIssues => t.wallet_health.summary.no_issues_found,
    HomeSafetyStatusKind.upToDate => t.wallet_health.status_chip.up_to_date,
  };

  @override
  Widget build(BuildContext context) => MediaQuery.withNoTextScaling(
    child: LayoutBuilder(builder: (context, constraints) => _build(context, math.min(maxWidth, constraints.maxWidth))),
  );

  Widget _build(BuildContext context, double maxWidth) {
    final colors = context.coconutColors;
    // 동작 줄이기: 전환 없이 바로 바꾸고, 업데이트 중 표시는 돌지 않는 원호로
    final reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    final health = context.walletHealthColors;
    final okColor = status.label == WalletHealthLabel.excellent ? health.excellent : health.good;
    Widget svg(String path, Color? color) => safetyStateIcon(path, 18, color);
    final (icon, color) = switch (status.kind) {
      HomeSafetyStatusKind.critical => (
        svg(FeatureWalletHealthIconPath.lightEmergencyOn, health.critical),
        health.critical,
      ),
      HomeSafetyStatusKind.connectionProblem => (
        svg(FeatureConnectivityIconPath.cloudDisconnected, null),
        colors.dangerText,
      ),
      HomeSafetyStatusKind.actionNeeded => (
        svg(FeatureWalletHealthIconPath.triangleWarningFilled, health.warning),
        health.warning,
      ),
      HomeSafetyStatusKind.reconnected => (svg(CommonFormIconPath.circleCheck, colors.success), colors.success),
      HomeSafetyStatusKind.updating => (
        // 16 상자 안의 14: 다른 상태로 바뀔 때 글이 옆으로 튀지 않게
        SizedBox.square(
          dimension: 18,
          child: Center(
            child: SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.secondaryText,
                value: reduceMotion ? 0.75 : null,
              ),
            ),
          ),
        ),
        colors.secondaryTextStrong,
      ),
      HomeSafetyStatusKind.noIssues => (svg(FeatureWalletHealthIconPath.checkCircleFilled, okColor), okColor),
      HomeSafetyStatusKind.upToDate => (
        svg(CommonFormIconPath.circleCheck, colors.secondaryTextStrong),
        colors.secondaryTextStrong,
      ),
    };
    final text = _text;
    final style = CoconutTypography.body2_14_Bold.copyWith(
      color: color,
      leadingDistribution: TextLeadingDistribution.even,
    );
    final fits = measureHomeText(context, text, style) <= maxWidth - _chromeWidth;
    final label =
        fits
            ? Text(text, maxLines: 1, style: style)
            : status.kind == HomeSafetyStatusKind.actionNeeded
            ? Text('${status.count}', maxLines: 1, style: style)
            : null;

    final row = FittedBox(
      key: ValueKey((status, label == null)),
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          if (label != null) ...[CoconutLayout.spacing_100w, label],
          if (status.kind != HomeSafetyStatusKind.updating) ...[
            CoconutLayout.spacing_200w,
            SvgPicture.asset(
              CommonNavigationIconPath.arrowRight,
              width: 6,
              height: 10,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      button: true,
      label: t.wallet_health.status_chip.a11y(status: text),
      onTap: onTap,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, _tapHeight), // 짧은 꼴도 터치 폭 44
        pressedOpacity: 0.5,
        alignment: Alignment.centerLeft,
        onPressed:
            onTap == null
                ? null
                : () {
                  vibrateExtraLight();
                  onTap!();
                },
        child:
            reduceMotion
                ? row
                : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  // 가운데 정렬이면 폭이 다른 상태끼리 바뀔 때 좌우로 흔들린다
                  layoutBuilder:
                      (current, previous) =>
                          Stack(alignment: Alignment.centerLeft, children: [...previous, if (current != null) current]),
                  child: row,
                ),
      ),
    );
  }
}
