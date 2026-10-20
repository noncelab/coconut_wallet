import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutAppBar, CoconutTextField, CoconutToast, CoconutToastLevel, CoconutUnderlinedButton;
import 'package:coconut_lib/coconut_lib.dart' show NetworkType;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/safety/assist/assist_move_screens.dart';
import 'package:coconut_wallet/screens/safety/help_channels_sheet.dart';
import 'package:coconut_wallet/services/fee_service.dart';
import 'package:coconut_wallet/services/safety/conflict_analyzer.dart';
import 'package:coconut_wallet/services/safety/safety_assist.dart';
import 'package:coconut_wallet/services/safety/sweep_builder.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart' show CoconutToast, CoconutToastLevel;
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/custom_wallet_icons.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_address_entry_sheet.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart' show formatHomeRelativeTime;
import 'package:coconut_wallet/widgets/features/safety/safety_verification_line.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_wallet_card.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_health_cards.dart' show safetyHidesAmounts;
import 'package:coconut_wallet/widgets/features/safety/safety_guide_scaffold.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_icon_small.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// 대응 흐름을 닫은 이유. null = 뒤로 가기, 또는 전송 후 보내기 완료 화면이 흐름을 비움
enum AssistExit { later, continueReview }

/// Premium Safety Assist: 분석(P1) → 대응 선택(P2)/대체 불가(P6) → 목적지 → (새 핫월렛·새 지갑 추가) → 서명 전 검토 →
/// 기존 보내기 확인. 서명·전송은 언제나 기존 화면에서 사용자가 한다
abstract final class SafetyAssistFlow {
  /// 가이드 STEP2(Premium)에서. 구독 중이 아니면 페이월부터. 사건 거래 상세에서 열었으면
  /// [entryPoint]를 transactionDetail로(전송 뒤 그 화면으로 돌아감), 아니면 home
  static Future<AssistExit?> start(
    BuildContext context,
    String incidentId, {
    SendEntryPoint entryPoint = SendEntryPoint.home,
  }) async {
    // 대체 자동 준비를 시작하는 순간의 권한으로 판단한다(페이월 결과 값은 믿지 않음)
    if (!await ensurePremium(context) || !context.mounted) return null;
    final safety = context.read<SafetyProvider>();
    final incident = safety.state.incidents.where((i) => i.id == incidentId).firstOrNull;
    if (incident == null) return null;
    unawaited(
      safety.setIncidentGuideStep(incident.id, incident.guideStep, assistStartedAt: DateTime.now()).catchError((_) {}),
    );
    final session = AssistSession(
      wallet: context.read<WalletProvider>().getWalletById(incident.walletId),
      incidentTxids: _openTxids(safety.state, incident.walletId, also: incident.txid),
      entryPoint: entryPoint,
      opener: ModalRoute.of(context),
      // 비상 목적지는 Rescue-ready만 가진다(SafetyProvider 상태는 예전 값일 수 있음)
      rescue: context.read<RescueReadyProvider?>()?.destinationOf(incident.walletId),
    );
    await Navigator.of(context).push(assistRoute('assist', _AssistHomeScreen(session: session)));
    return session.exitReason;
  }

  /// 비상 이동 [지금 이동](Track I). 구독이 끝나도 동작한다(사용자가 시작하는 이동).
  /// [destination]은 Track I가 누른 순간 다시 확인한 비상 목적지다(다른 곳에서 읽지 않는다).
  /// 수수료를 지금 다시 가져오고, 실패할 때만 [fallbackFeeRate](마지막 수수료)를 쓴다(그땐 "다시 계산했어요" 안내를 뺀다).
  /// 열린 사건의 충돌을 넣어 검토 화면으로 바로 간다
  static Future<void> moveNow(
    BuildContext context, {
    required int walletId,
    required RescueDestination destination,
    double? fallbackFeeRate,
  }) async {
    final state = context.read<SafetyProvider?>()?.state;
    final session = AssistSession(
      wallet: context.read<WalletProvider>().getWalletById(walletId),
      incidentTxids: state == null ? const [] : _openTxids(state, walletId),
      entryPoint: SendEntryPoint.home,
      opener: ModalRoute.of(context),
      rescue: destination,
      isMoveNow: true,
      fallbackFeeRate: fallbackFeeRate,
    );
    await Navigator.of(context).push(assistRoute('assist', _AssistHomeScreen(session: session)));
  }

  @visibleForTesting
  static ConflictAnalyzer Function(BuildContext context)? analyzerOverride;
  @visibleForTesting
  static Future<double?> Function()? fastFeeRateOverride;
  @visibleForTesting
  static Future<double?> Function()? nodeFeeRateOverride;

  /// 이번 실행에서 마지막으로 받은 정상 빠른 수수료율(Grok §4 대체 값)
  static double? _lastGoodFeeRate;
  @visibleForTesting
  static void resetLastGoodFeeRate() => _lastGoodFeeRate = null;

  static List<String> _openTxids(SafetyState state, int walletId, {String? also}) =>
      {
        for (final i in state.incidents)
          if (i.walletId == walletId && i.isCritical) i.txid,
        if (also != null) also,
      }.toList();
}

/// 단계 화면 경로. 가이드 경로 접두사와 같아서 가이드의 "나중에 하기"가 함께 닫는다
Route<T> assistRoute<T>(String name, Widget page) =>
    CupertinoPageRoute<T>(settings: RouteSettings(name: '/safety-guide/$name'), builder: (_) => page);

/// 아직 열린 기준점 검토 거래(최근 출금·앱이 만들지 않은 자기 앞 전송). 엔진과 같은 규칙: 지갑 기록에 있고 인지·앱이 만든
/// 거래·사건이 아님. 사용자 거래일 수 있어 대체하지 않는다(그 코인은 이동 금액에 없음, Grok G6)
Set<String> _openReviewTxids(BuildContext context, int walletId) {
  final state = context.read<SafetyProvider?>()?.state;
  final baseline = state?.baselines[walletId];
  if (state == null || baseline == null) return const {};
  final records = context.read<WalletProvider>();
  final incidents = {for (final i in state.incidents) i.txid};
  return {
    for (final txid in {...baseline.pendingSentAtBaseline, ...baseline.unexpectedSelfTxids})
      if (records.getTransactionRecord(walletId, txid) != null &&
          !state.recognizedTxids.contains(txid) &&
          !state.isAppCreated(txid) &&
          !incidents.contains(txid))
        txid,
  };
}

/// 화면 사이에서 넘기는 분석 결과·선택
class AssistSession {
  AssistSession({
    required this.wallet,
    required this.incidentTxids,
    required this.entryPoint,
    this.opener,
    this.rescue,
    this.isMoveNow = false,
    this.fallbackFeeRate,
  });

  /// 사고 지갑
  final WalletItemBase wallet;
  final List<String> incidentTxids;
  final SendEntryPoint entryPoint;
  final Route<dynamic>? opener;
  final RescueDestination? rescue;
  final bool isMoveNow;

