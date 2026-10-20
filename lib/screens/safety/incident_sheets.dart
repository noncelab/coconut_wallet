import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutPopup, CoconutToast, CoconutUnderlinedButton;
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/safety/help_channels_sheet.dart';
import 'package:coconut_wallet/screens/safety/security_guide_screen.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/transaction_safety_banner.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_health_cards.dart' show safetyHidesAmounts;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// openSafetyIncident가 연 거래 상세에서 배너가 인지 시트를 한 번 띄우도록 남기는 표시
String? _autoReviewIncidentId;

/// 사건 거래 상세를 연다. [autoReview]면 상세의 배너가 전환이 끝나고 300ms 뒤 인지 시트를 띄운다.
/// 거래 기록이 지갑에서 사라졌으면(대체·추방) 상세 대신 인지 시트를 바로 띄운다(없는 거래 상세는 열 수 없다).
Future<void> openSafetyIncident(
  BuildContext context, {
  required int walletId,
  required String txid,
  bool autoReview = true,
}) async {
  final incidentId = '$walletId:$txid';
  final wallets = context.read<WalletProvider?>();
  if (wallets != null && wallets.getTransactionRecord(walletId, txid) == null) {
    final incident = incidentOrPending(context, walletId, txid);
    switch (incident.state) {
      case IncidentState.detected:
        await showRecognizeSheet(context, incident);
      // 이미 대응 중이면 다시 묻지 않고 저장된 단계에서 이어 간다
      case IncidentState.responding:
        await SecurityGuide.resume(context, incident.id);
      // 끝난 사건은 저장된 사건으로 읽기 전용 요약(완료면 "가이드 다시 보기")
      case IncidentState.recognized || IncidentState.completed:
        await _showIncidentSummary(context, walletId, txid);
    }
    return;
  }
  _autoReviewIncidentId = autoReview ? incidentId : null;
  await Navigator.of(
    context,
  ).pushNamed(AppRouteNames.transactionDetail, arguments: TransactionDetailRouteArgs(id: walletId, txHash: txid));
  if (_autoReviewIncidentId == incidentId) _autoReviewIncidentId = null;
}

/// 거래 기록이 없는 끝난 사건: 거래 상세 배너와 같은 내용을 시트로 보여 준다
Future<void> _showIncidentSummary(BuildContext context, int walletId, String txid) =>
    CommonBottomSheets.showBottomSheet<void>(
      context: context,
      title: t.wallet_health.critical.review_transaction,
      screenName: '/incident/summary',
      showDragHandle: true,
      showCloseButton: true,
      child: Builder(
        builder:
            (sheetContext) => Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.paddingOf(sheetContext).bottom),
              child: TransactionSafetyBanner(walletId: walletId, txHash: txid),
            ),
      ),
    );

/// 거래 상세 배너가 부른다. openSafetyIncident가 이 사건의 자동 검토를 요청했으면 한 번만 true
bool takeIncidentAutoReview(String incidentId) {
  if (_autoReviewIncidentId != incidentId) return false;
  _autoReviewIncidentId = null;
  return true;
}

/// 사건이 아직 없으면(지갑을 추가할 때 이미 대기 중이던 출금) 같은 인지 시트를 쓰려고 임시 사건을 만든다.
/// 어느 쪽을 고르든 SafetyProvider가 그 txid를 받아 처리한다(모르는 거래면 그때 진짜 사건이 생긴다)
SafetyIncident incidentOrPending(BuildContext context, int walletId, String txid) =>
    context.read<SafetyProvider?>()?.incidentFor(walletId, txid) ??
    SafetyIncident(walletId: walletId, txid: txid, detectedAt: DateTime.now());

WalletItemBase? incidentWalletOf(BuildContext context, int walletId) =>
    context.read<WalletProvider?>()?.walletItemList.firstWhereOrNull((wallet) => wallet.id == walletId);

