import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart'
    show CoconutLayout, CoconutTypography, TextColorExtension;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/constants/app_info.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_navigation_target.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/safety/bsms_verification_screen.dart';
import 'package:coconut_wallet/screens/safety/incident_sheets.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_screen.dart';
import 'package:coconut_wallet/screens/safety/watch_only_verification_screen.dart';
import 'package:coconut_wallet/screens/settings/pin_setting_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart' show kEntryPointWalletHome;
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/suspicious_transaction_util.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/common/overlays/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart' show formatHomeRelativeTime;
import 'package:coconut_wallet/widgets/features/safety/safety_caution_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_score_gauge.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_health_cards.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:provider/provider.dart';

/// 점검 행의 동작: 기존 화면으로 가거나 검토 상세 시트를 띄운다
Future<void> openSafetyCheckAction(BuildContext context, SafetyCheckResult item) async {
  final walletId = item.walletId;
  switch (item.id) {
    case SafetyCheckId.appLock:
      // 앱 설정의 앱 잠금 켜기와 같은 PIN 설정 시트
      await CommonBottomSheets.showCustomHeightBottomSheet(
        context: context,
        screenName: AnalyticsScreenNames.appSettingsPinSetSheet,
        heightRatio: 0.9,
        // 완료 때 PIN 시트만 닫는다(기본값은 부모까지 닫아서 Wallet Health가 사라진다)
        child: const CustomLoadingOverlay(child: PinSettingScreen(useBiometrics: true, popParentOnComplete: false)),
      );
    case SafetyCheckId.mnemonicBackup || SafetyCheckId.passphraseVerify || SafetyCheckId.multisigConfig
        when walletId != null:
      final wallet = safetyWalletOf(context, walletId);
      if (wallet == null) return;
      await Navigator.pushNamed(
        context,
        AppRouteNames.walletInfo,
        arguments: WalletInfoRouteArgs(
          id: walletId,
          walletType: wallet.walletType,
          entryPoint: kEntryPointWalletHome,
          highlightMnemonicBackup: item.id == SafetyCheckId.mnemonicBackup,
          initialTarget: item.id == SafetyCheckId.passphraseVerify ? WalletInfoTarget.passphrase : null,
        ),
      );
    case SafetyCheckId.watchOnlyVerify when walletId != null:
      await WatchOnlyVerificationScreen.open(context, walletId: walletId);
    case SafetyCheckId.bsmsBackup when walletId != null:
      await BsmsVerificationScreen.open(context, walletId: walletId);
    case SafetyCheckId.pendingOutgoingAtBaseline || SafetyCheckId.unexpectedSelfTransfer
        when walletId != null && item.subjects.isNotEmpty:
      // 시트 없이 거래 상세 + 인지 시트로 바로 간다(내 거래예요로 닫힌다)
      await openSafetyIncident(context, walletId: walletId, txid: item.subjects.first);
    default:
      await showSafetyReviewItemSheet(context, item);
  }
}

// ── 점수 안내(ⓘ) ──

Future<void> showWalletHealthAboutSheet(BuildContext context) => CommonBottomSheets.showDraggableBottomSheet<void>(
  context: context,
  screenName: '/wallet-health/about',
  title: t.wallet_health.about.title,
  titleTextStyle: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
  scaleDownTitle: true,
  minChildSize: 0.6,
  maxChildSize: 0.9,
  initialChildSize: 0.9,
  childBuilder: (controller) => _AboutSheet(controller: controller),
);

