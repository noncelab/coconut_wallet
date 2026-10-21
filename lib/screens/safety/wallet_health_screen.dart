import 'package:coconut_design_system/coconut_design_system.dart'
    show CoconutLayout, CoconutTypography, TextColorExtension;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_screen.dart';
import 'package:coconut_wallet/screens/premium/premium_paywall_screen.dart';
import 'package:coconut_wallet/screens/premium/premium_subscription_screen.dart';
import 'package:coconut_wallet/screens/safety/assist/safety_assist_screen.dart';
import 'package:coconut_wallet/screens/safety/incident_sheets.dart';
import 'package:coconut_wallet/screens/safety/rescue/rescue_ready_screen.dart';
import 'package:coconut_wallet/screens/safety/safety_alerts_screen.dart';
import 'package:coconut_wallet/screens/safety/security_guide_screen.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_sheets.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_score_gauge.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_health_cards.dart';
import 'package:coconut_wallet/widgets/features/transaction/card/transaction_item_card.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// Wallet Health(지갑 상태): 게이지 · 카테고리 2×2 · 검토 필요 · Premium · 정상 항목 · 권장 점검.
/// 위급 사건이 있으면 점수 대신 사건이 먼저 온다(WH-S3).
class WalletHealthScreen extends StatefulWidget {
  const WalletHealthScreen({super.key, this.startCheck = false});

  /// 진입 직후 다시 검사(안전 점검 바로가기·모든 기능)
  final bool startCheck;

  static Future<void> open(BuildContext context, {bool startCheck = false}) => Navigator.of(context).push(
    CupertinoPageRoute<void>(
      settings: const RouteSettings(name: '/wallet-health'),
      builder: (_) => WalletHealthScreen(startCheck: startCheck),
    ),
  );

  @override
  State<WalletHealthScreen> createState() => _WalletHealthScreenState();
}

class _WalletHealthScreenState extends State<WalletHealthScreen> {
  /// 깜빡임 방지(지갑 상세 당겨서 새로고침과 같은 값)
  static const _minimumCheckingDuration = Duration(milliseconds: 700);

  bool _checking = false;
  VoidCallback? _cancelSettle;
  final _scroll = ScrollController();

  /// 직전 빌드가 위급 배치였는지(위급으로 바뀌는 순간을 안다)
  bool _wasCritical = false;

  @override
  void initState() {
    super.initState();
    if (widget.startCheck) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SafetyProvider?>()?.refresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 바로가기·모든 기능: 화면 전환이 끝난 뒤 곧바로 다시 검사
    if (widget.startCheck && _cancelSettle == null) _cancelSettle = whenRouteSettled(context, _checkAgain);
  }

  @override
  void dispose() {
    _cancelSettle?.call();
    _scroll.dispose();
    super.dispose();
  }

