import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutPopup, CoconutUnderlinedButton;
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_screen.dart';
import 'package:coconut_wallet/screens/premium/premium_paywall_screen.dart';
import 'package:coconut_wallet/screens/safety/assist/safety_assist_screen.dart';
import 'package:coconut_wallet/screens/safety/help_channels_sheet.dart';
import 'package:coconut_wallet/screens/safety/incident_sheets.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/services/safety/safety_assist.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/button_group.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_guide_scaffold.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_wallet_card.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_health_cards.dart' show safetyHidesAmounts;
import 'package:coconut_wallet/widgets/features/transaction/card/transaction_item_card.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// 가이드 경로 이름 접두사. "나중에 하기"·"완료"는 이 이름의 경로를 모두 닫는다(Safety Assist 화면도 같은 접두사)
const _routePrefix = '/safety-guide/';

/// Security Guide(Free): STEP1 다른 지갑 확인 → STEP2 남은 비트코인 보호 → STEP3 사용 주의 → STEP4 보관 점검 → 완료.
/// 단계는 사건의 guideStep(1–4)에 남아서 거래 상세 배너·알림 목록에서 이어 할 수 있다
abstract final class SecurityGuide {
  static Future<void> start(BuildContext context, String incidentId) => _open(context, incidentId, restart: true);

  static Future<void> resume(BuildContext context, String incidentId) => _open(context, incidentId, restart: false);

  static Future<void> _open(BuildContext context, String incidentId, {required bool restart}) async {
    final provider = context.read<SafetyProvider?>();
    final incident = provider?.state.incidents.firstWhereOrNull((i) => i.id == incidentId);
    if (provider == null || incident == null || incident.state == IncidentState.recognized) return;
    // 끝난 사건은 "가이드 다시 보기": 처음부터 보여 주고 사건 상태·단계는 바꾸지 않는다
    final review = incident.state == IncidentState.completed;
    final guide = _Guide(
      incidentId: incidentId,
      walletId: incident.walletId,
      fromTxDetail: ModalRoute.of(context)?.settings.name == AppRouteNames.transactionDetail,
      review: review,
    );
    // 가이드는 "모르는 거래" 대응이다
    if (incident.state == IncidentState.detected) {
      await provider.markIncidentUnrecognized(incidentId, safetyResponseMode(context));
    }
    // Premium 이동을 보낸 뒤 보내기 완료 화면이 흐름을 비웠으면 "거래를 보냈어요"부터(그때 STEP3로 기록)
    if (!restart && !review && incident.guideStep < 3 && _sentAfterAssist(incident, provider.state.lastBroadcast)) {
      await provider.setIncidentGuideStep(incidentId, 3);
      if (context.mounted) await Navigator.of(context).push(_route('submitted', _Submitted(guide: guide)));
      return;
    }
    final step = restart || review || incident.guideStep < 1 ? 1 : incident.guideStep.clamp(1, 4);
    if (!review && step != incident.guideStep) await provider.setIncidentGuideStep(incidentId, step);
    if (context.mounted) await guide.push(context, step);
  }
}

/// 대응(Safety Assist)을 시작한 뒤 이 지갑에서 성공한 전송이 있음(대응 거래의 증거. 이어 하기·요약이 같이 쓴다)
bool _sentAfterAssist(SafetyIncident incident, WalletTxEvent? lastBroadcast) {
  final assistAt = incident.assistStartedAt;
  return assistAt != null &&
      lastBroadcast != null &&
      lastBroadcast.walletId == incident.walletId &&
      lastBroadcast.at.isAfter(assistAt);
}

class _Guide {
  const _Guide({required this.incidentId, required this.walletId, required this.fromTxDetail, this.review = false});

  final String incidentId;
  final int walletId;

  /// 끝난 사건을 다시 보는 중(단계를 기록하지 않고 Premium 안내를 숨긴다)
  final bool review;

  /// 거래 상세에서 열었으면 보내기 후 거래 상세로, 아니면 홈으로 돌아간다(보내기 완료 화면이 이 경로까지 비운다)
  final bool fromTxDetail;

  Future<void> push(BuildContext context, int step) {
    final (String name, Widget page) = switch (step) {
      1 => ('step1', _Step1(guide: this)),
      2 => ('step2', _Step2(guide: this)),
      3 => ('step3', _Step3(guide: this)),
      _ => ('step4', _Step4(guide: this)),
    };
    return Navigator.of(context).push(_route(name, page));
  }