class _AboutSheet extends StatelessWidget {
  const _AboutSheet({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final report = context.watch<SafetyProvider?>()?.report;
    final s = t.wallet_health.about;
    final secondary = CoconutTypography.body3_12.setColor(colors.secondaryText);
    final notIncluded = <String>{
      for (final r in report?.notIncluded ?? const <SafetyCheckResult>[])
        if (r.reason != null) '${safetyCheckName(r.id)} - ${safetyReasonText(r.reason!)}',
    };
    return ListView(
      key: const Key('wallet-health-about-sheet'),
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Text(
          safetyKoText(report?.score != null ? s.meaning_body : s.no_score_body),
          style: CoconutTypography.body2_14.setColor(colors.primaryText),
        ),
        if (report?.status == WalletHealthStatus.notEnoughData) ...[
          CoconutLayout.spacing_200h,
          Text(safetyKoText(s.min_coverage), style: secondary),
        ],
        // 지갑이 없을 때: 지금 되는 점검과 지갑을 추가하면 되는 점검(REQ §18.11.4·§18.11.9-8, C47). 화면 S0와 같은 이름·행
        if (report != null && report.status == WalletHealthStatus.noWallet) ...[
          if (report.allGoodItems.isNotEmpty) ...[
            _SheetTitle(t.wallet_health.section.available_now),
            SafetyListCard(
              backgroundColor: colors.surfaceBottomSheetElevated,
              rows: [
                for (final (i, item) in report.allGoodItems.indexed)
                  if (report.allGoodItems.indexWhere((other) => other.id == item.id) == i) SafetyPassedRow(item: item),
              ],
            ),
          ],
          _SheetTitle(t.wallet_health.section.after_adding_wallet),
          WalletHealthNotIncludedCard(
            names: safetyNoWalletCheckNames(about: true),
            showReasons: false,
            backgroundColor: colors.surfaceBottomSheetElevated,
          ),
        ],
        _SheetTitle(s.range_title),
        for (final (i, label) in WalletHealthLabel.values.indexed) ...[
          if (i > 0) Divider(color: colors.divider, height: 1),
          _RangeRow(label: label),
        ],
        if (report != null && report.walletCount > 0) ...[_SheetTitle(s.included_title), _IncludedGrid(report: report)],
        if (report != null && report.score != null) ...[
          _SheetTitle(s.formula_title),
          _ScoreFormula(report: report),
          CoconutLayout.spacing_300h,
          Text(safetyKoText(s.formula_note), style: secondary),
        ],
        // 지갑이 없으면 위 "지갑을 추가하면…" 목록과 겹치므로 뺀다(C47)
        if (notIncluded.isNotEmpty && report?.status != WalletHealthStatus.noWallet) ...[
          CoconutLayout.spacing_400h,
          _Box(
            radius: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(safetyKoText(s.not_included_title), style: secondary),
                CoconutLayout.spacing_300h,
                for (final (i, line) in notIncluded.indexed) ...[
                  if (i > 0) CoconutLayout.spacing_50h,
                  Text(safetyKoText(line), style: secondary),
                ],
              ],
            ),
          ),
        ],
        if (report != null) ...[
          _SheetTitle(s.data_title, bottom: 0),
          Text(safetyKoText(s.data_note), style: CoconutTypography.body3_12.setColor(colors.primaryText)),
          CoconutLayout.spacing_300h,
          _Box(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                _DataRow(
                  label: s.last_updated,
                  value: Text(
                    // 성공한 동기화가 없으면 검사 시각을 쓰지 않는다(오프라인 자료가 새것처럼 보이면 안 된다, REQ §18.10.1·C45)
                    report.lastSuccessfulSyncAt == null
                        ? '—'
                        : DateTimeUtil.formatTimestamp(report.lastSuccessfulSyncAt!).join(' '),
                    style: CoconutTypography.body3_12.setColor(colors.primaryText),
                  ),
                ),
                Divider(color: colors.divider, height: 32),
                _DataRow(
                  label: t.wallet_health.section.connection,
                  value: _ConnectionValue(connected: report.isConnected),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 시트 안 소제목(앱 설정 분류 제목과 같은 크기)
class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text, {this.bottom = 12});

  final String text;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 32, bottom: bottom),
    child: Semantics(
      header: true,
      child: Text(
        safetyKoText(text),
        style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
      ),
    ),
  );
}

/// 시트 안 상자
class _Box extends StatelessWidget {
  const _Box({required this.child, this.radius = 16, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    padding: padding,
    decoration: BoxDecoration(
      color: context.coconutColors.surfaceBottomSheetElevated,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: child,
  );
}

class _RangeRow extends StatelessWidget {
  const _RangeRow({required this.label});

  final WalletHealthLabel label;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final health = context.walletHealthColors;
    final s = t.wallet_health.about;
    final (range, dot, description) = switch (label) {
      WalletHealthLabel.excellent => ('90 - 100', health.excellent, s.range_excellent),
      WalletHealthLabel.good => ('75 - 89', health.good, s.range_good),
      WalletHealthLabel.needsAttention => ('50 - 74', health.warning, s.range_needs_attention),
      WalletHealthLabel.actionNeeded => ('0 - 49', health.critical, s.range_action_needed),
    };
    final rowStyle = CoconutTypography.body2_14;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: safetyFirstLineTop(context, rowStyle, 12)),
            child: Container(width: 12, height: 12, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          ),
          CoconutLayout.spacing_300w,
          SizedBox(
            width: 64,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(range, maxLines: 1, style: CoconutTypography.body2_14.setColor(colors.primaryText)),
            ),
          ),
          CoconutLayout.spacing_200w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(walletHealthLabelText(label), style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
                CoconutLayout.spacing_50h,
                Text(safetyKoText(description), style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 카테고리별로 실제 적용된 점검과 실제 쓰인 비중 %
class _IncludedGrid extends StatelessWidget {
  const _IncludedGrid({required this.report});

  final WalletHealthReport report;

  @override
  Widget build(BuildContext context) {
    Widget box(SafetyCategory category) => Expanded(child: _IncludedBox(category: category, report: report));
    const order = [SafetyCategory.recovery, SafetyCategory.activity, SafetyCategory.app, SafetyCategory.privacy];
    return LayoutBuilder(
      builder: (context, constraints) {
        // 상자가 150dp(글자 배율만큼 넓혀)보다 좁아지면 한 줄에 하나씩(POLISH C39·X5)
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if ((constraints.maxWidth - 12) / 2 < 150 * textScale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, category) in order.indexed) ...[
                if (i > 0) CoconutLayout.spacing_300h,
                _IncludedBox(category: category, report: report),
              ],
            ],
          );
        }
        return _twoColumns(box);
      },
    );
  }

  Widget _twoColumns(Widget Function(SafetyCategory) box) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [box(SafetyCategory.recovery), CoconutLayout.spacing_300w, box(SafetyCategory.activity)],
          ),
        ),
        CoconutLayout.spacing_300h,
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [box(SafetyCategory.app), CoconutLayout.spacing_300w, box(SafetyCategory.privacy)],
          ),
        ),
      ],
    );
  }
}