  /// 지금 이동에서 수수료 조회가 실패하면 쓰는 마지막 수수료
  final double? fallbackFeeRate;

  /// 이번 분석에서 수수료를 새로 가져왔는지(아니면 마지막 수수료)
  bool feeRecalculated = false;

  /// 계획에 쓴 수수료율의 출처(새 값이 아니면 검토 화면에 알린다)
  FeeRateSource feeSource = FeeRateSource.fresh;

  List<SweepConflict> conflicts = const [];

  /// 충돌 입력 + 남은 입력. 막힘 없으면 대체 가능
  SweepPlan? replacement;

  /// 남은 코인만(충돌과 겨루지 않음)
  SweepPlan? remaining;
  bool replace = false;
  AssistExit? exitReason;

  /// 지금 계획을 만든 빠른 수수료율(검토 뒤 다시 계산할 때도 같은 값을 써서 수수료 변동만으로 바뀌지 않게)
  double? fastFeeRate;

  /// 대체 거래를 대체 하한(상대를 밀어내는 최소 수수료)으로. 고른 수수료율 때문에 20%를 넘을 때 "더 낮은 수수료"가 켠다(lead)
  bool replacementAtFloor = false;

  bool get canReplace => replacement?.blocker == null && (replacement?.conflicts.isNotEmpty ?? false);
  bool get hasRemaining => remaining?.blocker == null;
  SweepPlan get plan => replace ? replacement! : remaining!;

  /// 분석 결과로 두 계획(대체·남은 코인)을 만든다
  void computePlans(List<SweepConflict> conflicts, List<UtxoState> utxos, double fastFeeRate) {
    final pending = conflicts.where((c) => !c.confirmed).toList();
    this.conflicts = conflicts;
    this.fastFeeRate = fastFeeRate;
    // 하한으로: 수수료율 0이면 수수료 = 대체 하한(입력 걸러내기는 1 sat/vB·충돌 수수료율 기준)
    replacement =
        pending.isEmpty
            ? null
            : SweepBuilder.plan(
              wallet: wallet,
              utxos: utxos,
              conflicts: pending,
              fastFeeRate: replacementAtFloor ? 0 : fastFeeRate,
            );
    remaining = SweepBuilder.plan(wallet: wallet, utxos: utxos, conflicts: const [], fastFeeRate: fastFeeRate);
  }

  /// 검토한 뒤(지갑 만들기·추가로 시간이 지난 뒤 포함) UTXO·충돌을 다시 읽어 계획을 다시 만든다(AH2).
  /// 수수료율은 검토한 값 그대로. 넘길 계획이 달라졌으면 true(→ 바뀐 검토를 다시 승인받는다), 옮길 게 없어졌으면 null
  Future<bool?> refresh(BuildContext context) async {
    final walletProvider = context.read<WalletProvider>();
    final analyzer =
        SafetyAssistFlow.analyzerOverride?.call(context) ??
        ConflictAnalyzer(nodeProvider: context.read<NodeProvider>(), walletProvider: walletProvider);
    final state = context.read<SafetyProvider?>()?.state;
    final txids = {...incidentTxids, if (state != null) ...SafetyAssistFlow._openTxids(state, wallet.id)}.toList();
    final before = plan;
    final conflicts = await analyzer.analyze(wallet.id, txids);
    computePlans(conflicts, walletProvider.getUtxoList(wallet.id), fastFeeRate!);
    // 대체가 더는 안 되면(그 사이 확정 등) 남은 코인 이동으로 바꾸되 다시 승인받는다
    if (replace && !canReplace) replace = false;
    if (!(replace ? canReplace : hasRemaining)) return null;
    final after = plan;
    String key(SweepPlan p) => ([for (final u in p.inputs) u.utxoId]..sort()).join(',');
    String conflictIds(SweepPlan p) => ([for (final c in p.conflicts) c.txid]..sort()).join(',');
    return key(before) != key(after) ||
        before.fee != after.fee ||
        before.amount != after.amount ||
        conflictIds(before) != conflictIds(after) ||
        SweepFee.isFloorExempt(before) != SweepFee.isFloorExempt(after);
  }

  /// 흐름을 연 화면으로 돌아간다
  void exit(BuildContext context, AssistExit reason) {
    exitReason = reason;
    Navigator.of(context).popUntil((route) => route == opener || route.isFirst);
  }
}

enum _Phase { rescueReady, analyzing, failed, options, unavailable, nothingToMove }

/// P1 분석 → P2 선택지 / P6 대체 불가 / 옮길 것 없음. 한 경로 안에서 바뀐다(흐름의 첫 화면)
class _AssistHomeScreen extends StatefulWidget {
  const _AssistHomeScreen({required this.session});

  final AssistSession session;

  @override
  State<_AssistHomeScreen> createState() => _AssistHomeScreenState();
}

class _AssistHomeScreenState extends State<_AssistHomeScreen> {
  _Phase _phase = _Phase.analyzing;
  int _step = 0;

  AssistSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    // 준비된 비상 이동이 있으면 분석(P1)보다 먼저 보여 준다(UI_SPEC §10.6, AH8). 수수료 조회가 안 돼도 쓸 수 있다
    final rescueReady =
        !_session.isMoveNow &&
        context.read<RescueReadyProvider?>()?.canMoveNow(_session.wallet.id) == true &&
        resolveRescueDestination(context, _session) != null;
    if (rescueReady) {
      _phase = _Phase.rescueReady;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
    }
  }

  /// 비상 이동의 검증된 진입(Track I: 목적지 다시 확인·마지막 수수료 대체)으로 넘긴다
  Future<void> _moveViaRescueReady() => context.read<RescueReadyProvider>().moveNow(context, _session.wallet.id);

  /// 네트워크 실패는 자동으로 다시 하지 않는다(사용자가 다시 시도)
  Future<void> _analyze() async {
    setState(() {
      _phase = _Phase.analyzing;
      _step = 0;
    });
    final walletProvider = context.read<WalletProvider>();
    final analyzer =
        SafetyAssistFlow.analyzerOverride?.call(context) ??
        ConflictAnalyzer(nodeProvider: context.read<NodeProvider>(), walletProvider: walletProvider);
    final reduceMotion = safetyReduceMotion(context);
    Future<void> advance() async {
      if (!reduceMotion) await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) setState(() => _step++);
    }

    final node = context.read<NodeProvider?>();
    try {
      final conflicts = await analyzer.analyze(_session.wallet.id, _session.incidentTxids);
      await advance();
      double? fresh;
      try {
        fresh = await (SafetyAssistFlow.fastFeeRateOverride ?? _fetchFastFeeRate)();
      } catch (_) {}
      // 새 값이 없거나 비정상(음수·무한·1,000 sat/vB 초과·마지막 정상 값의 10배 초과)이면 마지막 정상 값 → 노드 추정(Grok §4, AH4)
      final lastGood = (_session.isMoveNow ? _session.fallbackFeeRate : null) ?? SafetyAssistFlow._lastGoodFeeRate;
      double? nodeRate;
      if (!SweepFee.isSane(fresh, lastGood: SweepFee.isSane(lastGood) ? lastGood : null) &&
          !SweepFee.isSane(lastGood)) {
        nodeRate = await (SafetyAssistFlow.nodeFeeRateOverride ?? () => _fetchNodeFeeRate(node))().catchError(
          (_) => null,
        );
      }
      final chosen = SweepFee.choose(fresh: fresh, lastGood: lastGood, node: nodeRate);
      if (!mounted) return;
      if (chosen == null) {
        setState(() => _phase = _Phase.failed);
        return;
      }
      if (chosen.source == FeeRateSource.fresh) SafetyAssistFlow._lastGoodFeeRate = chosen.rate;
      _session
        ..feeSource = chosen.source
        ..feeRecalculated = chosen.source == FeeRateSource.fresh;
      final utxos = walletProvider.getUtxoList(_session.wallet.id);
      await advance();
      _session.computePlans(conflicts, utxos, chosen.rate);
      await advance();
      await advance();
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.failed);
      return;
    }
    if (!mounted) return;
    vibrateLight();
    setState(
      () =>
          _phase =
              _session.canReplace
                  ? _Phase.options
                  : _session.hasRemaining
                  ? _Phase.unavailable
                  : _Phase.nothingToMove,
    );
    // 지금 이동: 의심 거래가 있는데 대체가 막혔으면 이유와 "의심 거래 코인은 빠진다"를 먼저 보여 준다(Grok §3)
    if (_session.isMoveNow && (_session.canReplace || _session.conflicts.isEmpty)) {
      unawaited(_moveToRescueDestination());
    }
  }

  static Future<double?> _fetchFastFeeRate() async => (await FeeService().getRecommendedFees())?.fastestFee;

  static Future<double?> _fetchNodeFeeRate(NodeProvider? node) async {
    if (node == null) return null;
    final result = await node.getRecommendedFees();
    return result.isSuccess ? result.value.fastestFee : null;
  }

  Future<void> _moveToRescueDestination() async {
    final destination = resolveRescueDestination(context, _session);
    if (destination == null) return;
    _session.replace = _session.canReplace;
    if (!_session.replace && !_session.hasRemaining) return;
    await Navigator.of(context).push(
      assistRoute(
        'move-review',
        AssistReviewScreen(session: _session, destination: destination, recalculated: _session.feeRecalculated),
      ),
    );
    // 지금 이동은 검토에서 돌아오면 흐름을 닫는다(전송했으면 보내기 완료 화면이 이미 비움)
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _choose({required bool replace}) async {
    // 대체 거래 자동 준비는 새 자동화라 누르는 순간 권한을 다시 확인한다. 지금 이동은 사용자가 시작한 초안이라 제외
    if (replace && !_session.isMoveNow && !await ensurePremium(context)) return;
    if (!mounted) return;
    // 지금 이동은 정해 둔 비상 목적지로 바로 검토
    if (_session.isMoveNow && !replace) return _moveToRescueDestination();
    _session.replace = replace;
    unawaited(Navigator.of(context).push(assistRoute('move-destination', AssistDestinationScreen(session: _session))));
  }

  @override
  Widget build(BuildContext context) {
    final strings = t.premium;
    switch (_phase) {
      case _Phase.rescueReady:
        final updated = context.read<RescueReadyProvider?>()?.drafts[_session.wallet.id]?.preparedAt;
        return SafetyGuidePage(
          key: const Key('safety-assist-rescue-ready'),
          progress: 0.25,
          icon: SvgPicture.asset(
            CustomWalletIcons.diamond,
            width: 32,
            height: 32,
            colorFilter: ColorFilter.mode(context.coconutColors.premiumText, BlendMode.srcIn),
          ),
          title: strings.rescue.incident_ready,
          // 초안 있음 → 마지막 갱신 · 검토할 때 다시 계산(POLISH H12, Health S3와 같은 말)
          description: [
            strings.rescue.card_body,
            [
              if (updated != null) strings.rescue.last_updated(time: formatHomeRelativeTime(updated, DateTime.now())),
              strings.rescue.recalc_note,
            ].join(' · '),
          ].join('\n'),
          buttonText: strings.rescue.move_now,
          onButton: _moveViaRescueReady,
          footer: CoconutUnderlinedButton(
            key: const Key('safety-assist-other-options'),
            text: strings.rescue.other_options,
            onTap: _analyze,
            defaultColor: context.coconutColors.secondaryTextStrong,
          ),
        );
      case _Phase.analyzing:
      case _Phase.failed:
        final failed = _phase == _Phase.failed;
        return SafetyGuidePage(
          key: const Key('safety-assist-analyzing'),
          progress: 0.25,
          title: strings.assist.analyzing_title,
          buttonText: t.retry,
          onButton: failed ? _analyze : null,
          children: [
            SafetyStepList(
              steps: [
                strings.assist.item_replacement,
                strings.assist.item_inputs,
                strings.assist.item_remaining,
                strings.assist.item_signing,
              ],
              activeIndex: _step,
              failed: failed,
            ),
            if (failed) ...[
              CoconutLayout.spacing_600h,
              SafetyStatusBanner(
                background: context.coconutColors.dangerSurface,
                iconPath: CommonStateIconPath.triangleWarning,
                iconColor: context.coconutColors.danger,
                title: t.safety_guide.move.prepare_failed,
                body: t.errors.network_error,
              ),
            ],
          ],
        );
      case _Phase.options:
        return SafetyGuidePage(
          key: const Key('safety-assist-options'),
          progress: 0.25,
          title: strings.assist.response_options,
          description: strings.assist.replacement_explain,
          buttonText: strings.assist.prepare_replacement,
          onButton: () => _choose(replace: true),
          footer:
              _session.hasRemaining
                  ? CoconutUnderlinedButton(
                    key: const Key('safety-assist-protect-remaining'),
                    text: strings.assist.protect_remaining,
                    onTap: () => _choose(replace: false),
                    defaultColor: context.coconutColors.secondaryTextStrong,
                  )
                  : null,
          children: [..._rescueCard(context), _summary(context), ..._notes(context), ..._help(context)],
        );
      case _Phase.unavailable:
        return SafetyGuidePage(
          key: const Key('safety-assist-unavailable'),
          progress: 0.25,
          iconPath: CommonStateIconPath.circleInfo,
          title: strings.protect.unavailable_title,
          // (의심 거래가 있으면) 그 코인은 되돌릴 수 없음 + 빈 줄 + 남은 코인은 옮길 수 있음. 이유는 맨 위 따로 한 줄(Grok §3, POLISH H11)
          description: [
            if (_session.conflicts.isNotEmpty) strings.assist.blocked_explain,
            strings.protect.unavailable_body,
          ].join('\n\n'),
          buttonText: strings.assist.protect_remaining,
          onButton: () => _choose(replace: false),
          children: [
            _InfoLine(key: const Key('safety-assist-unavailable-reason'), text: _unavailableReason()),
            CoconutLayout.spacing_400h,
            ..._rescueCard(context),
            _summary(context),
            ..._help(context),
          ],
        );
      case _Phase.nothingToMove:
        return SafetyGuidePage(
          key: const Key('safety-assist-nothing'),
          progress: 0.25,
          iconPath: CommonStateIconPath.circleInfo,
          title: strings.protect.none_remaining,
          description:
              _session.remaining?.blocker == SweepBlocker.tooLarge
                  ? t.premium.protect.reason_too_large
                  : _session.conflicts.isEmpty
                  ? null
                  : _unavailableReason(),
          buttonText: t.safety_guide.continue_review,
          onButton: () => _session.exit(context, AssistExit.continueReview),
          children: _help(context),
        );
    }
  }

  String _unavailableReason() {
    final strings = t.premium.protect;
    final blocker = _session.replacement?.blocker;
    if (_session.conflicts.any((c) => c.confirmed) || blocker == SweepBlocker.conflictConfirmed) {
      return strings.reason_confirmed;
    }
    return switch (blocker) {
      SweepBlocker.tooManyDescendants => strings.reason_descendants,
      SweepBlocker.unsupportedWallet => strings.reason_not_signable,
      SweepBlocker.insufficientForFee || SweepBlocker.belowDust => t.premium.replace.insufficient_fee,
      SweepBlocker.tooLarge => strings.reason_too_large,
      _ => strings.reason_replaced, // 분석에서 충돌 거래를 찾지 못함(대체·추방)
    };
  }

  Widget _summary(BuildContext context) {
    final colors = context.coconutColors;
    final unit = context.read<PreferenceProvider>().currentUnit;
    final remainingSats = _session.remaining?.inputs.fold<int>(0, (sum, u) => sum + u.amount) ?? 0;
    // 이름은 Flexible, 값은 Expanded(끝 정렬). 지금 글자 배율로 한 줄에 둘이 안 들어가면 이름 위·값 아래로 쌓는다
    // (값이 숫자 기둥처럼 갈리지 않게, GPT M6·POLISH H14)
    Widget row(String label, String value, {Color? valueColor, Key? key}) {
      final labelStyle = CoconutTypography.body2_14.setColor(colors.secondaryText);
      final valueStyle = CoconutTypography.body2_14_Bold.setColor(valueColor ?? colors.primaryText);
      final labelText = Text(safetyKoText(label), style: labelStyle);
      final valueText = Text(value, textAlign: TextAlign.end, style: valueStyle);
      return LayoutBuilder(
        key: key,
        builder: (context, constraints) {
          double width(String text, TextStyle style) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: style),
              textScaler: MediaQuery.textScalerOf(context),
              textDirection: Directionality.of(context),
              maxLines: 1,
            )..layout();
            final width = painter.width;
            painter.dispose();
            return width;
          }

          final fits = width(label, labelStyle) + 12 + width(value, valueStyle) <= constraints.maxWidth;
          return fits
              ? Row(children: [Flexible(child: labelText), CoconutLayout.spacing_300w, Expanded(child: valueText)])
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [labelText, CoconutLayout.spacing_100h, valueText],
              );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(CoconutStyles.radius_250)),
      child: Column(
        children: [
          row(
            t.premium.assist.replacement,
            _session.canReplace ? t.premium.assist.available : t.premium.assist.not_available,
            valueColor: _session.canReplace ? colors.success : colors.secondaryText,
            key: const Key('safety-assist-replacement-state'),
          ),
          CoconutLayout.spacing_300h,
          row(
            t.premium.assist.remaining_bitcoin,
            // 잔액 숨김·가짜 잔액이면 실제 금액을 보이지 않는다(H1)
            safetyHidesAmounts(context)
                ? t.premium.assist.hidden
                : unit.displayBitcoinAmount(remainingSats, withUnit: true),
          ),
        ],
      ),
    );
  }

  List<Widget> _notes(BuildContext context) {
    final colors = context.coconutColors;
    return [
      CoconutLayout.spacing_400h,
      Text(safetyKoText(t.premium.assist.sweep_note), style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
      if (_session.replacement?.anyConflictNonSignalling ?? false) ...[
        CoconutLayout.spacing_200h,
        _InfoLine(text: t.premium.replace.no_rbf_signal),
      ],
    ];
  }

  /// 비상 목적지가 있으면 Premium 경로 맨 위에 [지금 이동]
  List<Widget> _rescueCard(BuildContext context) {
    final destination = resolveRescueDestination(context, _session);
    if (destination == null || _session.isMoveNow) return const [];
    // Health S3와 같은 Premium 행동 카드(POLISH H3). 칩·밑줄 버튼 없이 카드 안 버튼 하나
    return [
      PremiumActionCard(
        key: const Key('safety-assist-rescue-card'),
        title: safetyKoText(t.premium.rescue.incident_ready),
        // 목적지 이름이 주소일 수 있어 문구 부분에만 줄바꿈 규칙(R1)
        body: '${destination.label} · ${safetyKoText(t.premium.rescue.recalc_note)}',
        button: safetyKoText(t.premium.rescue.move_now),
        onPressed: () {
          _session.replace = _session.canReplace;
          Navigator.of(context).push(
            assistRoute(
              'move-review',
              AssistReviewScreen(session: _session, destination: destination, recalculated: _session.feeRecalculated),
            ),
          );
        },
      ),
      CoconutLayout.spacing_400h,
    ];
  }

  List<Widget> _help(BuildContext context) => [
    CoconutLayout.spacing_600h,
    SafetyChoiceRow(
      key: const Key('safety-assist-help'),
      leading: SvgPicture.asset(
        CommonStateIconPath.circleHelp,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
      ),
      title: t.safety_guide.help_center.open,
      subtitle: t.safety_guide.help_center.subtitle,
      onTap: () => showHelpChannelsSheet(context),
    ),
    // 완료 화면과 같은 사기 예방 줄(POLISH H7)
    CoconutLayout.spacing_300h,
    const HelpCenterNeverAsksNote(),
  ];
}