/// "내 거래예요": 기록하고 가볍게 진동 + 토스트(인지 시트와 가이드 STEP1이 같이 쓴다). 인지했으면 true.
/// [askShared]면 같은 거래가 다른 지갑에도 열려 있을 때 먼저 묻는다(인지 시트는 시트 안에서 이미 물었다)
Future<bool> markIncidentRecognized(BuildContext context, String incidentId, {bool askShared = true}) async {
  final provider = context.read<SafetyProvider?>();
  final incident = provider?.state.incidents.firstWhereOrNull((i) => i.id == incidentId);
  // 끝난 사건(가이드 다시 보기)은 바꾸지 않는다. 사건이 없으면 기준점 검토 항목
  if (provider == null || (incident != null && !incident.isOpen)) return false;
  if (askShared && !await confirmSharedRecognition(context, incidentId)) return false;
  try {
    await provider.recognizeIncident(incidentId);
  } on StateError {
    return false; // 그사이 사라진 항목
  }
  vibrateLight();
  if (context.mounted) {
    CoconutToast.showToast(
      context: context,
      text: t.safety_guide.recognize.recognized_toast,
      isVisibleIcon: true,
      iconPath: CommonStateIconPath.circleInfo,
    );
  }
  return true;
}

/// 같은 거래가 다른 지갑에도 열려 있으면 그 지갑의 알림도 함께 닫힌다는 것을 묻는다(레드팀 §6).
/// 다른 지갑이 없거나 "함께 표시하기"면 true, 취소면 false(아무것도 바꾸지 않는다)
Future<bool> confirmSharedRecognition(BuildContext context, String incidentId) async {
  final provider = context.read<SafetyProvider?>();
  final separator = incidentId.indexOf(':'); // 사건 id = '지갑:txid'
  final walletId = int.tryParse(incidentId.substring(0, separator));
  final txid = incidentId.substring(separator + 1);
  final wallets = [
    for (final other in provider?.state.incidents ?? const <SafetyIncident>[])
      if (other.txid == txid && other.walletId != walletId && other.isOpen)
        incidentWalletOf(context, other.walletId)?.name ?? '#${other.walletId}',
  ];
  if (wallets.isEmpty) return true;
  final strings = t.safety_guide.recognize;
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => CoconutPopup(
          key: const Key('incident-recognize-shared'),
          languageCode: LocaleSettings.currentLocale.languageCode,
          title: strings.shared_title,
          description: strings.shared_body(wallets: wallets.join(', ')),
          leftButtonText: t.cancel,
          rightButtonText: strings.shared_confirm,
          rightButtonColor: context.coconutColors.primaryText,
          onTapLeft: () => Navigator.pop(dialogContext, false),
          onTapRight: () => Navigator.pop(dialogContext, true),
        ),
  );
  return confirmed == true && context.mounted;
}

/// 사건 대응 시작 시점의 구독 상태(분석 이벤트 mode)
IncidentResponseMode safetyResponseMode(BuildContext context) =>
    context.read<EntitlementService?>()?.state.value.isActive == true
        ? IncidentResponseMode.premium
        : IncidentResponseMode.free;