  /// 다음 단계를 기록하고 연다
  Future<void> next(BuildContext context, int step) async {
    if (!review) await context.read<SafetyProvider?>()?.setIncidentGuideStep(incidentId, step);
    if (context.mounted) await push(context, step);
  }

  /// 가이드를 연 곳(거래 상세·알림 목록 등)으로. 사건은 "대응 중"으로 남는다
  void close(BuildContext context) =>
      Navigator.of(context).popUntil((route) => !(route.settings.name ?? '').startsWith(_routePrefix));
}

Route<void> _route(String name, Widget page) =>
    CupertinoPageRoute<void>(settings: RouteSettings(name: '$_routePrefix$name'), builder: (_) => page);

class _Step1 extends StatelessWidget {
  const _Step1({required this.guide});

  final _Guide guide;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final strings = t.safety_guide.step1;
    return SafetyGuidePage(
      key: const Key('safety-guide-step1'),
      progress: 0.04,
      iconPath: FeatureWalletIconPath.walletAddConnected,
      title: strings.title,
      description: strings.body,
      buttonText: '',
      children: [
        _GuideCard(
          title: strings.checklist_title,
          items: [strings.item_device, strings.item_app, strings.item_hardware, strings.item_person],
        ),
        CoconutLayout.spacing_600h,
        Divider(color: colors.divider, height: 1),
        CoconutLayout.spacing_600h,
        Text(
          safetyKoText(strings.question),
          textAlign: TextAlign.center,
          style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText),
        ),
        CoconutLayout.spacing_400h,
        SafetyChoiceRow(
          key: const Key('safety-guide-step1-found'),
          title: strings.found_title,
          subtitle: strings.found_body,
          leading: safetyChoiceIcon(colors.successSurface, CommonStateIconPath.shieldCheck, colors.success),
          onTap: () async {
            if (await markIncidentRecognized(context, guide.incidentId) && context.mounted) guide.close(context);
          },
        ),
        CoconutLayout.spacing_200h,
        SafetyChoiceRow(
          key: const Key('safety-guide-step1-not-found'),
          title: strings.not_found_title,
          subtitle: t.safety_guide.recognize.no_body,
          leading: safetyChoiceIcon(colors.dangerSurface, CommonStateIconPath.triangleWarning, colors.danger),
          onTap: () => guide.next(context, 2),
        ),
      ],
    );
  }
}

/// STEP2 Free: 기존 기능으로 직접 옮기는 체크리스트 + 아래에 Premium 안내 한 줄(결제 안내가 무료 대응보다 먼저 오지 않게)
class _Step2 extends StatelessWidget {
  const _Step2({required this.guide});

  final _Guide guide;

  @override
  Widget build(BuildContext context) {
    final strings = t.safety_guide.step2;
    final balance = context.watch<WalletProvider?>()?.getWalletBalance(guide.walletId).total;
    return SafetyGuidePage(
      key: const Key('safety-guide-step2'),
      progress: 0.25,
      iconPath: FeatureShortcutIconPath.utxos,
      title: strings.title,
      description: strings.free_body,
      buttonText: guide.review ? t.safety_guide.next_step : strings.moved,
      onButton: () => guide.review ? guide.next(context, 3) : _confirmMoved(context),
      laterText: t.safety_guide.do_it_later,
      onLater: () => guide.close(context),
      children: [
        SafetyWalletCard(walletId: guide.walletId),
        if (balance == 0) ...[
          CoconutLayout.spacing_300h,
          Text(
            safetyKoText(strings.nothing_to_move),
            textAlign: TextAlign.center,
            style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
          ),
        ],
        CoconutLayout.spacing_600h,
        ButtonGroup(
          buttons: [
            _task(
              context,
              SingleButtonPosition.top,
              'create',
              FeatureWalletIconPath.walletAddDefault,
              t.wallet_home_screen.hot_wallet_add.create.title,
              strings.task_create_body,
              () => WalletAddScreen.openByWalletCount(context),
            ),
            _task(
              context,
              SingleButtonPosition.middle,
              'utxo',
              FeatureShortcutIconPath.utxos,
              strings.task_utxo,
              strings.task_utxo_body,
              () => Navigator.pushNamed(
                context,
                AppRouteNames.utxoOverview,
                arguments: UtxoOverviewRouteArgs(id: guide.walletId),
              ),
            ),
            _task(
              context,
              SingleButtonPosition.bottom,
              'send',
              FeatureShortcutIconPath.send,
              strings.task_send,
              strings.task_send_body,
              () => Navigator.pushNamed(
                context,
                AppRouteNames.send,
                arguments: SendRouteArgs(
                  id: guide.walletId,
                  sendEntryPoint: guide.fromTxDetail ? SendEntryPoint.transactionDetail : SendEntryPoint.home,
                ),
              ),
            ),
          ],
        ),
        if (!guide.review) ...[CoconutLayout.spacing_400h, _PremiumAssistRow(guide: guide)],
      ],
    );
  }