/// 목적지: 지갑이면 그 지갑의 받기 주소, 주소면 그대로
class AssistTarget {
  const AssistTarget({required this.address, this.wallet, this.isExternal = false, this.isNewWallet = false});

  final String address;
  final WalletItemBase? wallet;

  /// 직접 입력 주소(코코넛이 확인할 수 없음)
  final bool isExternal;

  /// 이 흐름에서 만들거나 추가한 지갑(주소 상자 제목 "새 지갑 받기 주소")
  final bool isNewWallet;

  String get label => wallet?.name ?? shortAddress(address);
}

String shortAddress(String address) =>
    address.length <= 14 ? address : '${address.substring(0, 8)}…${address.substring(address.length - 6)}';

/// 비상 목적지를 지금 쓸 수 있는 목적지로. 사고 지갑·같은 MFP·사용 주의로 바뀌었거나 지워졌으면 null
AssistTarget? resolveRescueDestination(BuildContext context, AssistSession session) {
  final rescue = session.rescue;
  if (rescue == null) return null;
  // Track I와 같은 마지막 확인(저장해 둔 주소의 주인이 그 사이 제외 대상이 됐을 수 있다, AH1·I-1)
  final target = SafetyAssist.verifiedTarget(
    context.read<WalletProvider>(),
    source: session.wallet,
    destination: rescue,
    state: context.read<SafetyProvider?>()?.state,
  );
  if (target == null) return null;
  return AssistTarget(address: target.address, wallet: target.wallet, isExternal: target.wallet == null);
}