  /// 보고서가 위급으로 바뀌면 맨 위로 올린다(POLISH X12). 검토 행처럼 깊이 내려간 자리에 그대로 있으면
  /// 사이렌 머리와 [검토] 버튼이 화면 밖에 남는다(예: 불일치를 확정하고 돌아왔을 때)
  void _followCritical(bool critical) {
    if (critical && !_wasCritical) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients || _scroll.offset <= 0) return;
        if (safetyReduceMotion(context)) {
          _scroll.jumpTo(0);
        } else {
          _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
        }
      });
    }
    _wasCritical = critical;
  }

  /// 다시 검사: 버튼·당겨서 새로고침·바로가기. 분석 이벤트는 provider가 남긴다
  Future<void> _checkAgain() async {
    final provider = context.read<SafetyProvider?>();
    if (provider == null || _checking) return;
    vibrateExtraLight();
    setState(() => _checking = true);
    final stopwatch = Stopwatch()..start();
    var failed = false;
    try {
      await provider.checkAgain();
    } catch (_) {
      failed = true;
    }
    final remaining = _minimumCheckingDuration - stopwatch.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (!mounted) return;
    setState(() => _checking = false);
    if (failed) {
      vibrateLightDouble();
      // 실패는 경고 토스트(지갑 상세의 요청 실패와 같은 모양)
      CoconutToast.showToast(
        context: context,
        text: t.wallet_health.toast.check_failed,
        isVisibleIcon: true,
        iconPath: CommonStateIconPath.triangleWarning,
        level: CoconutToastLevel.warning,
      );
      return;
    }
    vibrateLight();
    if (provider.report?.isConnected == false) {
      CoconutToast.showToast(
        context: context,
        text: t.wallet_health.toast.checked_offline,
        isVisibleIcon: true,
        iconPath: CommonStateIconPath.circleInfo,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final provider = context.watch<SafetyProvider?>();
    final report = provider?.report;
    // checkAgain은 provider가 1.2초 이상 검사 중으로 둔다(백그라운드 refresh는 검사 중 표시 없음)
    final checking = _checking || (provider?.isChecking ?? false) || report == null;
    _followCritical(report?.isCritical ?? false);
    return Scaffold(
      key: const Key('wallet-health-screen'),
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(
        context: context,
        title: t.wallet_health.title,
        backgroundColor: colors.background,
        actionButtonList: [
          CoconutAppBarActionButton(
            buttonKey: const Key('wallet-health-info'),
            tooltip: t.wallet_health.hero.info_a11y,
            onPressed: () => showWalletHealthAboutSheet(context),
            icon: SvgPicture.asset(
              CommonStateIconPath.circleInfo,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 진행 표시는 게이지 스윕이 대신한다. 위급(S3) 머리는 사이렌이라 스윕이 없어 기본 당김 표시를 쓴다(POLISH C15)
            CupertinoSliverRefreshControl(
              onRefresh: _checkAgain,
              refreshTriggerPullDistance: 80,
              builder:
                  report?.isCritical ?? false
                      ? CupertinoSliverRefreshControl.buildRefreshIndicator
                      : (_, _, _, _, _) => const SizedBox.shrink(),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              sliver: SliverList.list(
                children:
                    report != null && report.isCritical
                        ? _criticalSections(report, checking)
                        : _sections(report, checking),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// WH-S0 지갑 없음 · S4 데이터 부족 · S1 점수 + 조치 · S2 모두 양호
  List<Widget> _sections(WalletHealthReport? report, bool checking) {
    final status = report?.status;
    final noWallet = status == WalletHealthStatus.noWallet;
    final waiting = noWallet || status == WalletHealthStatus.notEnoughData;
    final s = t.wallet_health.section;
    final colors = context.coconutColors;
    final notIncluded = _waitingChecks(report);
    return [
      WalletHealthHeaderCard(
        report: report,
        isChecking: checking,
        onCheckAgain: _checkAgain,
        onAddWallet: () => WalletAddScreen.openByWalletCount(context),
        offlineCause: report != null && !report.isConnected ? _offlineCause() : null,
      ),
      if (waiting) ...[
        CoconutLayout.spacing_400h,
        Text(
          safetyKoText(noWallet ? t.wallet_health.hero.no_wallet_body : t.wallet_health.hero.not_enough_data_body),
          textAlign: TextAlign.center,
          style: CoconutTypography.body2_14.setColor(colors.secondaryText),
        ),
        if (!noWallet) ...[
          CoconutLayout.spacing_100h,
          Center(
            child: CoconutUnderlinedButton(
              text: t.wallet_health.hero.how_score_works,
              onTap: () => showWalletHealthAboutSheet(context),
              textStyle: CoconutTypography.body3_12_Bold,
              defaultColor: colors.secondaryTextStrong,
            ),
          ),
        ],
      ],
      CoconutLayout.spacing_400h,
      WalletHealthCategoryGrid(
        report: report,
        isChecking: checking,
        onTap: (category) => showSafetyCategorySheet(context, category),
      ),
      if (report != null) ...[
        ..._reviewSection(report),
        // 판매 카드는 지갑이 없을 때(S0)만 뺀다. S4에서도 Premium 줄과 비상 이동 준비(자금 없음 상태 포함)를 연다
        if (!noWallet && context.read<EntitlementService?>() != null)
          ..._premiumSection(notEnoughData: status == WalletHealthStatus.notEnoughData),
        if (_passedChecks(report) case final passed when passed.isNotEmpty) ...[
          SafetySectionTitle(waiting ? s.available_now : s.all_good),
          SafetyListCard(rows: [for (final item in passed) SafetyPassedRow(item: item)]),
        ],
        if (noWallet) ...[
          // 브리프 §3.4의 네 줄, 이 순서로(C41). 복구 준비는 점검이 아니라 카테고리 이름 한 줄
          SafetySectionTitle(s.after_adding_wallet),
          WalletHealthNotIncludedCard(
            names: safetyNoWalletCheckNames(),
            showReasons: false,
            footer: s.not_included_footer_no_wallet,
          ),
          // "더 많은 점검을 하려면"은 지갑이 없을 때만(UI 브리프 WH-S0)
          CoconutLayout.spacing_800h,
          const WalletHealthUnlockCard(),
        ] else if (waiting && notIncluded.isNotEmpty) ...[
          SafetySectionTitle(s.not_included_yet),
          WalletHealthNotIncludedCard(items: notIncluded, footer: s.not_included_footer_usage),
        ],
        ..._recommendedSection(report),
      ],
    ];
  }

  /// 오프라인 원인. 홈 상태칩(HomeConnectionStatusViewModel)과 같은 갈래: 인터넷 없음 → 네트워크 끊김,
  /// VPN 켜짐 → VPN 확인, 그 밖에는 연결 실패. 칩의 뷰모델은 홈 화면 안에만 있어 여기서는 연결 상태를 직접 읽는다
  String? _offlineCause() {
    final connectivity = context.watch<ConnectivityProvider?>();
    if (connectivity == null) return null;
    final chip = t.wallet_health.status_chip;
    if (connectivity.isInternetOff) return chip.offline;
    if (connectivity.isVpnActive) return chip.vpn;
    return chip.connection_failed;
  }

  /// "정상 항목": 점검 종류별 한 줄. 같은 점검이 어느 지갑에서든 검토 필요면 두지 않는다(모든 지갑이 통과해야 정상, C40)
  List<SafetyCheckResult> _passedChecks(WalletHealthReport report) {
    final failing = {for (final r in report.reviewItems) r.id};
    return _uniqueById([
      for (final item in report.allGoodItems)
        if (!failing.contains(item.id)) item,
    ]);
  }

  /// 지갑이 생기거나 쓰기 시작하면 자동으로 들어오는 점검(점검 종류별 한 줄)
  List<SafetyCheckResult> _waitingChecks(WalletHealthReport? report) => _uniqueById([
    for (final r in report?.notIncluded ?? const <SafetyCheckResult>[])
      if (const {
        NotApplicableReason.noWallet,
        NotApplicableReason.noFunds,
        NotApplicableReason.noHistory,
        NotApplicableReason.noReceiveHistory,
        NotApplicableReason.noUtxoHistory,
      }.contains(r.reason))
        r,
  ]);

  List<SafetyCheckResult> _uniqueById(List<SafetyCheckResult> items) => [
    for (final (i, item) in items.indexed)
      if (items.indexWhere((other) => other.id == item.id) == i) item,
  ];

  /// 검토 필요 + 멤풀에서 사라진 사건 정보 행. 위급 머리가 보여 주는 점검([inHero]) 하나만 빼고
  /// 나머지 위급 원인(사건과 함께 온 인증서 변경 등)은 여기 남긴다
  List<Widget> _reviewSection(WalletHealthReport report, {SafetyCheckResult? inHero}) {
    final items = [
      for (final r in report.reviewItems)
        if (r != inHero) r,
    ];
    if (items.isEmpty && report.infoIncidents.isEmpty) return const [];
    return [
      SafetySectionTitle(t.wallet_health.section.review_needed),
      SafetyListCard(
        rows: [
          for (final item in items) SafetyReviewRow(check: item),
          for (final incident in report.infoIncidents) _InfoIncidentRow(incident: incident),
        ],
      ),
    ];
  }

  /// Coconut Premium 구역(POLISH §4 D1·D4·D5·D6). 상태가 먼저, 판매는 그다음:
  /// [구독 중이면 "Premium 사용 중" 줄, 비상 이동 줄(무료에게도 자리를 보인다)] → 판매 카드.
  /// 판매 카드는 무료일 때만, 데이터 부족(S4)·구독 확인 중·만료 뒤 멈춘 목적지가 있으면 빼고
  List<Widget> _premiumSection({required bool notEnoughData}) {
    final entitlement = context.read<EntitlementService>();
    return [
      ValueListenableBuilder<PremiumState>(
        valueListenable: entitlement.state,
        builder: (context, premium, _) {
          final rescue = context.watch<RescueReadyProvider?>();
          final verifying = premium.status == PremiumStatus.verifying;
          final line = rescue == null ? null : _rescueLine(rescue, premium.isActive);
          // 구독이 끝나도 정해 둔 목적지가 남으면 멈춤 줄(지우기·지금 이동은 그대로). 그 옆에 판매 카드는 두지 않는다
          final paused = !premium.isActive && line != null;
          final walletIds = [for (final w in context.read<WalletProvider?>()?.walletItemList ?? const []) w.id];
          final hasDestination = rescue != null && walletIds.any((id) => rescue.statusOf(id) != RescueStatus.notSet);
          final rows = <Widget>[
            if (premium.isActive)
              _PremiumRow(
                key: const Key('wallet-health-premium-active'),
                leading: const PremiumMark(size: 20),
                title: t.premium.subscription.active_title,
                subtitle: t.premium.card.active_body,
                highlighted: true,
                onTap: () => PremiumSubscriptionScreen.open(context),
              ),
            if (rescue != null)
              _PremiumRow(
                key: const Key('wallet-health-rescue-ready'),
                leading: SvgPicture.asset(FeatureWalletHealthIconPath.ambulance, width: 20, height: 20),
                title: line?.title ?? t.premium.rescue.name,
                // 구독 확인 중이고 목적지가 있으면 확인 중 안내, 그 밖의 무료는 이 기능이 하는 일(POLISH §4 D1·D6)
                subtitle:
                    line?.subtitle ??
                    (verifying && hasDestination ? t.premium.rescue.verifying : t.premium.rescue.free_body),
                warning: line?.warning ?? false,
                highlighted: premium.isActive,
                chip: line == null && !verifying,
                onTap: () => RescueReadyScreen.open(context),
              ),
          ];
          final group = SafetyListCard(backgroundColor: premium.isActive ? Colors.transparent : null, rows: rows);
          final sales = !premium.isActive && !notEnoughData && !verifying && !paused;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rows.isNotEmpty) ...[
                SafetySectionTitle(t.premium.name),
                if (premium.isActive) PremiumSurface(radius: 20, ringWidth: 1, animate: true, child: group) else group,
              ],
              if (sales) ...[
                if (rows.isEmpty) CoconutLayout.spacing_600h else CoconutLayout.spacing_300h,
                WalletHealthPremiumCard(onTap: () => PremiumPaywallScreen.open(context)),
              ],
            ],
          );
        },
      ),
    ];
  }

  /// "비상 이동 준비" 줄(UI_SPEC §4.5 표). 점수·라벨에는 영향이 없다
  ({String title, String subtitle, bool warning})? _rescueLine(RescueReadyProvider rescue, bool premium) {
    final r = t.premium.rescue;
    final walletIds = [for (final w in context.read<WalletProvider?>()?.walletItemList ?? const []) w.id];
    final statuses = [for (final id in walletIds) rescue.statusOf(id)];
    if (!premium) {
      // 확인 중·결제 대기는 멈춤이 아니다(provider가 paused로 주지 않는다)
      return statuses.contains(RescueStatus.paused)
          ? (title: r.paused_title, subtitle: r.paused_body, warning: false)
          : null;
    }
    if (statuses.contains(RescueStatus.invalidDestination)) {
      return (title: r.needs_check_title, subtitle: r.destination_invalid, warning: true);
    }
    if (statuses.contains(RescueStatus.failed)) {
      return (title: r.needs_check_title, subtitle: r.fee_failed, warning: true);
    }
    final designated = statuses.where((s) => s != RescueStatus.notSet).length;
    if (designated == 0) return (title: r.name, subtitle: r.none_body, warning: false);
    final ready = statuses.where((s) => s == RescueStatus.ready).length;
    // 목적지가 없는 지갑이 먼저, 그다음 초안이 아직이거나 막힌 지갑
    final blocked = switch (statuses.firstWhereOrNull((s) => s != RescueStatus.ready && s != RescueStatus.notSet)) {
      RescueStatus.pending => r.draft_pending,
      RescueStatus.noBalance => r.draft_no_balance,
      RescueStatus.tooSmall => r.draft_too_small,
      RescueStatus.unavailable => r.draft_unavailable,
      _ => null,
    };
    if (designated < walletIds.length || blocked != null) {
      final total = designated < walletIds.length ? walletIds.length : designated;
      return (
        title: ready == 0 ? r.name : r.ready_partial(ready: ready, total: total),
        subtitle: designated < walletIds.length ? r.partial_body : blocked!,
        warning: false,
      );
    }
    final updated = rescue.drafts.values.map((d) => d.preparedAt).maxOrNull;
    return (
      title: r.health_row(n: ready),
      subtitle: [
        if (updated != null) r.last_updated(time: formatHomeRelativeTime(updated, DateTime.now())),
        r.ready_body,
      ].join(' · '),
      warning: false,
    );
  }

  List<Widget> _recommendedSection(WalletHealthReport report) {
    if (report.recommended.isEmpty) return const [];
    return [
      // 제목 아래 4에 진행 부제, 그 아래 12(POLISH C28). SafetySectionTitle은 아래 12가 고정이라 여기서 짠다
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 32, 0, 0),
        child: Semantics(
          header: true,
          child: Text(
            safetyKoText(t.wallet_health.section.recommended),
            style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
          ),
        ),
      ),
      CoconutLayout.spacing_100h,
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 12),
        child: Text(
          t.wallet_health.section.recommended_progress(
            done: report.recommended.where((r) => r.done).length,
            total: report.recommended.length,
          ),
          style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
        ),
      ),
      SafetyListCard(
        rows: [
          for (final item in report.recommended)
            _RecommendedRow(item: item, onTap: () => showSafetyRecommendedSheet(context, item)),
        ],
      ),
    ];
  }

  /// WH-S3: 위급 머리 → 사건 카드 → [거래 검토] → Premium → 다른 점검 → 검토 필요
  List<Widget> _criticalSections(WalletHealthReport report, bool checking) {
    final colors = context.coconutColors;
    final incidents = report.criticalIncidents;
    final incident = incidents.firstOrNull;
    final check = report.reviewItems.firstWhereOrNull((r) => r.severity == SafetySeverity.critical);
    final c = t.wallet_health.critical;
    final txState =
        incident == null
            ? null
            : incident.txState == IncidentTxState.confirmed
            ? t.wallet_health.incident.tx_state.confirmed
            : t.wallet_health.incident.tx_state.unconfirmed;
    final walletName = safetyWalletOf(context, incident?.walletId)?.name;
    final buttonText =
        incident != null
            ? c.review_transaction
            : switch (check?.id) {
              SafetyCheckId.serverCert => c.review_certificate,
              SafetyCheckId.watchOnlyVerify => c.review_verification,
              _ => c.review_configuration,
            };
    void review() {
      if (incident == null) {
        if (check != null) openSafetyCheckAction(context, check);
      } else if (incident.state == IncidentState.responding) {
        SecurityGuide.resume(context, incident.id);
      } else {
        openSafetyIncident(context, walletId: incident.walletId, txid: incident.txid);
      }
    }

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            HealthGauge(report: report, isChecking: checking),
            CoconutLayout.spacing_300h,
            Text(
              safetyKoText(c.title),
              textAlign: TextAlign.center,
              style: CoconutTypography.heading4_18_Bold.setColor(colors.dangerText),
            ),
            CoconutLayout.spacing_100h,
            Text(
              safetyKoText(safetyCriticalTitle(report)),
              textAlign: TextAlign.center,
              style: CoconutTypography.body2_14.setColor(colors.secondaryText),
            ),
            if (txState != null) ...[
              CoconutLayout.spacing_50h,
              Text(
                [if (walletName != null) walletName, txState].join(' · '),
                textAlign: TextAlign.center,
                style: CoconutTypography.body3_12.setColor(colors.secondaryText),
              ),
            ],
          ],
        ),
      ),
      if (incident == null && check != null) ...[
        CoconutLayout.spacing_400h,
        _CriticalCheckCard(check: check, onTap: review),
      ],
      if (incident != null) ...[
        CoconutLayout.spacing_400h,
        _IncidentCard(incident: incident),
        if (incidents.length > 1) ...[
          CoconutLayout.spacing_200h,
          Center(
            child: CoconutUnderlinedButton(
              text: c.more_alerts(n: incidents.length - 1),
              onTap: () => SafetyAlertsScreen.open(context),
              textStyle: CoconutTypography.body3_12_Bold,
              defaultColor: colors.secondaryTextStrong,
            ),
          ),
        ],
      ],
      CoconutLayout.spacing_300h,
      // 빨간 버튼은 흰 글자 대비가 4.5에 못 미쳐 앱 표준 주 버튼을 쓴다
      InlineActionButton(key: const Key('wallet-health-critical-review'), text: buttonText, onPressed: review),
      CoconutLayout.spacing_600h,
      // Premium은 무료 대응 버튼 아래 보조로만
      if (incident != null) _criticalPremium(incident),
      SafetySectionTitle(c.other_checks, top: 0),
      SafetyListCard(
        rows: [
          for (final category in [
            SafetyCategory.recovery,
            SafetyCategory.app,
            SafetyCategory.privacy,
            if (incident == null) SafetyCategory.activity,
          ])
            _OtherCheckRow(report: report, category: category, onTap: () => showSafetyCategorySheet(context, category)),
        ],
      ),
      ..._reviewSection(report, inHero: incident == null ? check : null),
    ];
  }

  /// 위급 Premium 자리: 준비된 비상 이동(구독이 끝나도 쓸 수 있다) → 지금 이동 / Premium → 대응 준비 / Free → 비트코인 보호하기
  /// 카드가 있으면 아래 32 여백까지(없으면 "다른 점검"이 바로 온다)
  Widget _criticalPremium(SafetyIncident incident) {
    Widget card(BuildContext context, PremiumState? premium) {
      final child = _criticalPremiumCard(context, incident, premium);
      return child == null
          ? const SizedBox.shrink()
          : Padding(padding: const EdgeInsets.only(bottom: 32), child: child);
    }

    final entitlement = context.read<EntitlementService?>();
    return entitlement == null
        ? Builder(builder: (context) => card(context, null))
        : ValueListenableBuilder<PremiumState>(
          valueListenable: entitlement.state,
          builder: (context, premium, _) => card(context, premium),
        );
  }

  /// [premium]이 null이면 EntitlementService가 없는 것: 준비된 비상 이동만 보이고 결제 카드는 없다
  Widget? _criticalPremiumCard(BuildContext context, SafetyIncident incident, PremiumState? premium) {
    final rescue = context.watch<RescueReadyProvider?>();
    if (rescue != null && rescue.canMoveNow(incident.walletId)) {
      final r = t.premium.rescue;
      final updated = rescue.drafts[incident.walletId]?.preparedAt;
      return PremiumActionCard(
        key: const Key('wallet-health-rescue-card'),
        title: r.card_title,
        body: [
          r.card_body,
          if (updated != null) r.last_updated(time: formatHomeRelativeTime(updated, DateTime.now())),
        ].join(' '),
        button: r.move_now,
        onPressed: () => rescue.moveNow(context, incident.walletId),
      );
    }
    if (premium == null) return null;
    if (premium.isActive) {
      return PremiumActionCard(
        key: const Key('wallet-health-assist-card'),
        title: t.premium.subscription.active_title,
        body: t.premium.card.active_incident_body,
        button: t.premium.card.prepare_response,
        onPressed: () => SafetyAssistFlow.start(context, incident.id),
      );
    }
    return WalletHealthPremiumCard(critical: true, onTap: () => PremiumPaywallScreen.open(context));
  }
}

