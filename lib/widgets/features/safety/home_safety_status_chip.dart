import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/safety/home_safety_status_resolver.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter_svg/flutter_svg.dart';

/// 홈 앱바 왼쪽 상태칩(아이콘 + 문구 + 꺾쇠). 누르면 Wallet Health.
/// 문구가 0.85배로 줄여도 안 들어가면 짧은 꼴(아이콘·꺾쇠, 조치 필요는 건수만)로 바꾼다. 의미 라벨은 늘 전체 문구.
class HomeSafetyStatusChip extends StatelessWidget {
  /// 아이콘 16 + 간격 6 + 4 + 꺾쇠 6
  static const _chromeWidth = 32.0;

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
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    // 동작 줄이기: 전환 없이 바로 바꾸고, 업데이트 중 표시는 돌지 않는 원호로
    final reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    Widget svg(String path, Color? color) =>
        SvgPicture.asset(path, width: 16, colorFilter: color == null ? null : ColorFilter.mode(color, BlendMode.srcIn));
    final (icon, color) = switch (status.kind) {
      HomeSafetyStatusKind.critical => (svg(CommonStateIconPath.siren, colors.danger), colors.dangerText),
      HomeSafetyStatusKind.connectionProblem => (
        svg(FeatureConnectivityIconPath.cloudDisconnected, null),
        colors.dangerText,
      ),
      HomeSafetyStatusKind.actionNeeded => (
        svg(CommonStateIconPath.triangleWarning, colors.warningText),
        colors.warningText,
      ),
      HomeSafetyStatusKind.reconnected => (svg(CommonFormIconPath.circleCheck, colors.success), colors.success),
      HomeSafetyStatusKind.updating => (
        SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colors.secondaryText,
            value: reduceMotion ? 0.75 : null,
          ),
        ),
        colors.secondaryTextStrong,
      ),
      HomeSafetyStatusKind.noIssues => (
        svg(CommonStateIconPath.shieldCheck, colors.secondaryTextStrong),
        colors.secondaryTextStrong,
      ),
      HomeSafetyStatusKind.upToDate => (
        svg(CommonFormIconPath.circleCheck, colors.secondaryTextStrong),
        colors.secondaryTextStrong,
      ),
    };
    final text = _text;
    final style = CoconutTypography.body3_12_Bold.copyWith(color: color);
    final fits = measureHomeText(context, text, style) * 0.85 <= maxWidth - _chromeWidth;
    final label =
        fits
            ? Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(text, maxLines: 1, style: style),
              ),
            )
            : status.kind == HomeSafetyStatusKind.actionNeeded
            ? Text('${status.count}', maxLines: 1, style: style)
            : null;

    final row = Row(
      key: ValueKey((status, label == null)),
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        if (label != null) ...[CoconutLayout.spacing_150w, label],
        CoconutLayout.spacing_100w,
        SvgPicture.asset(
          CommonNavigationIconPath.arrowRight,
          width: 6,
          height: 10,
          colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
        ),
      ],
    );
    return Semantics(
      button: true,
      label: t.wallet_health.status_chip.a11y(status: text),
      onTap: onTap,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, _tapHeight),
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