/// 목적지 선택(UI_SPEC §10.7). 사고 지갑·같은 MFP 지갑은 보이지 않는다
class AssistDestinationScreen extends StatelessWidget {
  const AssistDestinationScreen({super.key, required this.session});

  final AssistSession session;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final strings = t.premium.destination;
    context.watch<SafetyProvider?>();
    final destinations = SafetyAssist.destinations(
      incidentWallet: session.wallet,
      wallets: context.watch<WalletProvider>().walletItemList,
      safetyState: context.read<SafetyProvider?>()?.state,
      rescueDestination: session.rescue,
    );
    final children = <Widget>[];
    String? section;
    for (final d in destinations) {
      if (d.kind == AssistDestinationKind.manualAddress &&
          d.address != null &&
          SafetyAssist.checkDestination(
                context.read<WalletProvider>(),
                incidentWallet: session.wallet,
                address: d.address!,
                safetyState: context.read<SafetyProvider?>()?.state,
              ) !=
              null) {
        continue;
      }
      // 섹션 제목. 맨 위로 올린 비상 목적지만 따로 제목
      final heading =
          d.isRescueDestination && !d.onThisDevice
              ? t.premium.rescue.destination
              : switch (d.kind) {
                AssistDestinationKind.watchOnlyWallet => strings.watch_only_wallets,
                AssistDestinationKind.vaultNewWallet => strings.section_new,
                AssistDestinationKind.manualAddress => strings.section_manual,
                AssistDestinationKind.otherWallet => strings.other_wallets,
                AssistDestinationKind.newHotWallet => strings.section_this_device,
              };
      if (heading != section) {
        children.add(
          Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 0 : 24, bottom: 8),
            child: Text(safetyKoText(heading), style: CoconutTypography.body2_14_Bold.setColor(colors.secondaryText)),
          ),
        );
        section = heading;
      } else {
        children.add(CoconutLayout.spacing_200h);
      }
      children.add(_row(context, d));
    }
    children
      ..add(CoconutLayout.spacing_600h)
      ..add(
        SafetyChoiceRow(
          key: const Key('safety-assist-destination-later'),
          leading: _icon(context, CommonStateIconPath.circleInfo),
          title: t.safety_guide.step2_watch_only.later_title,
          subtitle: t.safety_guide.step2_watch_only.later_body,
          onTap: () => session.exit(context, AssistExit.later),
        ),
      );

    return SafetyGuidePage(
      key: const Key('safety-assist-destination'),
      progress: 0.25,
      title: session.wallet.hasLocalKey ? strings.title : t.safety_guide.step2_watch_only.question,
      description: strings.excluded_note,
      buttonText: '',
      children: children,
    );
  }

  Widget _icon(BuildContext context, String path) => SvgPicture.asset(
    path,
    width: 24,
    height: 24,
    colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
  );

  Widget _row(BuildContext context, AssistDestination d) {
    final strings = t.premium.destination;
    final wallet = d.wallet;
    final notes = [
      // 서명 기기 검증 상태도 줄 아래에(POLISH H8: 검토 화면과 같은 한 규칙)
      if (_verificationLine(context, wallet) case final line?) line,
      if (d.cannotVerifySeed) _InfoLine(text: strings.unknown_seed, iconSize: 12),
      // 새 핫월렛 줄만 "여기 만든 지갑도", 이미 있는 이 기기 핫월렛은 "키가 나갔다면 이 지갑도"(POLISH H16)
      if (d.onThisDevice)
        _WarningLine(
          text:
              d.kind == AssistDestinationKind.newHotWallet
                  ? strings.new_hot_wallet_warning
                  : strings.existing_hot_wallet_warning,
        ),
    ];
    // 이 기기 비상 목적지는 맨 위로 올리지 않아서 부제 앞에 표시한다
    String? walletSubtitle(WalletItemBase w) {
      final parts = [
        if (d.isRescueDestination && d.onThisDevice) t.premium.rescue.destination,
        // 이미 있는 지갑: 핫월렛은 종류만(새 니모닉 안내는 새 핫월렛 줄에만, H5)
        if (!d.cannotVerifySeed)
          w.hasLocalKey
              ? t.wallet_home_screen.wallet_filter.hot
              : '${strings.watch_only_wallets_body} · ${w.walletImportSource.displayName}',
      ];
      return parts.isEmpty ? null : parts.join(' · ');
    }

    final lifted = d.isRescueDestination && !d.onThisDevice;
    final rescueIcon = SvgPicture.asset(
      CustomWalletIcons.diamond,
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(context.coconutColors.premiumText, BlendMode.srcIn),
    );
    final below =
        notes.isEmpty
            ? null
            : notes.length == 1
            ? notes.single
            : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < notes.length; i++) ...[if (i > 0) CoconutLayout.spacing_100h, notes[i]],
              ],
            );
    return switch (d.kind) {
      AssistDestinationKind.watchOnlyWallet || AssistDestinationKind.otherWallet => SafetyChoiceRow(
        key: Key('safety-assist-destination-wallet-${wallet!.id}'),
        // 맨 위로 올린 비상 목적지: "비상 목적지로 옮기기 — 이름"(UI_SPEC §9.4)
        leading:
            lifted
                ? rescueIcon
                : WalletIconSmall(
                  walletImportSource: wallet.walletImportSource,
                  colorIndex: wallet.colorIndex,
                  iconIndex: wallet.iconIndex,
                  isHotWallet: wallet.hasLocalKey,
                ),
        title: lifted ? t.safety_guide.step2.move_to_rescue : wallet.name,
        subtitle: lifted ? wallet.name : walletSubtitle(wallet),
        below: below,
        onTap:
            () => _toReview(
              context,
              AssistTarget(
                address: SafetyAssist.receiveAddressOf(context.read<WalletProvider>(), wallet),
                wallet: wallet,
              ),
            ),
      ),
      AssistDestinationKind.vaultNewWallet => SafetyChoiceRow(
        key: const Key('safety-assist-destination-vault'),
        leading: _icon(context, FeatureWalletIconPath.walletAddConnected),
        title: strings.vault_new_wallet,
        subtitle: strings.vault_new_wallet_body,
        onTap:
            () => Navigator.of(context).push(
              assistRoute(
                'signer-new-wallet',
                AssistSignerGuideScreen(
                  sourceWallet: session.wallet,
                  // 추가한 지갑으로 "새 지갑 추가됨" → 거래 만들기(지금과 같음)
                  onAdded:
                      (context, wallet) => Navigator.of(context).pushReplacement(
                        assistRoute('wallet-added', AssistWalletAddedScreen(session: session, wallet: wallet)),
                      ),
                ),
              ),
            ),
      ),
      AssistDestinationKind.manualAddress when d.address != null => SafetyChoiceRow(
        key: const Key('safety-assist-destination-rescue-address'),
        leading: rescueIcon,
        title: t.safety_guide.step2.move_to_rescue,
        subtitle: shortAddress(d.address!),
        below: _WarningLine(text: strings.external_warning),
        onTap: () => _toReview(context, AssistTarget(address: d.address!, isExternal: true)),
      ),
      AssistDestinationKind.manualAddress => SafetyChoiceRow(
        key: const Key('safety-assist-destination-address'),
        leading: _icon(context, CommonActionIconPath.paste),
        title: strings.enter_address,
        onTap: () => _enterAddress(context),
      ),
      AssistDestinationKind.newHotWallet => SafetyChoiceRow(
        key: const Key('safety-assist-destination-new-hot'),
        leading: _icon(context, FeatureWalletIconPath.walletAddHot),
        title: strings.new_hot_wallet,
        subtitle: strings.new_hot_wallet_body,
        below: below,
        onTap:
            () => Navigator.of(context).push(assistRoute('move-progress', AssistNewHotWalletScreen(session: session))),
      ),
    };
  }

  void _toReview(BuildContext context, AssistTarget target) =>
      Navigator.of(context).push(assistRoute('move-review', AssistReviewScreen(session: session, destination: target)));

  Future<void> _enterAddress(BuildContext context) async {
    final walletProvider = context.read<WalletProvider>();
    SafetyState? safetyState() => context.read<SafetyProvider?>()?.state;
    final address = await showSafetyAddressEntrySheet(
      context,
      screenName: '/safety-guide/move-destination/address',
      actionText: t.next,
      fieldKey: const Key('safety-assist-address-field'),
      actionKey: const Key('safety-assist-address-confirm'),
      // 사고 지갑·같은 니모닉·사용 주의·위급 사건·검증 불일치 지갑의 주소는 직접 입력으로도 받지 않는다(넘길 때도 다시 확인)
      validate: (address) {
        final format = AddressValidator.validateAddress(address, NetworkType.currentNetworkType);
        if (format != null) return format.message;
        return switch (SafetyAssist.checkDestination(
          walletProvider,
          incidentWallet: session.wallet,
          address: address,
          safetyState: safetyState(),
        )) {
          null => null,
          DestinationProblem.invalidAddress => t.errors.address_error.invalid,
          _ => t.premium.destination.error_affected_address,
        };
      },
      // 제외 지갑의 받기·잔돈 주소 앞 1,000개씩과도 비교한다(한 번, 비동기, Grok §5). 확인하지 못하면 받지 않는다
      confirm: (address) async {
        final excluded = await SafetyAssist.derivesFromExcludedWallet(
          walletProvider,
          incidentWallet: session.wallet,
          address: address,
          safetyState: safetyState(),
        ).catchError((_) => true);
        return excluded ? t.premium.destination.error_affected_address : null;
      },
    );
    if (address == null || !context.mounted) return;
    _toReview(context, AssistTarget(address: address, isExternal: true));
  }
}