/// 사건이 아닌 위급(서버 인증서 변경 · 보기 전용/다중 서명 불일치)의 가운데 카드: 서버 또는 지갑 한 줄
class _CriticalCheckCard extends StatelessWidget {
  const _CriticalCheckCard({required this.check, required this.onTap});

  final SafetyCheckResult check;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final secondary = CoconutTypography.body3_12.setColor(colors.secondaryText);
    final wallet = safetyWalletOf(context, check.walletId);
    final server = check.id == SafetyCheckId.serverCert ? context.read<SafetyProvider?>()?.state.serverCert : null;
    final Widget content;
    if (check.id == SafetyCheckId.serverCert) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            server == null ? safetyCheckName(check.id) : '${server.host}:${server.port}',
            style: CoconutTypography.body2_14.setColor(colors.primaryText),
          ),
          if (check.subjects.length > 1)
            Text(
              '${t.wallet_health.review.server_cert.fingerprint} ${safetyShortFingerprint(check.subjects[1])}',
              style: secondary,
            ),
        ],
      );
    } else if (wallet != null) {
      content = Row(
        children: [
          safetyWalletIcon(wallet),
          CoconutLayout.spacing_300w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wallet.name, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
                Text(safetyWalletKindText(wallet), style: secondary),
              ],
            ),
          ),
        ],
      );
    } else {
      content = Text(
        safetyKoText(safetyCheckName(check.id)),
        style: CoconutTypography.body2_14.setColor(colors.primaryText),
      );
    }
    return SafetyListCard(
      key: const Key('wallet-health-critical-check-card'),
      rows: [
        SafetyPressRow(
          background: colors.homeSurface,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(children: [Expanded(child: content), CoconutLayout.spacing_200w, const SafetyChevron()]),
          ),
        ),
      ],
    );
  }
}