/// "이 거래를 알고 있나요?" → 내 거래면 인지, 모르면 "지금 할 일" 시트 → 시작하기 = Security Guide STEP1
Future<void> showRecognizeSheet(BuildContext context, SafetyIncident incident) async {
  final wallet = incidentWalletOf(context, incident.walletId);
  final safety = context.read<SafetyProvider?>();
  // 고르기 전에 사실(보낸 금액·받는 주소)부터 보여 준다. 거래 기록이 없으면 생략
  final record = context.read<WalletProvider?>()?.getTransactionRecord(incident.walletId, incident.txid);
  // 사건이 아닌 검토 항목이면 그 항목의 설명(지갑을 추가하기 전·추가할 때의 출금 / 코코넛 밖 자기 앞 전송)
  final baseline =
      safety?.incidentFor(incident.walletId, incident.txid) == null ? safety?.state.baselines[incident.walletId] : null;
  final review = t.wallet_health.review;
  final body = switch (baseline) {
    final b? when b.unexpectedSelfTxids.contains(incident.txid) => review.self_transfer.body,
    final b? when b.pendingSentAtBaseline.contains(incident.txid) => review.recent_at_add.body,
    _ => t.safety_guide.recognize.body,
  };
  final unit = context.read<PreferenceProvider?>()?.currentUnit ?? BitcoinUnit.btc;
  final facts =
      record == null
          ? null
          : (
            amount: unit.displayBitcoinAmount(record.amount.abs(), withUnit: true),
            recipients: _recipientsOf(context, incident.walletId, record),
          );
  final sheetKey = GlobalKey();
  final recognized = await CommonBottomSheets.showBottomSheet<bool>(
    context: context,
    title: t.wallet_health.critical.review_transaction,
    screenName: '/incident/recognize',
    showDragHandle: true,
    child: _RecognizeSheet(
      key: sheetKey,
      incidentId: incident.id,
      body: body,
      facts: facts,
      signedElsewhere: wallet != null && !wallet.hasLocalKey,
    ),
  );
  if (recognized == null || !context.mounted) return;
  if (recognized) {
    await markIncidentRecognized(context, incident.id, askShared: false);
    return;
  }
  final provider = context.read<SafetyProvider?>();
  final current = provider?.state.incidents.firstWhereOrNull((i) => i.id == incident.id);
  if (provider == null || (current != null && !current.isOpen)) return;
  if (current == null || current.state == IncidentState.detected) {
    try {
      await provider.markIncidentUnrecognized(incident.id, safetyResponseMode(context));
    } on StateError {
      return;
    }
  }
  // 앞 시트가 화면에서 완전히 내려간 뒤 다음 시트를 띄운다(핫월렛 앱 잠금 안내 시트와 같은 방식)
  while (sheetKey.currentContext != null) {
    await WidgetsBinding.instance.endOfFrame;
  }
  if (!context.mounted) return;
  // 이 지갑에 막힘 없는 비상 이동 초안이 있으면 "지금 이동"이 주 버튼(구독이 끝나도 초안은 쓸 수 있다)
  final rescue = context.read<RescueReadyProvider?>();
  final canMoveNow = rescue?.canMoveNow(incident.walletId) ?? false;
  final choice = await CommonBottomSheets.showCustomHeightBottomSheet<_WhatToDoChoice>(
    context: context,
    screenName: '/incident/what-to-do',
    heightRatio: 0.85,
    enableDragToResize: false,
    childBuilder:
        (controller) => _WhatToDoSheet(
          controller: controller,
          rescueDestination: canMoveNow ? _destinationName(context, rescue!.destinationOf(incident.walletId)) : null,
        ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == _WhatToDoChoice.moveNow) {
    await rescue?.moveNow(context, incident.walletId);
  } else {
    // 새 대응은 단계 0이라 STEP1부터, 이미 대응 중이던 사건은 저장된 단계를 지킨다
    await SecurityGuide.resume(context, incident.id);
  }
}

enum _WhatToDoChoice { guide, moveNow }

/// 비상 목적지 이름(지갑이면 지갑 이름, 주소면 주소). 모르면 빈 문자열
String _destinationName(BuildContext context, RescueDestination? destination) {
  final walletId = destination?.walletId;
  if (walletId != null) return incidentWalletOf(context, walletId)?.name ?? '';
  return destination?.address ?? '';
}

class _RecognizeSheet extends StatelessWidget {
  const _RecognizeSheet({
    super.key,
    required this.incidentId,
    required this.body,
    this.facts,
    required this.signedElsewhere,
  });

  final String incidentId;
  final String body;
  final ({String amount, List<String> recipients})? facts;

  /// 보기 전용·다중서명이면 다른 기기에서 서명했을 수 있다는 안내 한 줄
  final bool signedElsewhere;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final strings = t.safety_guide.recognize;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 4 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.title,
            textAlign: TextAlign.center,
            style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText),
          ),
          CoconutLayout.spacing_200h,
          Text(body, textAlign: TextAlign.center, style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
          // 잔액 숨김·가짜 잔액이거나 설정을 모르면 금액·주소를 보이지 않는다(안전 화면 공용 규칙)
          if (facts != null && !safetyHidesAmounts(context)) ...[CoconutLayout.spacing_400h, _FactsBox(facts: facts!)],
          CoconutLayout.spacing_500h,
          SafetyChoiceRow(
            key: const Key('incident-recognize-yes'),
            title: strings.yes_title,
            subtitle: strings.yes_body,
            leading: safetyChoiceIcon(colors.successSurface, CommonStateIconPath.shieldCheck, colors.success),
            backgroundColor: colors.surfaceBottomSheetElevated,
            // 다른 지갑에도 같은 거래가 있으면 시트 위에서 묻고, 취소하면 이 시트에 남는다
            onTap: () async {
              if (await confirmSharedRecognition(context, incidentId) && context.mounted) Navigator.pop(context, true);
            },
          ),
          CoconutLayout.spacing_200h,
          SafetyChoiceRow(
            key: const Key('incident-recognize-no'),
            title: strings.no_title,
            subtitle: strings.no_body,
            leading: safetyChoiceIcon(colors.dangerSurface, CommonStateIconPath.triangleWarning, colors.danger),
            backgroundColor: colors.surfaceBottomSheetElevated,
            onTap: () => Navigator.pop(context, false),
          ),
          if (signedElsewhere) ...[
            CoconutLayout.spacing_300h,
            // 사실과 선택지보다 작은 보조 안내(지원 사칭이 "내 거래예요"로 이끄는 말로 쓰이지 않게)
            Text(
              strings.signed_elsewhere,
              key: const Key('incident-recognize-signed-elsewhere'),
              textAlign: TextAlign.center,
              style: CoconutTypography.caption_10.setColor(colors.secondaryText),
            ),
          ],
          // 지원을 사칭해 "내 거래예요"를 누르게 하는 말에 맞서, 같은 화면에 "절대 묻지·시키지 않아요"
          CoconutLayout.spacing_500h,
          const HelpCenterNeverAsksNote(),
        ],
      ),
    );
  }
}