class _IncludedBox extends StatelessWidget {
  const _IncludedBox({required this.category, required this.report});

  final SafetyCategory category;
  final WalletHealthReport report;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final applied = {
      for (final r in [...report.reviewItems, ...report.allGoodItems]) r.id,
      if (report.criticalIncidents.isNotEmpty) SafetyCheckId.unrecognizedOutgoing,
    };
    final names = <String>{
      for (final id in SafetyCheckId.values)
        if (id.category == category && applied.contains(id))
          id == SafetyCheckId.multisigConfig || id == SafetyCheckId.bsmsBackup
              ? t.wallet_health.about.multisig_recovery
              : safetyCheckName(id),
    };
    final percent = report.categories[category]?.weightPercent ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.homeSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: safetyCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                safetyCategoryIconPath(category),
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(colors.secondaryText, BlendMode.srcIn),
              ),
              CoconutLayout.spacing_200w,
              Expanded(
                child: Text(
                  safetyKoText(safetyCategoryName(category)),
                  style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                ),
              ),
              if (percent > 0) ...[
                CoconutLayout.spacing_200w,
                Text('${percent.round()}%', style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
              ],
            ],
          ),
          CoconutLayout.spacing_200h,
          if (names.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                safetyKoText(t.wallet_health.category.waiting),
                style: CoconutTypography.body3_12.setColor(colors.secondaryText),
              ),
            ),
          for (final (i, name) in names.indexed) ...[
            if (i > 0) CoconutLayout.spacing_100h,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 28),
                Padding(
                  padding: EdgeInsets.only(top: safetyFirstLineTop(context, CoconutTypography.body3_12, 10)),
                  child: SvgPicture.asset(
                    FeatureWalletHealthIconPath.check,
                    width: 10,
                    height: 10,
                    colorFilter: ColorFilter.mode(context.walletHealthColors.good, BlendMode.srcIn),
                  ),
                ),
                CoconutLayout.spacing_150w,
                Expanded(
                  child: Text(safetyKoText(name), style: CoconutTypography.body3_12.setColor(colors.primaryText)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 카테고리 점수 × 비중 = 기여, 아래에 합계(최종 점수)
class _ScoreFormula extends StatelessWidget {
  const _ScoreFormula({required this.report});

  final WalletHealthReport report;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final s = t.wallet_health.about;
    final style = CoconutTypography.body3_12.setColor(colors.primaryText);
    final muted = CoconutTypography.body3_12.setColor(colors.secondaryText);
    final bold = CoconutTypography.body3_12_Bold.setColor(colors.primaryText);
    const order = [SafetyCategory.recovery, SafetyCategory.activity, SafetyCategory.app, SafetyCategory.privacy];
    Widget row(String name, String formula, String result, {TextStyle? nameStyle, TextStyle? resultStyle}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: Text(safetyKoText(name), style: nameStyle ?? style)),
          CoconutLayout.spacing_200w,
          Expanded(flex: 4, child: Text(formula, textAlign: TextAlign.end, style: muted)),
          CoconutLayout.spacing_200w,
          SizedBox(width: 40, child: Text(result, textAlign: TextAlign.end, style: resultStyle ?? style)),
        ],
      ),
    );
    return _Box(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          for (final category in order)
            if (report.categories[category] case final c?)
              c.score == null
                  ? row(safetyCategoryName(category), s.formula_not_scored, '—', nameStyle: muted, resultStyle: muted)
                  : row(
                    safetyCategoryName(category),
                    '${c.score} × ${c.weightPercent.round()}%',
                    (c.score! * c.weightPercent / 100).toStringAsFixed(1),
                  ),
          Divider(color: colors.divider, height: 16),
          row(s.formula_total, '', '${report.score}', nameStyle: bold, resultStyle: bold),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 2,
        child: Text(safetyKoText(label), style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText)),
      ),
      CoconutLayout.spacing_400w,
      Expanded(flex: 3, child: Align(alignment: Alignment.centerLeft, child: value)),
    ],
  );
}

class _ConnectionValue extends StatelessWidget {
  const _ConnectionValue({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: connected ? context.walletHealthColors.good : context.walletHealthColors.critical,
            shape: BoxShape.circle,
          ),
        ),
        CoconutLayout.spacing_200w,
        Flexible(
          child: Text(
            safetyKoText(connected ? t.wallet_health.connection.connected : t.wallet_health.about.offline_not_scored),
            style: CoconutTypography.body3_12.setColor(colors.primaryText),
          ),
        ),
      ],
    );
  }
}

// ── 카테고리 상세 · 지갑별 기여 ──

Future<void> showSafetyCategorySheet(BuildContext context, SafetyCategory category) =>
    CommonBottomSheets.showDraggableBottomSheet<void>(
      context: context,
      screenName: '/wallet-health/category',
      title: safetyCategoryName(category),
      minChildSize: 0.5,
      maxChildSize: 0.9,
      childBuilder: (controller) => _CategorySheet(category: category, controller: controller, opener: context),
    );

