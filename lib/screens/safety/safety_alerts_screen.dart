import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/screens/safety/incident_sheets.dart';
import 'package:coconut_wallet/screens/safety/security_guide_screen.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart' show formatHomeRelativeTime;
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_health_cards.dart' show SafetyPressRow, SafetyReviewRow;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// 🔔 알림 목록: 보안 경고(열린 사건) · 확인할 항목 · 지난 알림(인지함·대응 완료).
/// 들어오면 경로 전환이 끝난 뒤 보이는 항목을 읽음으로 바꾸고, 읽지 않음 점은 220ms에 걸쳐 사라진다
class SafetyAlertsScreen extends StatefulWidget {
  const SafetyAlertsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    CupertinoPageRoute<void>(
      settings: const RouteSettings(name: '/wallet-health/alerts'),
      builder: (_) => const SafetyAlertsScreen(),
    ),
  );

  @override
  State<SafetyAlertsScreen> createState() => _SafetyAlertsScreenState();
}

class _SafetyAlertsScreenState extends State<SafetyAlertsScreen> {
  Set<String>? _unreadAtOpen;
  bool _dotsVisible = true;
  VoidCallback? _cancelWait;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_unreadAtOpen != null) return;
    final items = context.read<SafetyProvider?>()?.alertItems ?? const [];
    _unreadAtOpen = {
      for (final item in items)
        if (item.unread) item.key,
    };
    _cancelWait = whenRouteSettled(context, _markRead);
  }

  /// 읽음 저장이 끝난 뒤에만 점을 지운다. 실패하면 점을 그대로 둔다(제공자 상태와 맞춤)
  Future<void> _markRead() async {
    if (!mounted) return;
    final provider = context.read<SafetyProvider?>();
    if (provider == null) return;
    try {
      await provider.markAlertsRead();
    } catch (_) {
      return;
    }
    if (mounted) setState(() => _dotsVisible = false);
  }

  @override
  void dispose() {
    _cancelWait?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final strings = t.wallet_health.alerts;
    final provider = context.watch<SafetyProvider?>();
    final incidents = [...?provider?.state.incidents]..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    // 보안 경고는 위급 사건만. 멤풀에서 사라진 사건·인지함·완료는 지난 알림
    final open = incidents.where((i) => i.isCritical).toList();
    final earlier = incidents.where((i) => !i.isCritical).toList();
    // 확인할 항목은 보고서의 검토 항목 전부(경고 포함). 읽지 않음 점은 위급 사건만 쓴다
    final checks = [
      for (final check in provider?.report?.reviewItems ?? const <SafetyCheckResult>[])
        if (check.id != SafetyCheckId.unrecognizedOutgoing) check,
    ];
    final now = DateTime.now();
    Widget incidentCard(List<SafetyIncident> list) => SafetyListCard(
      rows: [
        for (final incident in list)
          _IncidentRow(
            incident: incident,
            now: now,
            // 읽지 않음 점은 위급 사건만(인지함·완료·사라짐은 세지 않는다)
            showDot: incident.isCritical && _unreadAtOpen!.contains('incident:${incident.id}'),
            dotVisible: _dotsVisible,
          ),
      ],
    );

    return Scaffold(
      key: const Key('safety-alerts-screen'),
      backgroundColor: colors.homeBackground,
      appBar: CoconutAppBar.build(context: context, title: strings.title, backgroundColor: colors.homeBackground),
      body:
          open.isEmpty && earlier.isEmpty && checks.isEmpty
              ? const _EmptyAlerts()
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (open.isNotEmpty) ...[SafetySectionTitle(strings.section_security, top: 8), incidentCard(open)],
                  // 검토 행은 Wallet Health와 같다(Track C)
                  if (checks.isNotEmpty) ...[
                    SafetySectionTitle(strings.section_attention, top: open.isEmpty ? 8 : 32),
                    SafetyListCard(rows: [for (final check in checks) SafetyReviewRow(check: check)]),
                  ],
                  if (earlier.isNotEmpty) ...[
                    SafetySectionTitle(strings.section_earlier, top: open.isEmpty && checks.isEmpty ? 8 : 32),
                    incidentCard(earlier),
                  ],
                ],
              ),
    );
  }
}

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({required this.incident, required this.now, required this.showDot, required this.dotVisible});

  final SafetyIncident incident;
  final DateTime now;
  final bool showDot;
  final bool dotVisible;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final states = t.wallet_health.incident.state;
    final txStates = t.wallet_health.incident.tx_state;
    final txState = switch (incident.txState) {
      IncidentTxState.pending => txStates.unconfirmed,
      IncidentTxState.confirmed => txStates.confirmed,
      IncidentTxState.replaced => txStates.replaced,
      IncidentTxState.dropped => txStates.dropped,
    };
    // (아이콘 바탕, 아이콘, 아이콘 색, 칩 글, 칩 글색, 칩 바탕)
    final (iconBackground, iconPath, iconColor, chip, chipColor, chipBackground) = switch (incident.state) {
      IncidentState.recognized => (
        colors.successSurface,
        CommonStateIconPath.shieldCheck,
        colors.success,
        states.recognized,
        colors.success,
        colors.successSurface,
      ),
      IncidentState.completed => (
        colors.surfaceMuted,
        CommonFormIconPath.circleCheck,
        colors.iconSecondary,
        states.completed,
        colors.secondaryText,
        colors.surfaceInfoChip,
      ),
      _ when incident.isInfo => (
        colors.surfaceMuted,
        CommonStateIconPath.circleInfo,
        colors.iconSecondary,
        states.dropped,
        colors.secondaryText,
        colors.surfaceInfoChip,
      ),
      IncidentState.responding => (
        colors.dangerSurface,
        CommonStateIconPath.siren,
        colors.danger,
        states.responding,
        colors.warningText,
        colors.warningSurface,
      ),
      IncidentState.detected => (
        colors.dangerSurface,
        CommonStateIconPath.siren,
        colors.danger,
        states.detected,
        colors.dangerText,
        colors.dangerSurface,
      ),
    };
    final walletName = incidentWalletOf(context, incident.walletId)?.name;
    final subtitle = [
      if (walletName != null) walletName,
      // 멤풀에서 사라진 사건은 "다음 동기화 때 다시 확인", 대체됐으면 끝에 "· 대체됨"
      if (incident.isInfo) ...[
        t.wallet_health.incident.dropped_subtitle,
        if (incident.txState == IncidentTxState.replaced) txStates.replaced,
      ] else ...[
        if (incident.txState != IncidentTxState.dropped) txState,
        t.wallet_health.alerts.detected_at(time: formatHomeRelativeTime(incident.detectedAt, now)),
      ],
    ].join(' · ');

    return SafetyPressRow(
      key: Key('safety-alert-incident-${incident.id}'),
      background: colors.homeSurface,
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: LayoutBuilder(
          builder:
              (context, constraints) => Row(
                children: [
                  SafetyIconCircle(
                    size: 36,
                    background: iconBackground,
                    icon: SvgPicture.asset(
                      iconPath,
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    ),
                  ),
                  CoconutLayout.spacing_300w,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Padding(
                              // 점 자리(오른쪽 -8)가 글자와 겹치지 않게
                              padding: EdgeInsets.only(right: showDot ? 10 : 0),
                              child: Text(
                                safetyKoText(
                                  incident.isInfo
                                      ? t.wallet_health.incident.dropped_title
                                      : t.wallet_health.incident.outgoing_title,
                                ),
                                style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText),
                              ),
                            ),
                            if (showDot)
                              Positioned(
                                top: -1,
                                right: 0,
                                child: AnimatedOpacity(
                                  key: Key('safety-alert-unread-${incident.id}'),
                                  opacity: dotVisible ? 1 : 0,
                                  duration:
                                      safetyReduceMotion(context) ? Duration.zero : const Duration(milliseconds: 220),
                                  child: Semantics(
                                    label: t.wallet_health.alerts.unread_a11y,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(color: colors.danger, shape: BoxShape.circle),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        CoconutLayout.spacing_50h,
                        Text(safetyKoText(subtitle), style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
                      ],
                    ),
                  ),
                  CoconutLayout.spacing_200w,
                  // 상태 칩은 줄 폭의 35%까지(긴 독일어·큰 글자면 가운데 정렬로 줄을 바꾼다). 제목 열은 남는 폭을 다 받는다
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.35),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: chipBackground,
                        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
                      ),
                      child: Text(
                        chip,
                        textAlign: TextAlign.center,
                        style: CoconutTypography.caption_10_Bold.setColor(chipColor),
                      ),
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    if (incident.state == IncidentState.responding && !incident.isInfo) {
      SecurityGuide.resume(context, incident.id);
      return;
    }
    openSafetyIncident(
      context,
      walletId: incident.walletId,
      txid: incident.txid,
      autoReview: incident.state == IncidentState.detected && incident.isCritical,
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final strings = t.wallet_health.alerts;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          key: const Key('safety-alerts-empty'),
          mainAxisSize: MainAxisSize.min,
          children: [
            SafetyIconCircle(
              size: 72,
              background: colors.homeSurface,
              icon: SvgPicture.asset(
                CommonCommunicationIconPath.boldBell,
                width: 32,
                height: 32,
                colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
              ),
            ),
            CoconutLayout.spacing_500h,
            Text(
              safetyKoText(strings.empty_title),
              textAlign: TextAlign.center,
              style: CoconutTypography.heading3_21_Bold.setColor(colors.primaryText),
            ),
            CoconutLayout.spacing_200h,
            Text(
              safetyKoText(strings.empty_body),
              textAlign: TextAlign.center,
              style: CoconutTypography.body2_14.setColor(colors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}