  /// ButtonGroup 안의 할 일 줄: 앱의 SingleButton과 같은 위치별 여백, 진동 없음(POLISH D19)
  Widget _task(
    BuildContext context,
    SingleButtonPosition position,
    String id,
    String icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => SafetyChoiceRow(
    key: Key('safety-guide-step2-$id'),
    padding: position.padding,
    haptic: false,
    title: title,
    subtitle: subtitle,
    leading: SvgPicture.asset(
      icon,
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
    ),
    backgroundColor: Colors.transparent,
    onTap: onTap,
  );

  /// "완료했어요"는 직접 확인한 결과로 저장된다는 확인을 한 번 받는다
  Future<void> _confirmMoved(BuildContext context) async {
    final strings = t.safety_guide.step2;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => CoconutPopup(
            languageCode: LocaleSettings.currentLocale.languageCode,
            title: strings.moved_confirm_title,
            description: strings.moved_confirm_body,
            leftButtonText: t.cancel,
            rightButtonText: strings.moved_confirm,
            rightButtonColor: context.coconutColors.primaryText,
            onTapLeft: () => Navigator.pop(dialogContext, false),
            onTapRight: () => Navigator.pop(dialogContext, true),
          ),
    );
    if (confirmed == true && context.mounted) await guide.next(context, 3);
  }
}

class _PremiumAssistRow extends StatelessWidget {
  const _PremiumAssistRow({required this.guide});

  final _Guide guide;

  @override
  Widget build(BuildContext context) {
    final service = context.read<EntitlementService?>();
    if (service == null) return const SizedBox.shrink();
    final colors = context.coconutColors;
    // 큰 글자(1.3배~)에서는 칩을 글 위에 둔다: 나란히면 칩이 폭을 크게 차지해 글이 여러 줄로 좁아진다(X7)
    final stacked = MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.3;
    Widget text(PremiumState premium) => Text(
      safetyKoText(premium.isActive ? t.premium.card.active_incident_body : t.premium.incident_chip.body),
      key: const Key('safety-guide-step2-premium-text'),
      style: CoconutTypography.body3_12.setColor(colors.primaryText),
    );
    return ValueListenableBuilder<PremiumState>(
      valueListenable: service.state,
      builder:
          (context, premium, _) => ShrinkAnimationButton(
            key: const Key('safety-guide-step2-premium'),
            onPressed: () => _open(context),
            defaultColor: colors.surface,
            borderRadius: CoconutStyles.radius_250,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child:
                        stacked
                            ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [const PremiumChip(), CoconutLayout.spacing_100h, text(premium)],
                            )
                            : Row(
                              children: [
                                const PremiumChip(),
                                CoconutLayout.spacing_200w,
                                Expanded(child: text(premium)),
                              ],
                            ),
                  ),
                  CoconutLayout.spacing_200w,
                  const SafetyChevron(),
                ],
              ),
            ),
          ),
    );
  }

  /// 페이월(구독 중이 아니면) → 대응 방식을 Premium으로(단계는 그대로) → Safety Assist.
  /// 끝나면 보안 점검을 이어 가거나 가이드를 닫는다
  Future<void> _open(BuildContext context) async {
    if (context.read<EntitlementService?>()?.state.value.isActive != true &&
        !await PremiumPaywallScreen.open(context)) {
      return;
    }
    if (!context.mounted) return;
    final provider = context.read<SafetyProvider?>();
    final incident = provider?.state.incidents.firstWhereOrNull((i) => i.id == guide.incidentId);
    if (incident != null && incident.isOpen && incident.responseMode != IncidentResponseMode.premium) {
      await provider!.markIncidentUnrecognized(guide.incidentId, IncidentResponseMode.premium);
    }
    if (!context.mounted) return;
    final exit = await SafetyAssistFlow.start(
      context,
      guide.incidentId,
      entryPoint: guide.fromTxDetail ? SendEntryPoint.transactionDetail : SendEntryPoint.home,
    );
    if (!context.mounted) return;
    switch (exit) {
      case AssistExit.continueReview:
        await guide.next(context, 3);
      case AssistExit.later:
        guide.close(context);
      case null:
        break;
    }
  }
}