/// 점검 결과 전체(실패 → 통과 → 해당 없음 순)
List<SafetyCheckResult> _allChecks(WalletHealthReport report) => [
  ...report.reviewItems,
  ...report.allGoodItems,
  ...report.notIncluded,
];

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({required this.category, required this.controller, required this.opener});

  final SafetyCategory category;
  final ScrollController controller;

  /// 시트를 닫은 뒤 다음 화면을 여는 데 쓴다
  final BuildContext opener;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final report = context.watch<SafetyProvider?>()?.report;
    if (report == null) return const SizedBox.shrink();
    final score = report.categories[category]?.score;
    final status = safetyCategoryStatus(context, report, category);
    final available = report.status == WalletHealthStatus.noWallet && category == SafetyCategory.app;
    final checks = [
      for (final r in _allChecks(report))
        if (r.id.category == category) r,
    ];
    final secondary = CoconutTypography.body3_12.setColor(colors.secondaryText);
    final note = switch (category) {
      SafetyCategory.app => t.wallet_health.category_sheet.app_protection_note,
      SafetyCategory.recovery => t.wallet_health.about.wallets_note,
      SafetyCategory.activity => t.wallet_health.category_sheet.activity_note,
      SafetyCategory.privacy => t.wallet_health.about.weight_privacy,
    };
    return ListView(
      key: Key('wallet-health-category-sheet-${category.name}'),
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              available ? t.wallet_health.category.available : score?.toString() ?? t.wallet_health.category.waiting,
              style:
                  score != null && !available
                      ? CoconutTypography.heading2_28_NumberBold.setColor(colors.primaryText)
                      : CoconutTypography.heading3_21_Bold.setColor(
                        available ? colors.primaryText : colors.secondaryText,
                      ),
            ),
            CoconutLayout.spacing_200w,
            Expanded(child: Text(safetyKoText(status.text), style: CoconutTypography.body2_14.setColor(status.color))),
          ],
        ),
        CoconutLayout.spacing_400h,
        if (category == SafetyCategory.recovery)
          ..._walletBoxes(context, report, checks)
        else if (checks.isNotEmpty)
          _Box(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, item) in checks.indexed) ...[
                  if (i > 0) Divider(color: colors.divider, height: 1, indent: 16, endIndent: 16),
                  _CheckRow(item: item, opener: opener, showWallet: true),
                ],
              ],
            ),
          ),
        CoconutLayout.spacing_300h,
        Text(safetyKoText(note), style: secondary),
      ],
    );
  }

  /// 복구 준비: 지갑마다 상자 하나(비중 큰 지갑부터, 점수 없는 지갑은 뒤에)
  List<Widget> _walletBoxes(BuildContext context, WalletHealthReport report, List<SafetyCheckResult> checks) {
    final walletIds = {
      for (final r in report.recovery) r.walletId,
      for (final c in checks)
        if (c.walletId != null) c.walletId!,
    };
    if (walletIds.isEmpty) {
      return [
        Text(
          safetyKoText(t.wallet_health.category_sheet.no_applicable),
          style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
        ),
      ];
    }
    return [
      for (final (i, walletId) in walletIds.indexed) ...[
        if (i > 0) CoconutLayout.spacing_300h,
        _WalletBox(
          walletId: walletId,
          score: report.recovery.firstWhereOrNull((r) => r.walletId == walletId)?.score,
          checks: [
            for (final c in checks)
              if (c.walletId == walletId) c,
          ],
          opener: opener,
        ),
      ],
    ];
  }
}

class _WalletBox extends StatelessWidget {
  const _WalletBox({required this.walletId, required this.score, required this.checks, required this.opener});

  final int walletId;
  final int? score;
  final List<SafetyCheckResult> checks;
  final BuildContext opener;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final wallet = safetyWalletOf(context, walletId);
    return _Box(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (wallet != null)
            Padding(padding: const EdgeInsets.all(16), child: _WalletHeader(wallet: wallet, score: score)),
          if (wallet != null && checks.isNotEmpty) Divider(color: colors.divider, height: 1),
          for (final item in checks) _CheckRow(item: item, opener: opener),
        ],
      ),
    );
  }
}

class _WalletHeader extends StatelessWidget {
  const _WalletHeader({required this.wallet, required this.score});

  final WalletItemBase wallet;
  final int? score;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Row(
      children: [
        safetyWalletIcon(wallet),
        CoconutLayout.spacing_300w,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(wallet.name, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
              Text(safetyWalletKindText(wallet), style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
            ],
          ),
        ),
        CoconutLayout.spacing_200w,
        Text(
          score?.toString() ?? t.wallet_health.category.waiting,
          style:
              score == null
                  ? CoconutTypography.body2_14_Bold.setColor(colors.secondaryText)
                  : CoconutTypography.heading4_18_NumberBold.setColor(colors.primaryText),
        ),
      ],
    );
  }
}