/// 위급 사건 거래. 잔액 숨김·가짜 잔액이면 금액 없이 지갑 이름과 발견 시각만
class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident});

  final SafetyIncident incident;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final preferences = context.watch<PreferenceProvider?>();
    final tx = context.read<WalletProvider?>()?.getTransactionRecord(incident.walletId, incident.txid);
    void open() => openSafetyIncident(context, walletId: incident.walletId, txid: incident.txid, autoReview: false);
    final hideAmount = preferences == null || preferences.isBalanceHidden || preferences.isFakeBalanceActive;
    if (tx != null && !hideAmount) {
      return TransactionItemCard(
        key: const Key('wallet-health-incident-card'),
        tx: tx,
        currentUnit: preferences.currentUnit,
        id: incident.walletId,
        onPressed: open,
        backgroundColor: colors.homeSurface,
        borderRadius: 20,
      );
    }
    final walletName = safetyWalletOf(context, incident.walletId)?.name;
    return SafetyListCard(
      key: const Key('wallet-health-incident-card'),
      rows: [
        SafetyPressRow(
          background: colors.homeSurface,
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 금액 대신 "보낸 거래"(잔액 숨김을 따른다)
                      Text(
                        safetyKoText(t.wallet_health.critical.sent_transaction),
                        style: CoconutTypography.body2_14.setColor(colors.primaryText),
                      ),
                      Text(
                        [
                          if (walletName != null) walletName,
                          t.wallet_health.alerts.detected_at(
                            time: formatHomeRelativeTime(incident.detectedAt, DateTime.now()),
                          ),
                        ].join(' · '),
                        style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                      ),
                    ],
                  ),
                ),
                CoconutLayout.spacing_200w,
                const SafetyChevron(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 멤풀에서 사라진 사건(정보). 확인 필요 수·🔔 점에 넣지 않는다
class _InfoIncidentRow extends StatelessWidget {
  const _InfoIncidentRow({required this.incident});

  final SafetyIncident incident;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final wallet = safetyWalletLine(context, incident.walletId);
    return SafetyPressRow(
      key: Key('wallet-health-info-${incident.id}'),
      background: colors.homeSurface,
      // 사라진 거래는 거래 상세 대신 사건 시트로(D가 처리)
      onTap: () => openSafetyIncident(context, walletId: incident.walletId, txid: incident.txid, autoReview: false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            SvgPicture.asset(
              CommonStateIconPath.circleInfo,
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
            ),
            CoconutLayout.spacing_300w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wallet != null) Text(wallet, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
                  Text(
                    safetyKoText(t.wallet_health.section.mempool_dropped),
                    style: CoconutTypography.body2_14.setColor(colors.primaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumRow extends StatelessWidget {
  const _PremiumRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.warning = false,
    this.chip = false,
    this.highlighted = false,
    required this.onTap,
  });

  /// "Premium 사용 중"은 PremiumMark 20, 비상 이동 줄은 컬러 구급차 아이콘 20
  final Widget leading;
  final String title;
  final String? subtitle;

  /// 무료 비상 이동 줄: 제목 옆에 PremiumChip(POLISH §4 D1)
  final bool chip;
  final bool highlighted;

  /// 갱신 실패 등 확인이 필요한 줄(제목 warningText)
  final bool warning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    // 큰 글자(1.3배~)에서는 칩을 부제 아래 왼쪽에: 나란히면 칩이 폭을 크게 차지해 글이 여러 줄로 좁아진다(X13, D의 X7·X8과 같은 기준)
    final chipBelow = chip && MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.3;
    return SafetyPressRow(
      background: highlighted ? Colors.transparent : colors.homeSurface,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: EdgeInsets.only(top: safetyTitleLineTop(context, 20, tallest: 20)), child: leading),
            CoconutLayout.spacing_200w,
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: safetyTitleLineShift(context, 20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            safetyKoText(title),
                            style: (highlighted ? CoconutTypography.body2_14_Bold : CoconutTypography.body2_14)
                                .setColor(warning ? colors.warningText : colors.primaryText),
                          ),
                        ),
                        if (chip && !chipBelow) ...[CoconutLayout.spacing_150w, const PremiumChip()],
                      ],
                    ),
                    if (subtitle != null) ...[
                      CoconutLayout.spacing_50h,
                      Text(
                        safetyKoText(subtitle!),
                        style: CoconutTypography.body3_12.setColor(
                          highlighted ? colors.secondaryTextStrong : colors.secondaryText,
                        ),
                      ),
                    ],
                    if (chipBelow) ...[CoconutLayout.spacing_100h, const PremiumChip()],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: safetyTitleLineTop(context, SafetyChevron.height, tallest: 20)),
              child: const SafetyChevron(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 위급 화면의 "다른 점검" 행(카테고리 점수 + 상태)
class _OtherCheckRow extends StatelessWidget {
  const _OtherCheckRow({required this.report, required this.category, required this.onTap});

  final WalletHealthReport report;
  final SafetyCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final score = report.categories[category]?.score;
    final status = safetyCategoryStatus(context, report, category);
    return SafetyPressRow(
      background: colors.homeSurface,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            SvgPicture.asset(
              safetyCategoryIconPath(category),
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
            ),
            CoconutLayout.spacing_300w,
            Expanded(
              child: Text(
                safetyKoText(safetyCategoryName(category)),
                style: CoconutTypography.body2_14.setColor(colors.primaryText),
              ),
            ),
            CoconutLayout.spacing_200w,
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    score?.toString() ?? t.wallet_health.category.waiting,
                    style:
                        score == null
                            ? CoconutTypography.body2_14_Bold.setColor(colors.secondaryText)
                            : CoconutTypography.body1_16_NumberBold.setColor(colors.primaryText),
                  ),
                  Text(
                    safetyKoText(status.text),
                    textAlign: TextAlign.end,
                    style: CoconutTypography.body3_12.setColor(status.color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 권장 점검 행. 직접 완료한 항목은 초록이 아닌 회색 체크(자동 검증 "확인됨"과 구분)
class _RecommendedRow extends StatelessWidget {
  const _RecommendedRow({required this.item, required this.onTap});

  final RecommendedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final check = item.check;
    final evidence = t.wallet_health.evidence;
    final cert = t.wallet_health.check.server_cert;
    final subtitle = switch (check) {
      null => item.done ? evidence.completed_by_you : evidence.not_checked,
      final SafetyCheckResult check when item.done => safetyPassedText(check).text,
      final SafetyCheckResult check when check.id == SafetyCheckId.serverCert =>
        (check.count ?? 0) == 0 ? cert.expires_today : cert.expires_in(n: check.count!),
      final SafetyCheckResult check => safetyIssueText(check),
    };
    return SafetyPressRow(
      key: Key('wallet-health-recommended-${item.id?.key ?? item.check?.key}'),
      background: colors.homeSurface,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: safetyTitleLineTop(context, 20, above: CoconutTypography.body3_12, tallest: 20),
              ),
              child: SvgPicture.asset(
                item.done ? FeatureWalletHealthIconPath.checkCircleFilled : FeatureWalletHealthIconPath.circleEmpty,
                width: 20,
                height: 20,
                semanticsLabel: item.done ? safetyEvidenceA11y(byUser: true) : null,
                colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
              ),
            ),
            CoconutLayout.spacing_200w,
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: safetyTitleLineShift(context, 20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(safetyKoText(subtitle), style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
                    Text(
                      safetyKoText(safetyRecommendedName(context, item)), // "확인하 / 기" 방지(POLISH R1)
                      style: CoconutTypography.body2_14.setColor(colors.primaryText),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: safetyTitleLineTop(context, SafetyChevron.height, above: CoconutTypography.body3_12, tallest: 20),
              ),
              child: const SafetyChevron(),
            ),
          ],
        ),
      ),
    );
  }
}