/// 거래를 보냈어요(Premium 이동 뒤 이어 하기). 대응 중 만든 새 핫월렛이 백업 전이면 "지금 백업하기"
class _Submitted extends StatelessWidget {
  const _Submitted({required this.guide});

  final _Guide guide;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final strings = t.safety_guide.move;
    final broadcast = context.watch<SafetyProvider?>()?.state.lastBroadcast;
    final wallets = context.watch<WalletProvider?>();
    // 이번 이동 거래를 실제로 받은, 아직 백업하지 않은 핫월렛(Track H가 출력 주소·넘겨준 목적지로 찾는다)
    final unbacked =
        broadcast == null || wallets == null
            ? null
            : SafetyAssist.unbackedHotWalletFor(wallets, walletId: broadcast.walletId, txid: broadcast.txid);
    final record = broadcast == null ? null : wallets?.getTransactionRecord(broadcast.walletId, broadcast.txid);
    final preferences = context.watch<PreferenceProvider?>();
    return SafetyResultPage(
      key: const Key('safety-guide-submitted'),
      progress: 0.25,
      title: strings.submitted_title,
      description: strings.submitted_body,
      buttonText: t.safety_guide.continue_review,
      onButton: () => Navigator.of(context).pushReplacement(_route('step3', _Step3(guide: guide))),
      subWidget:
          unbacked == null
              ? null
              : CoconutUnderlinedButton(
                key: const Key('safety-guide-back-up-now'),
                text: strings.back_up_now,
                defaultColor: colors.secondaryTextStrong,
                onTap: () => SafetyAssist.openBackup(context, unbacked.id),
              ),
      children: [
        if (record != null && broadcast != null)
          // 잔액 숨김·가짜 잔액이거나 설정을 모르면 금액 없이 "보낸 거래 · 지갑 이름"(안전 화면 공용 규칙)
          if (preferences == null || safetyHidesAmounts(context))
            SafetyChoiceRow(
              key: const Key('safety-guide-submitted-tx'),
              title: t.wallet_health.critical.sent_transaction,
              subtitle: incidentWalletOf(context, broadcast.walletId)?.name,
              onTap: () => _openDetail(context, broadcast.walletId, broadcast.txid),
            )
          else
            TransactionItemCard(
              key: const Key('safety-guide-submitted-tx'),
              tx: record,
              currentUnit: preferences.currentUnit,
              id: broadcast.walletId,
              backgroundColor: colors.surface,
              borderRadius: CoconutStyles.radius_250,
              onPressed: () => _openDetail(context, broadcast.walletId, broadcast.txid),
            ),
        if (unbacked != null) ...[
          CoconutLayout.spacing_400h,
          Text(
            safetyKoText(strings.backup_reminder),
            textAlign: TextAlign.center,
            style: CoconutTypography.body3_12.setColor(colors.secondaryText),
          ),
        ],
      ],
    );
  }
}

void _openDetail(BuildContext context, int walletId, String txid) => Navigator.pushNamed(
  context,
  AppRouteNames.transactionDetail,
  arguments: TransactionDetailRouteArgs(id: walletId, txHash: txid),
);

class _Step3 extends StatelessWidget {
  const _Step3({required this.guide});

  final _Guide guide;

  @override
  Widget build(BuildContext context) {
    final strings = t.safety_guide.step3;
    return SafetyGuidePage(
      key: const Key('safety-guide-step3'),
      progress: 0.5,
      iconPath: CommonStateIconPath.stopSign,
      title: strings.title,
      description: '${strings.body}\n\n${strings.sync_note}',
      buttonText: guide.review ? t.safety_guide.next_step : strings.mark,
      onButton: () => _mark(context),
      laterText: t.safety_guide.do_it_later,
      onLater: () => guide.close(context),
    );
  }

  Future<void> _mark(BuildContext context) async {
    // 다시 보기: 사용 주의를 새로 표시하지 않고(표시 완료 화면도 없이) STEP4로
    if (guide.review) {
      await Navigator.of(context).push(_route('step4', _Step4(guide: guide)));
      return;
    }
    final provider = context.read<SafetyProvider?>();
    await provider?.setCaution(guide.walletId, true);
    await provider?.setIncidentGuideStep(guide.incidentId, 4);
    if (!context.mounted) return;
    await Navigator.of(context).push(_route('step3-marked', _Step3Marked(guide: guide)));
  }
}