/// 서명 전 검토(move-review). 출발 ↓ 받는 곳, 받는 주소 대조, 대체 안내, 잠긴 UTXO·RBF 신호 안내 →
/// 기존 보내기 확인으로(핫월렛: 서명하고 보내기 / 보기 전용: 다음 → PSBT QR)
class AssistReviewScreen extends StatefulWidget {
  const AssistReviewScreen({super.key, required this.session, required this.destination, this.recalculated = false});

  final AssistSession session;
  final AssistTarget destination;

  /// 비상 이동(지금 이동): 수수료를 방금 다시 계산했음을 맨 위에
  final bool recalculated;

  @override
  State<AssistReviewScreen> createState() => _AssistReviewScreenState();
}

class _AssistReviewScreenState extends State<AssistReviewScreen> {
  bool _opening = false;

  /// 검토한 뒤 계획이 바뀌어 다시 보여 주는 중(한 번 더 눌러야 넘어간다)
  bool _updated = false;

  /// 대체 하한이 20%를 넘을 때 한 번 눌러 확인한 수수료. 같은 수수료일 때만 다음 누름이 넘긴다
  int? _acceptedFee;

  bool _floorFeeHigh(SweepPlan plan) => SweepFee.isExcessive(plan) && SweepFee.isFloorExempt(plan);

  Future<void> _confirm() async {
    if (_opening) return;
    final session = widget.session;
    // 대체 하한이 받는 금액의 20%를 넘으면 수수료·비율을 보여 주고 한 번 더 눌러야 넘긴다(lead 결정)
    if (_floorFeeHigh(session.plan) && _acceptedFee != session.plan.fee) {
      vibrateLightDouble();
      setState(() => _acceptedFee = session.plan.fee);
      return;
    }
    _opening = true;
    try {
      // 넘기기 직전에 UTXO·충돌을 다시 읽는다. 달라졌으면 바뀐 내용을 보여 주고 다시 승인받는다(AH2)
      final changed = await session.refresh(context);
      if (!mounted) return;
      if (changed == null) {
        _warn(t.premium.protect.none_remaining);
        Navigator.of(context).pop();
        return;
      }
      if (changed) {
        vibrateLightDouble();
        setState(() => _updated = true);
        return;
      }
      // 직접 입력·저장된 주소는 제외 지갑의 받기·잔돈 주소 앞 1,000개씩과도 비교한다(Grok §5)
      if (widget.destination.isExternal &&
          await SafetyAssist.derivesFromExcludedWallet(
            context.read<WalletProvider>(),
            incidentWallet: session.wallet,
            address: widget.destination.address,
            safetyState: context.read<SafetyProvider?>()?.state,
          )) {
        throw const AssistDestinationRejected(DestinationProblem.excludedOwner);
      }
      if (!mounted) return;
      await SafetyAssist.openConfirm(
        context,
        wallet: session.wallet,
        plan: session.plan,
        destination: widget.destination.address,
        destinationWalletId: widget.destination.wallet?.id,
        entryPoint: session.entryPoint,
      );
    } on AssistDestinationRejected catch (e) {
      if (!mounted) return;
      _warn(
        e.problem == DestinationProblem.invalidAddress
            ? t.errors.address_error.invalid
            : t.premium.destination.error_affected_address,
      );
      // 다른 주소로 바꿔 보내지 않고 목적지를 다시 고르게 한다(AH1)
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _warn(t.safety_guide.move.prepare_failed);
    } finally {
      _opening = false;
    }
  }