/// 점검 한 줄: 실패 = ⚠ + 문제 + 알약(누르면 시트를 닫고 해당 화면) / 통과 = ✓ + 결과 / 해당 없음 = ○ + 이유
class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.item, required this.opener, this.showWallet = false});

  final SafetyCheckResult item;
  final BuildContext opener;

  /// 지갑별이 아닌 카테고리 상자: 지갑 이름을 부제로, 할 일은 꺾쇠로(복구 준비·지갑 시트는 알약)
  final bool showWallet;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final failed = item.outcome == SafetyOutcome.failed;
    final passed = item.outcome == SafetyOutcome.passed ? safetyPassedText(item) : null;
    final wallet = showWallet ? safetyWalletOf(context, item.walletId)?.name : null;
    final health = context.walletHealthColors;
    final (icon, iconColor) =
        failed
            ? (FeatureWalletHealthIconPath.triangleWarningFilled, health.warning)
            : passed != null
            ? (FeatureWalletHealthIconPath.checkCircleFilled, passed.byUser ? colors.iconSecondary : health.good)
            : (FeatureWalletHealthIconPath.circleEmpty, colors.iconSecondary);
    final result =
        failed
            ? safetyFailedResultText(item)
            : passed?.text ??
                (item.outcome == SafetyOutcome.notApplicable
                    ? t.wallet_health.check.not_applicable
                    : item.reason == null
                    ? t.wallet_health.evidence.not_checked
                    : safetyReasonText(item.reason!));
    final resultColor =
        failed
            ? health.warning
            : passed != null && !passed.byUser
            ? health.good
            : colors.secondaryText;
    final chevron = failed && showWallet;
    final tallest = 20.0;
    final resultLine =
        MediaQuery.textScalerOf(context).scale(CoconutTypography.body3_12.fontSize!) *
        CoconutTypography.body3_12.height!;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: safetyTitleLineTop(context, 20, tallest: tallest)),
            child: SvgPicture.asset(
              icon,
              width: 20,
              height: 20,
              semanticsLabel: passed == null ? null : safetyEvidenceA11y(byUser: passed.byUser),
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
          CoconutLayout.spacing_200w,
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: safetyTitleLineShift(context, tallest)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    safetyKoText(safetyCheckName(item.id)),
                    style: CoconutTypography.body2_14.setColor(colors.primaryText),
                  ),
                  if (wallet != null) Text(wallet, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
                ],
              ),
            ),
          ),
          CoconutLayout.spacing_200w,
          // 결과는 오른쪽 끝, 할 일 알약은 결과 아래 줄(좁은 폭·긴 언어에서 결과 글이 밀리지 않게, POLISH C7)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: safetyTitleLineTop(context, resultLine, tallest: tallest)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    safetyKoText(result),
                    textAlign: TextAlign.end,
                    style: CoconutTypography.body3_12.setColor(resultColor),
                  ),
                  if (failed && !showWallet) ...[
                    CoconutLayout.spacing_100h,
                    SafetyActionPill(text: safetyCtaText(item)),
                  ],
                ],
              ),
            ),
          ),
          if (chevron) ...[
            CoconutLayout.spacing_200w,
            Padding(
              padding: EdgeInsets.only(top: safetyTitleLineTop(context, SafetyChevron.height, tallest: tallest)),
              child: const SafetyChevron(),
            ),
          ],
        ],
      ),
    );
    if (!failed) return row;
    return SafetyPressRow(
      key: Key('wallet-health-check-row-${item.key}'),
      background: colors.surfaceBottomSheetElevated,
      onTap: () {
        Navigator.pop(context);
        if (opener.mounted) openSafetyCheckAction(opener, item);
      },
      child: row,
    );
  }
}

/// 지갑 하나의 복구 기여와 점검(지갑 정보 "안전 상태" 줄에서 연다)
Future<void> showWalletContributionSheet(BuildContext context, int walletId) =>
    CommonBottomSheets.showDraggableBottomSheet<void>(
      context: context,
      screenName: '/wallet-health/wallet',
      title: safetyWalletOf(context, walletId)?.name ?? t.wallet_health.title,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      childBuilder: (controller) => _WalletSheet(walletId: walletId, controller: controller, opener: context),
    );

class _WalletSheet extends StatelessWidget {
  const _WalletSheet({required this.walletId, required this.controller, required this.opener});