/// 받는 곳: 이 지갑 주소(거스름)와 주소 없는 출력(스크립트 자리표시 '')을 뺀 출력 주소. 모두 내 주소면 빈 목록
List<String> _recipientsOf(BuildContext context, int walletId, TransactionRecord record) {
  final wallets = context.read<WalletProvider?>();
  return {
    for (final output in record.outputAddressList)
      if (output.address.isNotEmpty && !(wallets?.containsAddress(walletId, output.address) ?? false)) output.address,
  }.toList();
}

/// 주소 가운데 줄임(앞 10 · 뒤 8)
String _middleShort(String address) =>
    address.length <= 21 ? address : '${address.substring(0, 10)}…${address.substring(address.length - 8)}';

/// 인지 시트의 사실 상자(보낸 금액 · 받는 주소, UI_SPEC §5.4 v2.1)
class _FactsBox extends StatelessWidget {
  const _FactsBox({required this.facts});

  final ({String amount, List<String> recipients}) facts;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final strings = t.safety_guide.recognize;
    final label = CoconutTypography.body3_12.setColor(colors.secondaryText);
    final recipients = facts.recipients;
    return Container(
      key: const Key('incident-recognize-facts'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceBottomSheetElevated,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_250),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(strings.amount_sent, style: label),
              const Spacer(),
              Text(facts.amount, style: CoconutTypography.body3_12_NumberBold.setColor(colors.primaryText)),
            ],
          ),
          // 받는 곳이 모두 내 주소(자기 앞 전송)면 줄을 뺀다
          if (recipients.isNotEmpty) ...[
            Divider(color: colors.divider, height: 17),
            Row(
              children: [
                Text(strings.recipient, style: label),
                CoconutLayout.spacing_400w,
                Expanded(
                  child: Text(
                    _middleShort(recipients.first),
                    key: const Key('incident-recognize-recipient'),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoconutTypography.body3_12_Number.setColor(colors.primaryText),
                  ),
                ),
                if (recipients.length > 1) ...[
                  CoconutLayout.spacing_100w,
                  Text(
                    strings.recipient_more(n: recipients.length - 1),
                    key: const Key('incident-recognize-recipient-more'),
                    style: label,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 선택지 행 왼쪽 36 원 아이콘(인지 시트·가이드 STEP1)
Widget safetyChoiceIcon(Color background, String iconPath, Color iconColor) => SafetyIconCircle(
  size: 36,
  background: background,
  icon: SvgPicture.asset(iconPath, width: 18, height: 18, colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn)),
);

/// "지금 할 일" 시트(0.85 고정 높이). [rescueDestination]이 있으면 비상 이동 초안이 준비된 Premium 변형
class _WhatToDoSheet extends StatelessWidget {
  const _WhatToDoSheet({required this.controller, this.rescueDestination});

  final ScrollController controller;
  final String? rescueDestination;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final strings = t.safety_guide.unknown;
    final steps = [
      (strings.step1_title, strings.step1_body),
      (strings.step2_title, strings.step2_body),
      (strings.step3_title, strings.step3_body),
      (strings.step4_title, strings.step4_body),
    ];
    return Stack(
      children: [
        ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            Center(
              child: Container(
                width: 55,
                height: 4,
                decoration: BoxDecoration(color: colors.bottomSheetHandle, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            CoconutLayout.spacing_600h,
            Center(
              child: SafetyIconCircle(
                size: 48,
                background: colors.dangerSurface,
                icon: SvgPicture.asset(
                  CommonStateIconPath.triangleWarning,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(colors.danger, BlendMode.srcIn),
                ),
              ),
            ),
            CoconutLayout.spacing_400h,
            Text(
              strings.title,
              textAlign: TextAlign.center,
              style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText),
            ),
            CoconutLayout.spacing_200h,
            Text(
              strings.body,
              textAlign: TextAlign.center,
              style: CoconutTypography.body2_14.setColor(colors.secondaryText),
            ),
            CoconutLayout.spacing_600h,
            if (rescueDestination != null) ...[
              Row(
                children: [
                  const PremiumChip(),
                  CoconutLayout.spacing_200w,
                  Expanded(
                    child: Text(
                      t.premium.rescue.destination_line(destination: rescueDestination!),
                      style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                    ),
                  ),
                ],
              ),
              CoconutLayout.spacing_300h,
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceBottomSheetElevated,
                borderRadius: BorderRadius.circular(CoconutStyles.radius_250),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.what_to_do, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
                  CoconutLayout.spacing_400h,
                  for (var i = 0; i < steps.length; i++) ...[
                    if (i > 0) CoconutLayout.spacing_400h,
                    SafetyNumberedRow(number: i + 1, title: steps[i].$1, description: steps[i].$2),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (rescueDestination == null)
          FixedBottomButton(
            buttonKey: const Key('incident-what-to-do-start'),
            text: strings.get_started,
            surroundingsColor: colors.surfaceBottomSheet,
            onButtonClicked: () => Navigator.pop(context, _WhatToDoChoice.guide),
          )
        else
          FixedBottomButton(
            buttonKey: const Key('incident-what-to-do-move-now'),
            text: t.premium.rescue.move_now,
            surroundingsColor: colors.surfaceBottomSheet,
            onButtonClicked: () => Navigator.pop(context, _WhatToDoChoice.moveNow),
            subWidget: CoconutUnderlinedButton(
              key: const Key('incident-what-to-do-step-by-step'),
              text: strings.step_by_step,
              defaultColor: colors.secondaryTextStrong,
              onTap: () => Navigator.pop(context, _WhatToDoChoice.guide),
            ),
          ),
      ],
    );
  }
}

/// 노출 의심 시트. 자금 이동은 다시 권하지 않는다
Future<void> showExposureSheet(BuildContext context) {
  final strings = t.safety_guide.exposure;
  return CommonBottomSheets.showBottomSheet<void>(
    context: context,
    title: strings.title,
    screenName: '/safety-guide/exposure',
    showDragHandle: true,
    showCloseButton: true,
    child: Builder(
      builder:
          (sheetContext) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.paddingOf(sheetContext).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SafetyNumberedRow(number: 1, title: strings.no_reuse_title, description: strings.no_reuse_body),
                CoconutLayout.spacing_400h,
                SafetyNumberedRow(
                  number: 2,
                  title: strings.other_wallets_title,
                  description: strings.other_wallets_body,
                ),
                CoconutLayout.spacing_400h,
                SafetyNumberedRow(
                  number: 3,
                  title: strings.remove_copies_title,
                  description: strings.remove_copies_body,
                ),
                CoconutLayout.spacing_600h,
                const HelpCenterNeverAsksNote(),
                CoconutLayout.spacing_600h,
                InlineActionButton(
                  key: const Key('safety-exposure-got-it'),
                  text: strings.got_it,
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
    ),
  );
}