  /// 수수료가 너무 클 때: 대체 거래면 대체 하한까지 낮춘다(여전히 대체, lead). 아니면 빠른 수수료율을 절반으로(최소 1 sat/vB).
  /// 바뀐 검토를 다시 보여 준다
  void _lowerFee() {
    final session = widget.session;
    final utxos = context.read<WalletProvider>().getUtxoList(session.wallet.id);
    if (session.replace) {
      session.replacementAtFloor = true;
      session.computePlans(session.conflicts, utxos, session.fastFeeRate!);
      setState(() => _updated = true);
      return;
    }
    final rate = session.fastFeeRate ?? 1;
    if (rate <= 1) return _warn(t.premium.protect.none_remaining);
    session.computePlans(session.conflicts, utxos, (rate / 2).clamp(1, double.infinity).toDouble());
    setState(() => _updated = true);
  }

  /// 대체를 빼고 남은 코인만(사용자가 고를 때만, 자동으로 바꾸지 않는다). 의심 거래의 코인은 빠지고(안내 줄), 바뀐 검토를 다시 승인받는다
  void _moveRemainingOnly() => setState(() {
    widget.session.replace = false;
    _updated = true;
  });

  void _warn(String text) {
    vibrateLightDouble();
    CoconutToast.showToast(
      context: context,
      isVisibleIcon: true,
      iconPath: CommonStateIconPath.triangleWarning,
      text: text,
      level: CoconutToastLevel.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final session = widget.session;
    final plan = session.plan;
    final unit = context.read<PreferenceProvider>().currentUnit;
    final isHot = session.wallet.hasLocalKey;
    final lockedCount = plan.inputs.where((u) => u.status == UtxoStatus.locked).length;
    final strings = t.safety_guide.move;
    final target = widget.destination;

    // 수수료가 받는 금액의 20%를 넘으면 그대로는 못 보내고 더 낮은 수수료로 다시 계산하게 한다(Grok §4).
    // 대체 하한 그대로인 대체 거래는 예외: 수수료·비율을 보여 주고 한 번 더 눌러야 넘긴다(lead 결정)
    final excessive = SweepFee.isExcessive(plan);
    final floorFeeHigh = _floorFeeHigh(plan);
    final blocked = excessive && !floorFeeHigh;
    // 하한인 대체 거래는 대체한 채로 더 낮출 수 없다(남은 코인만 옮기기는 따로 고른다)
    final canLower = !(session.replace && plan.fee <= plan.feeFloor);
    final feeAccepted = floorFeeHigh && _acceptedFee == plan.fee;
    return SafetyGuidePage(
      key: const Key('safety-assist-review'),
      progress: 0.25,
      title: isHot ? strings.review_title : strings.wo_review_title,
      buttonText:
          blocked
              ? t.premium.assist.recalculate_lower_fee
              : feeAccepted
              ? t.premium.assist.replacement_fee_confirm
              : (isHot ? strings.sign_and_send : t.next),
      onButton: blocked ? _lowerFee : _confirm,
      buttonEnabled: !blocked || canLower,
      footer: Text(
        '${safetyKoText(strings.network_fee)} ${unit.displayBitcoinAmount(plan.fee, withUnit: true)}',
        key: const Key('safety-assist-review-fee'),
        style: CoconutTypography.body3_12.setColor(colors.secondaryText),
      ),
      children: [
        if (_updated) ...[
          _WarningLine(key: const Key('safety-assist-review-updated'), text: t.premium.assist.plan_updated),
          CoconutLayout.spacing_400h,
        ],
        if (widget.recalculated && !_updated) ...[
          Text(
            safetyKoText(t.premium.rescue.recalculated),
            key: const Key('safety-assist-review-recalculated'),
            textAlign: TextAlign.center,
            style: CoconutTypography.body3_12.setColor(colors.secondaryText),
          ),
          CoconutLayout.spacing_400h,
        ],
        _label(context, strings.from),
        SafetyWalletCard(walletId: session.wallet.id),
        CoconutLayout.spacing_300h,
        Center(
          child: SvgPicture.asset(
            CommonNavigationIconPath.arrowDown,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
          ),
        ),
        CoconutLayout.spacing_300h,
        _label(context, strings.to),
        if (target.wallet != null)
          SafetyWalletCard(walletId: target.wallet!.id)
        else
          _AddressBox(address: target.address),
        CoconutLayout.spacing_400h,
        Text(
          '${safetyKoText(t.send_amount)} ${unit.displayBitcoinAmount(plan.amount, withUnit: true)}',
          key: const Key('safety-assist-review-amount'),
          textAlign: TextAlign.center,
          style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText),
        ),
        // 대체가 막혀 남은 코인만 옮길 때: 의심 거래의 코인은 이 금액에 없다(Grok §3)
        if (!session.replace && session.conflicts.isNotEmpty) ...[
          CoconutLayout.spacing_200h,
          _InfoLine(key: const Key('safety-assist-review-excludes'), text: t.premium.assist.excludes_suspicious),
        ],
        // 아직 열린 기준점 검토 거래는 사용자 거래일 수 있어 대체하지 않는다. 그 코인도 빠진다(Grok G6, 중립 문구)
        if (_openReviewTxids(context, session.wallet.id).isNotEmpty) ...[
          CoconutLayout.spacing_200h,
          _InfoLine(
            key: const Key('safety-assist-review-excludes-review'),
            text: t.premium.assist.excludes_under_review,
          ),
        ],
        if (session.feeSource != FeeRateSource.fresh) ...[
          CoconutLayout.spacing_200h,
          _InfoLine(key: const Key('safety-assist-review-fee-fallback'), text: t.premium.assist.fee_fallback),
        ],
        if (blocked) ...[
          CoconutLayout.spacing_200h,
          _WarningLine(
            key: const Key('safety-assist-review-fee-excessive'),
            text: t.premium.assist.fee_too_high(percent: SweepFee.maxSharePercent),
          ),
        ],
        // 정확한 수수료는 아래 버튼 위 네트워크 수수료 줄(경고 줄은 2줄 안에 비율만)
        if (floorFeeHigh) ...[
          CoconutLayout.spacing_200h,
          _WarningLine(
            key: const Key('safety-assist-review-replacement-fee-high'),
            text: t.premium.assist.replacement_fee_high(percent: (plan.fee * 100 / plan.amount).ceil()),
          ),
        ],
        // 남은 코인만 옮기기는 사용자가 고를 때만(자동으로 바꾸지 않음, lead)
        if (session.replace && excessive && session.hasRemaining) ...[
          CoconutLayout.spacing_200h,
          Center(
            child: CoconutUnderlinedButton(
              key: const Key('safety-assist-review-remaining-only'),
              text: t.premium.assist.move_remaining_only,
              onTap: _moveRemainingOnly,
              defaultColor: colors.secondaryTextStrong,
            ),
          ),
        ],
        // 수수료 올리기 화면과 같은 기준(0.01 BTC 이상)
        if (plan.fee >= 1000000) ...[
          CoconutLayout.spacing_200h,
          _WarningLine(
            key: const Key('safety-assist-review-fee-high'),
            text: t.transaction_fee_bumping_screen.estimated_fee_too_high_error,
          ),
        ],
        CoconutLayout.spacing_600h,
        if (_verificationLine(context, target.wallet, key: const Key('safety-assist-review-verification'))
            case final line?) ...[
          line,
          CoconutLayout.spacing_200h,
        ],
        _AddressCheck(address: target.address, signingDevice: !isHot, isNewWallet: target.isNewWallet),
        if (target.isExternal) ...[
          CoconutLayout.spacing_200h,
          _WarningLine(text: t.premium.destination.external_warning),
        ],
        CoconutLayout.spacing_300h,
        // 사고 지갑의 키를 상대도 가졌을 수 있어서, 대체가 아닌 이동도 승인 전엔 다시 가져갈 수 있다
        if (session.replace)
          SafetyStatusBanner(
            key: const Key('safety-assist-review-replace-warning'),
            background: colors.warningSurface,
            iconPath: CommonStateIconPath.triangleWarning,
            iconColor: colors.warningText,
            title: t.premium.assist.sign_warning_title,
            body: t.premium.assist.sign_warning,
          )
        else
          _WarningLine(key: const Key('safety-assist-review-move-warning'), text: t.premium.assist.sign_warning),
        if (session.replace) ...[CoconutLayout.spacing_200h, _InfoLine(text: t.premium.replace.conflict_note)],
        if (lockedCount > 0) ...[
          CoconutLayout.spacing_200h,
          _InfoLine(
            key: const Key('safety-assist-review-locked'),
            text: t.premium.assist.locked_included(n: lockedCount),
            iconPath: CommonSecurityIconPath.lock,
          ),
        ],
        if (session.replace && plan.anyConflictNonSignalling) ...[
          CoconutLayout.spacing_200h,
          _InfoLine(key: const Key('safety-assist-review-no-rbf'), text: t.premium.replace.no_rbf_signal),
        ],
        if (session.replace && plan.conflicts.any((c) => !c.descendantsComplete)) ...[
          CoconutLayout.spacing_200h,
          _InfoLine(key: const Key('safety-assist-review-descendants'), text: t.premium.replace.descendants_incomplete),
        ],
        CoconutLayout.spacing_400h,
        Text(
          safetyKoText(strings.review_note),
          textAlign: TextAlign.center,
          style: CoconutTypography.body3_12.setColor(colors.secondaryText),
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(safetyKoText(text), style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText)),
  );
}

/// 직접 입력한 받는 주소 상자(지갑 카드 대신)
class _AddressBox extends StatelessWidget {
  const _AddressBox({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(CoconutStyles.radius_300)),
      child: Text(shortAddress(address), style: CoconutTypography.body2_14_NumberBold.setColor(colors.primaryText)),
    );
  }
}

/// 받는 주소 대조 상자: 4글자씩 띄우고 앞·끝 4글자를 굵게
class _AddressCheck extends StatelessWidget {
  const _AddressCheck({required this.address, required this.signingDevice, required this.isNewWallet});