  final int walletId;
  final ScrollController controller;
  final BuildContext opener;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final report = context.watch<SafetyProvider?>()?.report;
    final wallet = safetyWalletOf(context, walletId);
    final checks = [
      for (final r in report == null ? const <SafetyCheckResult>[] : _allChecks(report))
        if (r.walletId == walletId) r,
    ];
    final incidents = [
      for (final i in report?.criticalIncidents ?? const [])
        if (i.walletId == walletId) i,
    ];
    final secondary = CoconutTypography.body3_12.setColor(colors.secondaryText);
    // 전체 지갑 상태로 가는 버튼을 시트 아래에 고정한다(고르기 시트의 확인 버튼과 같은 방식). 목록은 그 높이만큼 비켜 둔다
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final buttonArea =
        FixedBottomButton.fixedBottomButtonDefaultHeight * textScale.clamp(1.0, double.infinity) + 3 + 12;
    final list = ListView(
      key: const Key('wallet-health-wallet-sheet'),
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        // 사용 주의면 지갑 상세와 같은 배너(문구·해제·확인 창·토스트가 같다, POLISH X11). 아니면 아무것도 그리지 않는다
        SafetyCautionBanner(walletId: walletId),
        if (wallet != null) ...[
          _WalletHeader(wallet: wallet, score: report?.recovery.firstWhereOrNull((r) => r.walletId == walletId)?.score),
          CoconutLayout.spacing_400h,
        ],
        if (checks.isEmpty && incidents.isEmpty)
          Text(
            safetyKoText(t.wallet_health.category_sheet.no_applicable),
            style: CoconutTypography.body2_14.setColor(colors.secondaryText),
          )
        else
          _Box(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final incident in incidents)
                  SafetyPressRow(
                    background: colors.surfaceBottomSheetElevated,
                    onTap: () {
                      Navigator.pop(context);
                      if (opener.mounted) openSafetyIncident(opener, walletId: walletId, txid: incident.txid);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            FeatureWalletHealthIconPath.lightEmergencyOn,
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(context.walletHealthColors.critical, BlendMode.srcIn),
                          ),
                          CoconutLayout.spacing_200w,
                          Expanded(
                            child: Text(
                              safetyKoText(t.wallet_health.incident.outgoing_title),
                              style: CoconutTypography.body2_14.setColor(colors.primaryText),
                            ),
                          ),
                          CoconutLayout.spacing_200w,
                          // 사건은 위급 짝(빨강 사이렌 옆 노랑 알약이 아니라, POLISH C23)
                          SafetyActionPill(text: t.wallet_health.cta.review, danger: true),
                        ],
                      ),
                    ),
                  ),
                for (final item in checks) _CheckRow(item: item, opener: opener),
              ],
            ),
          ),
        CoconutLayout.spacing_300h,
        Text(safetyKoText(t.wallet_health.about.wallets_note), style: secondary),
      ],
    );
    return SafeArea(
      top: false,
      child: Stack(
        children: [
          Positioned.fill(bottom: buttonArea, child: list),
          // 지갑 정보·지갑 상세에서 열었을 때 전체 지갑 상태로(UI_SPEC §7.5, POLISH §3)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: buttonArea + 5,
              child: FixedBottomButton(
                buttonKey: const Key('wallet-health-view-all'),
                text: t.wallet_health.wallet_info.view_all,
                isVisibleAboveKeyboard: false,
                bottomPadding: 16,
                surroundingsColor: Colors.transparent,
                onButtonClicked: () {
                  Navigator.pop(context);
                  if (opener.mounted) WalletHealthScreen.open(opener);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 검토 항목 상세 ──

Future<void> showSafetyReviewItemSheet(BuildContext context, SafetyCheckResult item) =>
    CommonBottomSheets.showBottomSheet<void>(
      context: context,
      screenName: '/wallet-health/review',
      // 시트 제목은 점검 이름으로 짧게, 문장 제목은 본문 첫 줄로(POLISH C16)
      title: safetyCheckName(item.id),
      showDragHandle: true,
      showCloseButton: true,
      child: _ReviewSheet(item: item, opener: context),
    );

String _reviewTitle(SafetyCheckResult item) {
  final r = t.wallet_health.review;
  return switch (item.id) {
    SafetyCheckId.addressReuse => r.address_reuse.title,
    SafetyCheckId.appUpdate => r.app_update.title,
    SafetyCheckId.txConflict => r.tx_conflict.title,
    SafetyCheckId.serverCert => safetyIssueText(item),
    _ => safetyCheckName(item.id),
  };
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.item, required this.opener});

  final SafetyCheckResult item;
  final BuildContext opener;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  /// 상자에 처음 보이는 행 수(나머지는 "N개 더 보기")
  static const _visibleRows = 5;

  bool _showAll = false;
  bool _learnMore = false;

  /// 시트를 닫고 연 화면에서 다음 화면을 연다
  VoidCallback _go(void Function(BuildContext context) open) => () {
    Navigator.pop(context);
    if (widget.opener.mounted) open(widget.opener);
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final item = widget.item;
    final r = t.wallet_health.review;
    final walletId = item.walletId;
    final count = item.count ?? 0;
    // 잔액 숨김·가짜 잔액이면 실제 금액과 주소 조각을 보이지 않는다(설명과 동작은 그대로)
    final hidden = safetyHidesAmounts(context);
    void close() => Navigator.pop(context);

    var bodies = <String>[];
    var rows = <Widget>[];
    var primary = t.confirm;
    VoidCallback onPrimary = close;
    String? secondary;
    VoidCallback? onSecondary;
    String? learnMore;
    void openUtxo(BuildContext c, UtxoState utxo) =>
        Navigator.pushNamed(c, AppRouteNames.utxoDetail, arguments: UtxoDetailRouteArgs(utxo: utxo, id: walletId!));

    switch (item.id) {
      case SafetyCheckId.addressReuse:
        final walletName = safetyWalletOf(context, walletId)?.name;
        final utxos =
            walletId == null
                ? const <UtxoState>[]
                : context.read<WalletProvider?>()?.getUtxoList(walletId) ?? const <UtxoState>[];
        bodies = [r.address_reuse.body];
        // 주소마다 머리 + 그 주소에 남은 UTXO(최대 5개, 그 밖은 "외 N건"). 누르면 그 UTXO 상세(UI_SPEC §5.3, POLISH C42)
        rows = [
          for (final address in item.subjects)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AddressRow(address: hidden ? null : address, walletName: walletName),
                for (final (i, utxo) in utxos.where((u) => u.to == address).indexed)
                  if (i < 5)
                    _UtxoRow(
                      amount: hidden ? null : utxo.amount,
                      date: utxo.timestamp,
                      onTap: _go((c) => openUtxo(c, utxo)),
                    ),
                if (utxos.where((u) => u.to == address).length > 5)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text(
                      t.wallet_health.widget.more_items(n: utxos.where((u) => u.to == address).length - 5),
                      style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                    ),
                  ),
              ],
            ),
        ];
        if (walletId != null) {
          primary = r.address_reuse.view_utxos;
          onPrimary = _go(
            (c) => Navigator.pushNamed(c, AppRouteNames.utxoList, arguments: UtxoListRouteArgs(id: walletId)),
          );
          secondary = r.address_reuse.use_new_address;
          onSecondary = _go(
            (c) =>
                Navigator.pushNamed(c, AppRouteNames.receiveAddress, arguments: ReceiveAddressRouteArgs(id: walletId)),
          );
        }
      case SafetyCheckId.possibleDusting:
        bodies = [r.dusting.body, r.dusting.threshold(sats: SuspiciousTransactionUtil.suspiciousAmountThreshold)];
        final utxos =
            walletId == null
                ? const <UtxoState>[]
                : [
                  for (final id in item.subjects)
                    if (context.read<WalletProvider?>()?.getUtxoState(walletId, id) case final utxo?) utxo,
                ];
        rows = [
          for (final utxo in utxos)
            _UtxoRow(
              amount: hidden ? null : utxo.amount,
              date: utxo.timestamp,
              label: r.dusting.unlocked,
              onTap: _go((c) => openUtxo(c, utxo)),
            ),
        ];
        if (utxos.isNotEmpty) {
          primary = r.dusting.view_utxo;
          onPrimary = _go((c) => openUtxo(c, utxos.first));
        }
        secondary = r.dusting.learn_more;
        onSecondary = () => setState(() => _learnMore = !_learnMore);
        learnMore = r.dusting.learn_more_body;
      case SafetyCheckId.serverCert:
        final record = context.read<SafetyProvider?>()?.state.serverCert;
        primary = r.server_cert.open_server_settings;
        onPrimary = _go((c) => Navigator.pushNamed(c, AppRouteNames.electrumServer));
        if (item.detail == SafetyCheckDetail.expired || item.detail == SafetyCheckDetail.expiresSoon) {
          bodies = [
            item.detail == SafetyCheckDetail.expired
                ? r.server_cert.expired_body(n: math.max(1, count))
                : count == 0
                ? t.wallet_health.check.server_cert.expires_today
                : r.server_cert.expiring_body(n: count),
          ];
          final end = record?.endValidity;
          rows = [
            if (record != null) _KeyValueRow(label: r.server_cert.server, value: '${record.host}:${record.port}'),
            if (end != null) _KeyValueRow(label: r.server_cert.expires_on, value: DateTimeUtil.formatTimestamp(end)[0]),
            if (record != null)
              _KeyValueRow(label: r.server_cert.fingerprint, value: safetyShortFingerprint(record.fingerprint)),
          ];
        } else {
          // 지문 변경: 사용자가 직접 비교하도록 지문 전체를 보여 준다
          bodies = [r.server_cert.changed_body];
          rows = [
            if (item.subjects.isNotEmpty)
              _KeyValueRow(label: r.server_cert.previous_fingerprint, value: item.subjects.first),
            if (item.subjects.length > 1)
              _KeyValueRow(label: r.server_cert.current_fingerprint, value: item.subjects[1]),
          ];
          primary = t.wallet_health.critical.review_certificate;
        }
      case SafetyCheckId.appUpdate:
        bodies = [r.app_update.body];
        primary = t.alert.update.btn_update;
        onPrimary = () {
          close();
          InAppReview.instance.openStoreListing(appStoreId: APPSTORE_ID_REGTEST);
        };
      case SafetyCheckId.txConflict:
        // 대체된 받은 거래는 지갑 기록에서 지워져서 거래 상세로 갈 수 없다
        bodies = [r.tx_conflict.body];
      case SafetyCheckId.metadataBackup:
        bodies = [r.metadata.body];
        final exported = context.read<SafetyProvider?>()?.state.metadataExport?.at;
        rows = [
          _KeyValueRow(label: safetyCheckName(item.id), value: safetyFailedResultText(item), number: false),
          // 시각은 데이터라 저장 상태에서 읽는다(문구는 detail로 고른다)
          if (exported != null)
            _KeyValueRow(
              label: r.metadata.last_exported(time: formatHomeRelativeTime(exported, DateTime.now())),
              value: DateTimeUtil.formatTimestamp(exported).join(' '),
            ),
        ];
        primary = r.metadata.export_backup;
        onPrimary = _go(
          (c) => Navigator.pushNamed(c, AppRouteNames.labelExport, arguments: const LabelExportRouteArgs()),
        );
      default:
        bodies = [safetyIssueText(item)];
    }

    final moreRows = _showAll ? 0 : math.max(0, rows.length - _visibleRows);
    final shownRows = rows.take(rows.length - moreRows).toList();
    final reduceMotion = safetyReduceMotion(context);
    return SingleChildScrollView(
      key: const Key('wallet-health-review-sheet'),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_reviewTitle(item) != safetyCheckName(item.id)) ...[
            Semantics(
              header: true,
              child: Text(
                safetyKoText(_reviewTitle(item)),
                style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText),
              ),
            ),
            CoconutLayout.spacing_200h,
          ],
          for (final (i, body) in bodies.indexed) ...[
            if (i > 0) CoconutLayout.spacing_200h,
            Text(safetyKoText(body), style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
          ],
          if (learnMore != null)
            AnimatedSize(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
              alignment: Alignment.topCenter,
              child:
                  _learnMore
                      ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          safetyKoText(learnMore),
                          style: CoconutTypography.body2_14.setColor(colors.primaryText),
                        ),
                      )
                      : const SizedBox(width: double.infinity),
            ),
          if (shownRows.isNotEmpty) ...[
            CoconutLayout.spacing_400h,
            _Box(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, row) in shownRows.indexed) ...[
                    if (i > 0) Divider(color: colors.divider, height: 1, indent: 16, endIndent: 16),
                    row,
                  ],
                  if (moreRows > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Center(
                        child: CoconutUnderlinedButton(
                          text: r.more(n: moreRows),
                          onTap: () => setState(() => _showAll = true),
                          textStyle: CoconutTypography.body3_12_Bold,
                          defaultColor: colors.secondaryTextStrong,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          CoconutLayout.spacing_600h,
          InlineActionButton(key: const Key('wallet-health-review-primary'), text: primary, onPressed: onPrimary),
          if (secondary != null && onSecondary != null) ...[
            CoconutLayout.spacing_300h,
            Center(
              child: CoconutUnderlinedButton(
                text: secondary,
                onTap: onSecondary,
                textStyle: CoconutTypography.body3_12_Bold,
                defaultColor: colors.secondaryTextStrong,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 다시 쓴 주소 한 줄의 머리: 가운데를 줄인 주소 + 지갑 이름(남은 UTXO는 아래 줄들이 보여 준다)
class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, required this.walletName});

  /// null = 숨김
  final String? address;
  final String? walletName;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 가운데를 줄인다
          if (address != null)
            Text(
              TextUtils.truncate(address!, 28, 12, 12),
              style: CoconutTypography.body3_12_Number.setColor(colors.primaryText),
            ),
          if (address == null)
            Text(
              safetyKoText(safetyCheckName(SafetyCheckId.addressReuse)),
              style: CoconutTypography.body3_12.setColor(colors.primaryText),
            ),
          if (walletName != null) Text(walletName!, style: CoconutTypography.caption_10.setColor(colors.secondaryText)),
        ],
      ),
    );
  }
}