class _Step3Marked extends StatelessWidget {
  const _Step3Marked({required this.guide});

  final _Guide guide;

  @override
  Widget build(BuildContext context) {
    final strings = t.safety_guide.step3;
    return SafetyResultPage(
      key: const Key('safety-guide-step3-marked'),
      progress: 0.75,
      title: strings.marked_title,
      description: strings.marked_body,
      buttonText: t.safety_guide.next_step,
      // 결과 화면은 뒤로 갈 수 없으므로 STEP4로 바꿔 끼운다(STEP4의 ←는 STEP3)
      onButton: () => Navigator.of(context).pushReplacement(_route('step4', _Step4(guide: guide))),
      children: [SafetyWalletCard(walletId: guide.walletId, animateBadge: true)],
    );
  }
}

class _Step4 extends StatelessWidget {
  const _Step4({required this.guide});

  final _Guide guide;

  @override
  Widget build(BuildContext context) {
    final strings = t.safety_guide.step4;
    final wallet = incidentWalletOf(context, guide.walletId);
    final (title, body) = switch (wallet) {
      null || WalletItemBase(hasLocalKey: true) => (strings.hot_title, strings.hot_body),
      WalletItemBase(walletType: WalletType.multiSignature) => (strings.multisig_title, strings.multisig_body),
      _ => (strings.watch_only_title, strings.watch_only_body),
    };
    return SafetyGuidePage(
      key: const Key('safety-guide-step4'),
      progress: 0.75,
      iconPath: FeatureShortcutIconPath.mnemonicWordList,
      title: title,
      description: body,
      buttonText: strings.complete,
      onButton: () => _complete(context),
      laterText: strings.maybe_exposed,
      // 노출이 의심된다고 표시하고 대응 안내만 연다(자금 이동 단계로 되돌리지 않는다)
      onLater: () async {
        await _recordReview(context, RecoveryReviewStatus.exposureSuspected);
        if (context.mounted) await showExposureSheet(context);
      },
      children: [
        _ReviewStatusLine(incidentId: guide.incidentId),
        _GuideCard(
          title: strings.consider_title,
          items: [strings.consider_photo, strings.consider_cloud, strings.consider_entered, strings.consider_access],
        ),
      ],
    );
  }

  Future<void> _complete(BuildContext context) async {
    final provider = context.read<SafetyProvider?>();
    final incident = provider?.state.incidents.firstWhereOrNull((i) => i.id == guide.incidentId);
    // 직접 점검을 마쳤다는 기록. 앞서 노출 의심으로 표시했으면 그 표시를 지킨다(더 조심할 쪽을 남긴다)
    if (incident?.recoveryReview != RecoveryReviewStatus.exposureSuspected && context.mounted) {
      await _recordReview(context, RecoveryReviewStatus.completedByUser);
    }
    if (incident?.state == IncidentState.responding) await provider!.completeIncident(guide.incidentId);
    if (!context.mounted) return;
    await Navigator.of(context).push(_route('done', _Done(guide: guide)));
  }

  /// 복구 자료 자가 점검 기록(R33). 끝난 사건 다시 보기는 아무것도 바꾸지 않는다.
  /// 기록은 덧붙임일 뿐이라, 실패해도(그사이 지갑·사건이 사라짐 등) 가이드는 그대로 이어 간다
  Future<void> _recordReview(BuildContext context, RecoveryReviewStatus status) async {
    if (guide.review) return;
    try {
      await context.read<SafetyProvider?>()?.recordRecoveryReview(guide.incidentId, status);
    } catch (_) {}
  }
}

/// 다시 열었을 때 이 사건의 복구 자료 점검 상태(직접 점검함 / 노출 의심으로 표시함). 아직 없으면 그리지 않는다.
/// 차분하게: 보조 글과 회색 아이콘(검증했다고 말하지 않는다)
class _ReviewStatusLine extends StatelessWidget {
  const _ReviewStatusLine({required this.incidentId});

  final String incidentId;

