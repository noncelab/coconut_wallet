import 'dart:async';

import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/screens/safety/incident_sheets.dart';
import 'package:coconut_wallet/screens/safety/safety_alerts_screen.dart';
import 'package:coconut_wallet/screens/safety/security_guide_screen.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _BannerVariant { unreviewed, recognized, responding, completed, info }

/// 거래 상세 맨 위 사건 배너(검토 전 · 인지함 · 대응 중 · 대응 끝남 · 멤풀에서 사라짐).
/// 사건 거래가 아니거나 SafetyProvider가 없으면 아무것도 그리지 않는다
class TransactionSafetyBanner extends StatefulWidget {
  const TransactionSafetyBanner({super.key, required this.walletId, required this.txHash});

  final int walletId;
  final String txHash;

  @override
  State<TransactionSafetyBanner> createState() => _TransactionSafetyBannerState();
}

class _TransactionSafetyBannerState extends State<TransactionSafetyBanner> {
  bool _autoReviewChecked = false;
  VoidCallback? _cancelWait;
  Timer? _autoReviewTimer;

  @override
  void dispose() {
    _cancelWait?.call();
    _autoReviewTimer?.cancel();
    super.dispose();
  }

  /// openSafetyIncident로 들어왔으면 경로 전환이 끝나고 300ms 뒤 인지 시트를 띄운다.
  /// 사건이 아직 없는 기준점 대기 출금도 같은 시트를 띄운다(배너는 그리지 않음)
  void _checkAutoReview(SafetyIncident? incident) {
    if (_autoReviewChecked) return;
    _autoReviewChecked = true;
    if (incident != null && incident.state != IncidentState.detected) return;
    if (!takeIncidentAutoReview('${widget.walletId}:${widget.txHash}')) return;
    _cancelWait = whenRouteSettled(context, _scheduleAutoReview);
  }

  void _scheduleAutoReview() {
    if (!mounted) return;
    _autoReviewTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      final incident = incidentOrPending(context, widget.walletId, widget.txHash);
      if (incident.state == IncidentState.detected) showRecognizeSheet(context, incident);
    });
  }

  static _BannerVariant _variantOf(SafetyIncident incident) => switch (incident.state) {
    IncidentState.recognized => _BannerVariant.recognized,
    IncidentState.completed => _BannerVariant.completed,
    // 열린 사건의 거래가 사라지면(대체·추방) 위급이 풀린다. 대응 중이어도 정보 배너
    _ when incident.isInfo => _BannerVariant.info,
    IncidentState.responding => _BannerVariant.responding,
    IncidentState.detected => _BannerVariant.unreviewed,
  };

  @override
  Widget build(BuildContext context) {
    final incident = context.select<SafetyProvider?, SafetyIncident?>(
      (provider) => provider?.incidentFor(widget.walletId, widget.txHash),
    );
    final isCaution = context.select<SafetyProvider?, bool>(
      (provider) => provider?.isCaution(widget.walletId) ?? false,
    );
    // 같은 지갑에 아직 위급한 다른 출금이 있음(예: 이 거래를 대체한 상대의 거래)
    final hasOtherOutgoing = context.select<SafetyProvider?, bool>(
      (provider) =>
          provider?.state.incidents.any(
            (i) => i.walletId == widget.walletId && i.txid != widget.txHash && i.isCritical,
          ) ??
          false,
    );
    _checkAutoReview(incident);
    final variant = incident == null ? null : _variantOf(incident);
    final duration = safetyReduceMotion(context) ? Duration.zero : const Duration(milliseconds: 300);
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        // 배너가 바뀌는 동안 두 배너를 위에 맞춰 겹친다(가운데 정렬이면 높이가 다를 때 위치가 튄다)
        layoutBuilder:
            (current, previous) =>
                Stack(alignment: Alignment.topCenter, children: [...previous, if (current != null) current]),
        child:
            variant == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                  key: Key('transaction-safety-banner-${variant.name}'),
                  // 배너 아래 간격(spacing_500h)까지 이 위젯이 그린다
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _banner(context, incident!, variant, isCaution: isCaution, hasOtherOutgoing: hasOtherOutgoing),
                ),
      ),
    );
  }

  Widget _banner(
    BuildContext context,
    SafetyIncident incident,
    _BannerVariant variant, {
    required bool isCaution,
    required bool hasOtherOutgoing,
  }) {
    final responding = incident.state == IncidentState.responding;
    final colors = context.coconutColors;
    final strings = t.safety_guide.tx_banner;
    return switch (variant) {
      _BannerVariant.unreviewed => SafetyStatusBanner(
        background: colors.dangerSurface,
        iconPath: CommonStateIconPath.triangleWarning,
        iconColor: colors.danger,
        title: strings.unreviewed_title,
        body: strings.unreviewed_body,
        linkText: strings.review,
        onLink: () => showRecognizeSheet(context, incident),
      ),
      _BannerVariant.recognized => SafetyStatusBanner(
        background: colors.successSurface,
        iconPath: CommonStateIconPath.shieldCheck,
        iconColor: colors.success,
        title: strings.recognized_title,
        body: strings.recognized_body,
      ),
      _BannerVariant.responding => SafetyStatusBanner(
        background: colors.dangerSurface,
        iconPath: CommonStateIconPath.triangleWarning,
        iconColor: colors.danger,
        title: strings.responding_title,
        body: strings.responding_body,
        linkText: strings.continue_guide,
        onLink: () => SecurityGuide.resume(context, incident.id),
      ),
      _BannerVariant.completed => SafetyStatusBanner(
        background: colors.surface,
        iconPath: CommonFormIconPath.circleCheck,
        iconColor: colors.iconSecondary,
        title: t.safety_guide.complete.title,
        body: isCaution ? strings.completed_body : strings.completed_body_unmarked,
        linkText: strings.review_guide,
        onLink: () => SecurityGuide.resume(context, incident.id),
      ),
      _BannerVariant.info => SafetyStatusBanner(
        background: colors.surface,
        iconPath: CommonStateIconPath.circleInfo,
        iconColor: colors.iconSecondary,
        title: strings.dropped_title,
        // "다음 동기화 때 다시 확인"이 해결처럼 들리지 않게, 남은 위급 출금이 있으면 알리고 알림 목록으로
        body: hasOtherOutgoing ? '${strings.dropped_body}\n${strings.dropped_other_outgoing}' : strings.dropped_body,
        // 그다음 대응 중이던 사건은 가이드를 이어 갈 길을 남긴다
        linkText:
            hasOtherOutgoing
                ? strings.view_alerts
                : responding
                ? strings.continue_guide
                : null,
        onLink:
            hasOtherOutgoing
                ? () => SafetyAlertsScreen.open(context)
                : responding
                ? () => SecurityGuide.resume(context, incident.id)
                : null,
      ),
    };
  }
}