/// UTXO 한 줄(금액·날짜, 누르면 UTXO 상세). 더스팅 의심과 주소 재사용 시트가 같이 쓴다
class _UtxoRow extends StatelessWidget {
  const _UtxoRow({required this.amount, required this.date, required this.onTap, this.label});

  /// null = 숨김(잔액 숨김·가짜 잔액)
  final int? amount;
  final DateTime date;
  final VoidCallback onTap;

  /// 날짜 앞에 붙는 말(더스팅: "잠기지 않음")
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final secondary = CoconutTypography.body3_12.setColor(colors.secondaryText);
    return SafetyPressRow(
      background: colors.surfaceBottomSheetElevated,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  amount == null
                      ? Text(t.premium.assist.hidden, style: CoconutTypography.body3_12.setColor(colors.primaryText))
                      : Text(
                        BitcoinUnit.sats.displayBitcoinAmount(amount, withUnit: true),
                        style: CoconutTypography.body3_12_Number.setColor(colors.primaryText),
                      ),
                  Text(
                    [if (label != null) label!, DateTimeUtil.formatTimestamp(date).join(' ')].join(' · '),
                    style: secondary,
                  ),
                ],
              ),
            ),
            CoconutLayout.spacing_200w,
            const SafetyChevron(),
          ],
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value, this.number = true});

  final String label;
  final String value;

  /// 숫자·주소·지문만 숫자 글꼴(SpaceGrotesk에는 한글이 없다)
  final bool number;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(safetyKoText(label), style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
          CoconutLayout.spacing_50h,
          Text(
            number ? value : safetyKoText(value),
            style: (number ? CoconutTypography.body3_12_Number : CoconutTypography.body3_12).setColor(
              colors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 권장 점검 ──

/// 직접 확인하는 권장 점검. 표시하면 "직접 확인함"(검증됨 아님)
Future<void> showSafetyRecommendedSheet(BuildContext context, RecommendedItem item) {
  final id = item.id;
  final check = item.check;
  if (check != null) return showSafetyReviewItemSheet(context, check);
  if (id == null) return Future.value();
  return CommonBottomSheets.showBottomSheet<void>(
    context: context,
    screenName: '/wallet-health/recommended',
    title: safetyRecommendedSheetTitle(id),
    showDragHandle: true,
    showCloseButton: true,
    child: Builder(
      builder: (context) {
        final colors = context.coconutColors;
        final r = t.wallet_health.recommended;
        // 큰 글자·작은 화면에서도 표시 버튼까지 내려갈 수 있게(POLISH C38)
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 이 점검이 무엇을 확인하는지 한 줄, 그다음 공통 안내(R41)
              Text(
                safetyKoText(safetyRecommendedBody(id)),
                style: CoconutTypography.body2_14.setColor(colors.primaryText),
              ),
              CoconutLayout.spacing_400h,
              Text(safetyKoText(r.intro), style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
              CoconutLayout.spacing_600h,
              InlineActionButton(
                key: const Key('wallet-health-recommended-toggle'),
                text: item.done ? r.mark_not_done : r.mark_done,
                onPressed: () {
                  final provider = context.read<SafetyProvider?>();
                  Navigator.pop(context);
                  if (!item.done) vibrateLight();
                  provider?.setRecommendedDone(id, !item.done);
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}