  @override
  Widget build(BuildContext context) {
    final incident = context.watch<SafetyProvider?>()?.state.incidents.firstWhereOrNull((i) => i.id == incidentId);
    final strings = t.safety_guide.step4;
    final (icon, text) = switch (incident?.recoveryReview) {
      RecoveryReviewStatus.completedByUser => (CommonFormIconPath.circleCheck, strings.status_reviewed),
      RecoveryReviewStatus.exposureSuspected => (CommonStateIconPath.circleInfo, strings.status_exposure_suspected),
      _ => (null, null),
    };
    if (icon == null || text == null) return const SizedBox.shrink();
    final colors = context.coconutColors;
    return Padding(
      key: const Key('safety-guide-step4-review-status'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            icon,
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
          ),
          CoconutLayout.spacing_150w,
          Flexible(
            child: Text(safetyKoText(text), style: CoconutTypography.body3_12.setColor(colors.secondaryTextStrong)),
          ),
        ],
      ),
    );
  }
}

/// 완료. Free는 "다음 동기화 때 다시 확인"(상시 감시를 암시하지 않는다), Premium은 대응 요약 + 도움 받기
class _Done extends StatelessWidget {
  const _Done({required this.guide});

  final _Guide guide;

  @override
  Widget build(BuildContext context) {
    final strings = t.safety_guide.complete;
    final provider = context.watch<SafetyProvider?>();
    final incident = provider?.state.incidents.firstWhereOrNull((i) => i.id == guide.incidentId);
    final isCaution = provider?.isCaution(guide.walletId) ?? false;
    final isPremium = incident?.responseMode == IncidentResponseMode.premium;
    return SafetyResultPage(
      key: const Key('safety-guide-done'),
      progress: 1,
      title: isPremium ? strings.premium_title : strings.title,
      description:
          isPremium
              ? strings.premium_body
              : isCaution
              ? strings.free_body_marked
              : strings.free_body,
      buttonText: t.done,
      onButton: () => guide.close(context),
      children: [
        if (isPremium && incident != null) ...[
          _PremiumSummary(incident: incident, isCaution: isCaution, lastBroadcast: provider!.state.lastBroadcast),
          CoconutLayout.spacing_600h,
          SafetyChoiceRow(
            key: const Key('safety-guide-help'),
            title: t.safety_guide.help_center.open,
            subtitle: t.safety_guide.help_center.subtitle,
            leading: SvgPicture.asset(
              CommonStateIconPath.circleHelp,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
            ),
            onTap: () => showHelpChannelsSheet(context),
          ),
          CoconutLayout.spacing_300h,
        ],
        const HelpCenterNeverAsksNote(),
      ],
    );
  }
}

class _PremiumSummary extends StatelessWidget {
  const _PremiumSummary({required this.incident, required this.isCaution, required this.lastBroadcast});

  final SafetyIncident incident;
  final bool isCaution;
  final WalletTxEvent? lastBroadcast;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final strings = t.safety_guide.complete;
    final txStates = t.wallet_health.incident.tx_state;
    // 대응을 시작하기 전의 보통 전송이나 다른 지갑의 전송은 대응 거래로 보지 않는다
    final responded = _sentAfterAssist(incident, lastBroadcast);
    final rows = [
      (
        strings.suspicious_tx,
        switch (incident.txState) {
          IncidentTxState.pending => txStates.unconfirmed,
          IncidentTxState.confirmed => txStates.confirmed,
          IncidentTxState.replaced => txStates.replaced,
          IncidentTxState.dropped => txStates.dropped,
        },
      ),
      (strings.response_tx, responded ? strings.sent : strings.none),
      (strings.current_wallet, isCaution ? t.safety_guide.caution.badge : strings.wallet_normal),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(CoconutStyles.radius_250)),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) CoconutLayout.spacing_300h,
            // 이름표와 값 모두 폭 안에서 줄을 바꾼다(긴 독일어 값이 줄을 넘지 않게, WalletSafetyStatusRow와 같은 배치)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    safetyKoText(rows[i].$1),
                    style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                  ),
                ),
                CoconutLayout.spacing_300w,
                Expanded(
                  child: Text(
                    safetyKoText(rows[i].$2),
                    textAlign: TextAlign.end,
                    style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 단계 화면의 회색 안내 카드(제목 + ①②③④)
class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(CoconutStyles.radius_250)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(safetyKoText(title), style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
          CoconutLayout.spacing_400h,
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) CoconutLayout.spacing_300h,
            SafetyNumberedRow(number: i + 1, title: items[i]),
          ],
        ],
      ),
    );
  }
}