  final String address;
  final bool signingDevice;
  final bool isNewWallet;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final groups = [for (var i = 0; i < address.length; i += 4) address.substring(i, (i + 4).clamp(0, address.length))];
    final bold = CoconutTypography.body2_14_NumberBold.setColor(colors.primaryText);
    final normal = CoconutTypography.body2_14_Number.setColor(colors.secondaryTextStrong);
    return Container(
      key: const Key('safety-assist-review-address'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(CoconutStyles.radius_250)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            safetyKoText(isNewWallet ? t.safety_guide.move.receive_address_label : t.premium.replace.destination),
            style: CoconutTypography.body3_12.setColor(colors.secondaryText),
          ),
          CoconutLayout.spacing_200h,
          Text.rich(
            TextSpan(
              children: [
                for (var i = 0; i < groups.length; i++)
                  TextSpan(
                    text: i == groups.length - 1 ? groups[i] : '${groups[i]} ',
                    style: i == 0 || i == groups.length - 1 ? bold : normal,
                  ),
              ],
            ),
            // 줄 수 제한 없음: 서명 기기와 대조할 끝 글자가 큰 글자·좁은 폭에서도 잘리지 않게(H2)
          ),
          CoconutLayout.spacing_300h,
          _InfoLine(
            text: signingDevice ? t.premium.assist.address_check : t.premium.assist.address_check_hot,
            strong: true,
          ),
        ],
      ),
    );
  }
}

/// 받는 지갑의 서명 기기 검증 줄(Grok §5, POLISH H8). 이 기기 핫월렛·직접 입력 주소는 없음
SafetyVerificationLine? _verificationLine(BuildContext context, WalletItemBase? wallet, {Key? key}) =>
    wallet == null || wallet.hasLocalKey
        ? null
        : SafetyVerificationLine(
          key: key,
          verifiedAt: SafetyAssist.verifiedAt(context.read<SafetyProvider?>()?.state, wallet),
        );

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    super.key,
    required this.text,
    this.iconPath = CommonStateIconPath.circleInfo,
    this.iconSize = 14,
    this.strong = false,
  });

  final String text;
  final String iconPath;
  final double iconSize;

  /// 꼭 읽어야 하는 안내(다른 곳에서 서명·대조)는 코코넛에서도 읽히게 `secondaryTextStrong`(POLISH R5)
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: SvgPicture.asset(
            iconPath,
            width: iconSize,
            height: iconSize,
            colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
          ),
        ),
        CoconutLayout.spacing_150w,
        Expanded(
          child: Text(
            safetyKoText(text),
            style: CoconutTypography.body3_12.setColor(strong ? colors.secondaryTextStrong : colors.secondaryText),
          ),
        ),
      ],
    );
  }
}

class _WarningLine extends StatelessWidget {
  const _WarningLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SvgPicture.asset(
            CommonStateIconPath.triangleWarning,
            width: 12,
            height: 12,
            colorFilter: ColorFilter.mode(colors.warningText, BlendMode.srcIn),
          ),
        ),
        CoconutLayout.spacing_100w,
        Expanded(child: Text(safetyKoText(text), style: CoconutTypography.body3_12.setColor(colors.warningText))),
      ],
    );
  }
}
