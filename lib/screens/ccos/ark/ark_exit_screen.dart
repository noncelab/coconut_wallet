import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_exit.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_fill_source.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_expiry_text.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_move_parts.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_navigation.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/utils/clipboard_copy_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/info/info_section.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_exit_tx_cells.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_glow.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_info_row.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_info_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// 서버 없이 출금(설정 안). 출금 전이면 안내, 시작했으면 진행 단계, 끝났으면 완료
class ArkExitScreen extends StatelessWidget {
  const ArkExitScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletExit),
      builder: (_) => const ArkExitScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<ArkWalletProvider>();
    final session = wallet.exit;
    if (session != null && session.phase == ArkExitPhase.done && session.isSettled) {
      return _ArkExitDoneView(session: session, onDismiss: wallet.dismissExit);
    }
    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(context: context, title: t.ark_wallet.exit_title),
      body: session == null ? const _ArkExitIntro() : _ArkExitProgressView(session: session),
    );
  }
}

/// 노아의 경고 화면처럼 무엇인지와 네 가지 사실, 그리고 언제까지 시작해야 하는지
class _ArkExitIntro extends StatefulWidget {
  const _ArkExitIntro();

  @override
  State<_ArkExitIntro> createState() => _ArkExitIntroState();
}

class _ArkExitIntroState extends State<_ArkExitIntro> {
  ArkExitQuote? _quote;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    context
        .read<ArkWalletProvider>()
        .estimateExit()
        .then((quote) {
          if (mounted) setState(() => _quote = quote);
        })
        .catchError((Object error) {
          Logger.error('ArkExitScreen: estimate failed: $error');
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final wallet = context.watch<ArkWalletProvider>();
    final quote = _quote;
    final firstExpiry = quote?.firstExpiryHeight;
    final blocksToExpiry = firstExpiry == null || wallet.tipHeight == null ? null : firstExpiry - wallet.tipHeight!;
    final problem =
        _failed
            ? t.ark_wallet.problem_fee
            : quote != null && quote.vtxoIds.isEmpty
            ? t.ark_wallet.exit_nothing
            : null;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Text(t.ark_wallet.exit_intro, style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
            CoconutLayout.spacing_500h,
            _ArkExitFact(
              iconPath: CommonStateIconPath.clock,
              title: t.ark_wallet.exit_fact_time,
              line: t.ark_wallet.exit_fact_time_line(time: arkBlocksText(quote?.exitDelta ?? 144)),
            ),
            _ArkExitFact(
              iconPath: FeatureTransactionIconPath.receipt,
              title: t.ark_wallet.exit_fact_fee,
              line: t.ark_wallet.exit_fact_fee_line,
            ),
            _ArkExitFact(
              iconPath: CommonStateIconPath.stopSign,
              title: t.ark_wallet.exit_fact_final,
              line: t.ark_wallet.exit_fact_final_line,
            ),
            _ArkExitFact(
              iconPath: FeatureArkIconPath.boat,
              title: t.ark_wallet.exit_fact_ark,
              line: t.ark_wallet.exit_fact_ark_line,
            ),
            if (blocksToExpiry != null) ...[
              CoconutLayout.spacing_400h,
              Text(
                t.ark_wallet.exit_expiry(time: arkExpiryText(blocksToExpiry)),
                key: const Key('ark-exit-expiry'),
                style: CoconutTypography.body2_14_Bold.setColor(colors.warning),
              ),
            ],
          ],
        ),
        FixedBottomButton(
          buttonKey: const Key('ark-exit-next'),
          text: t.next,
          isActive: quote != null && quote.vtxoIds.isNotEmpty,
          subWidget: problem == null ? null : arkMoveProblemText(context, problem),
          onButtonClicked: () => _ArkExitReviewScreen.open(context, quote!),
        ),
      ],
    );
  }
}

class _ArkExitFact extends StatelessWidget {
  const _ArkExitFact({required this.iconPath, required this.title, required this.line});

  final String iconPath;
  final String title;
  final String line;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: colors.surfaceButton, shape: BoxShape.circle),
            child: Center(
              child: SvgPicture.asset(
                iconPath,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
              ),
            ),
          ),
          CoconutLayout.spacing_300w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
                CoconutLayout.spacing_100h,
                Text(line, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 노아의 VTXO 고르기·시작 요약처럼 받을 금액과 수수료, 받을 지갑과 수수료 낼 지갑
class _ArkExitReviewScreen extends StatefulWidget {
  const _ArkExitReviewScreen({required this.quote});

  final ArkExitQuote quote;

  static Future<void> open(BuildContext context, ArkExitQuote quote) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletExitReview),
      builder: (_) => _ArkExitReviewScreen(quote: quote),
    ),
  );

  @override
  State<_ArkExitReviewScreen> createState() => _ArkExitReviewScreenState();
}

class _ArkExitReviewScreenState extends State<_ArkExitReviewScreen> {
  bool _running = false;
  int? _destinationWalletId;
  int? _feeWalletId;

  @override
  void initState() {
    super.initState();
    final wallets = context.read<WalletProvider>();
    final all = wallets.walletItemList;
    _destinationWalletId = all.isEmpty ? null : all.first.id;
    final feeWallets = _feeWalletIds(wallets)
      ..sort((a, b) => wallets.getWalletBalance(b).confirmed.compareTo(wallets.getWalletBalance(a).confirmed));
    _feeWalletId = feeWallets.isEmpty ? null : feeWallets.first;
  }

  /// 서명할 때 패스프레이즈를 묻지 않는 싱글시그 핫월렛
  List<int> _feeWalletIds(WalletProvider wallets) => [
    for (final id in ArkWalletNavigation.fillWalletIds(wallets))
      if (!(wallets.getWalletById(id).hotWalletMetadata?.enterPassphraseWhenSigning ?? false)) id,
  ];

  Future<void> _pick({required bool destination}) async {
    final wallets = context.read<WalletProvider>();
    final candidates = destination ? [for (final wallet in wallets.walletItemList) wallet.id] : _feeWalletIds(wallets);
    if (candidates.isEmpty) return;
    final id = await pickCoconutWallet(
      context,
      candidates,
      AnalyticsScreenNames.ccosArkWalletExitWallet,
      title: destination ? t.ark_wallet.export_to : t.ark_wallet.exit_fee_from,
    );
    if (id == null || !mounted) return;
    setState(() => destination ? _destinationWalletId = id : _feeWalletId = id);
  }

  String? _problem(WalletProvider wallets) {
    final feeWalletId = _feeWalletId;
    if (feeWalletId == null) return t.ark_wallet.exit_no_fee_wallet;
    if (wallets.getWalletBalance(feeWalletId).confirmed <= widget.quote.fundingSats) {
      return t.alert.error_send.insufficient_balance;
    }
    return null;
  }

  /// 인증 뒤 수수료를 수수료 지갑으로 보내고 출금을 시작
  Future<void> _start() {
    final quote = widget.quote;
    final wallet = context.read<ArkWalletProvider>();
    final wallets = context.read<WalletProvider>();
    final destinationId = _destinationWalletId!;
    final feeWalletId = _feeWalletId!;
    final source = HotWalletFillSource(
      wallets,
      context.read<NodeProvider>(),
      context.read<UtxoRepository>(),
      feeWalletId,
    );
    return runArkMove(
      context,
      authenticate: authenticateArkMove,
      run: () async {
        final receive = wallets.getReceiveAddress(destinationId);
        final feeAddress = await wallet.exitFeeAddress();
        final signed = await source.sign(feeAddress, quote.fundingSats, quote.feeRateSatPerVb.toDouble());
        if (!await source.broadcast(signed)) await wallet.broadcastTx(signed.signedTxHex);
        await source.markSpent(signed);
        await wallet.beginExit(
          ArkExitSession(
            vtxoIds: quote.vtxoIds,
            amountSats: quote.amountSats,
            destination: receive.address,
            destinationPath: receive.derivationPath,
            feeWalletId: feeWalletId,
            fundingSats: quote.fundingSats,
            feeRateSatPerVb: quote.feeRateSatPerVb,
            firstExpiryHeight: quote.firstExpiryHeight,
            startedAt: DateTime.now(),
            claimFeeSats: quote.claimFeeSats,
            txTotal: quote.txCount,
            fundingFeeSats: signed.feeSats,
          ),
        );
      },
      doneMessage: t.ark_wallet.exit_started,
      failedMessage: t.ark_wallet.exit_start_failed,
      returnRoute: AnalyticsScreenNames.ccosArkWalletExit,
      onRunning: (running) {
        if (mounted) setState(() => _running = running);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final wallets = context.watch<WalletProvider>();
    final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
    String sats(int value) => unit.displayBitcoinAmount(value, withUnit: true);
    final quote = widget.quote;
    final destinationId = _destinationWalletId;
    final feeWalletId = _feeWalletId;
    final problem = _problem(wallets);
    final canPickFeeWallet = _feeWalletIds(wallets).length > 1;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, title: t.ark_wallet.exit_title),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              ArkMoveRoute(
                key: const Key('ark-exit-route'),
                fromName: t.ark_wallet.wallet_name,
                fromBalance: sats(context.select<ArkWalletProvider, int>((wallet) => wallet.balance.spendable)),
                amount: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '- ${sats(quote.amountSats)}',
                      style: CoconutTypography.heading4_18_NumberBold.setColor(colors.primaryText),
                    ),
                    CoconutLayout.spacing_100h,
                    Text(
                      'VTXO ${t.ark_wallet.vtxo_count(n: quote.vtxoIds.length)}',
                      style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                    ),
                    if (quote.leftOutSats > 0) ...[
                      CoconutLayout.spacing_100h,
                      Text(
                        t.ark_wallet.exit_left_out(amount: sats(quote.leftOutSats)),
                        key: const Key('ark-exit-left-out'),
                        style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                      ),
                    ],
                  ],
                ),
                fees: [
                  '${t.ark_wallet.fee_network} ${sats(quote.broadcastFeeSats)} · ${arkFeeRateText(quote.feeRateSatPerVb)}',
                ],
                feeExtra: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${t.ark_wallet.exit_claim_fee} ${sats(quote.claimFeeSats)}',
                            style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                          ),
                        ),
                        ArkInfoTooltip(
                          message: t.ark_wallet.exit_claim_fee_tooltip,
                          iconKey: const Key('ark-exit-claim-tooltip'),
                          iconSize: 14,
                        ),
                      ],
                    ),
                    GestureDetector(
                      key: const Key('ark-exit-fee-wallet'),
                      behavior: HitTestBehavior.opaque,
                      onTap: canPickFeeWallet ? () => _pick(destination: false) : null,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              feeWalletId == null
                                  ? '${t.ark_wallet.exit_fee_from} ${t.ark_wallet.exit_choose}'
                                  : '${t.ark_wallet.exit_fee_from_wallet(wallet: wallets.getWalletById(feeWalletId).name)} · ${t.ark_wallet.wallet_balance(amount: sats(wallets.getWalletBalance(feeWalletId).confirmed))}',
                              style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                            ),
                          ),
                          ArkInfoTooltip(message: t.ark_wallet.exit_funding_detail, iconSize: 14),
                          if (canPickFeeWallet) const InfoRowArrow(),
                        ],
                      ),
                    ),
                  ],
                ),
                toName: destinationId == null ? t.ark_wallet.exit_choose : wallets.getWalletById(destinationId).name,
                toBalance: destinationId == null ? '-' : sats(wallets.getWalletBalance(destinationId).total),
                onToTap: wallets.walletItemList.length > 1 ? () => _pick(destination: true) : null,
                arrival: sats(quote.receiveSats),
                arrivalDetail: t.ark_wallet.exit_step_wait_detail(time: arkBlocksLaterText(quote.waitBlocks)),
              ),
            ],
          ),
          FixedBottomButton(
            buttonKey: const Key('ark-exit-start'),
            text: t.ark_wallet.exit_start,
            isActive: problem == null && destinationId != null && !_running,
            subWidget: problem == null ? null : arkMoveProblemText(context, problem),
            onButtonClicked: _start,
          ),
        ],
      ),
    );
  }
}

/// 진행 중. 노아처럼 지금 어느 단계인지와 언제 받을 수 있는지
class _ArkExitProgressView extends StatelessWidget {
  const _ArkExitProgressView({required this.session});

  final ArkExitSession session;

  /// 수수료를 가져온 지갑과 금액. 지갑을 기록하기 전에 시작한 출금이나 지운 지갑이면 금액만
  String _fundLine(BuildContext context, BitcoinUnit unit) {
    final amount = unit.displayBitcoinAmount(session.fundingSats, withUnit: true);
    final wallets = context.read<WalletProvider>();
    final walletId = session.feeWalletId;
    if (walletId == null || !wallets.walletItemList.any((wallet) => wallet.id == walletId)) return amount;
    return t.ark_wallet.exit_step_fund_detail(wallet: wallets.getWalletById(walletId).name, amount: amount);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final wallet = context.watch<ArkWalletProvider>();
    final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
    final failed = session.phase == ArkExitPhase.failed;
    final tip = wallet.tipHeight;
    final claimable = session.claimableHeight;
    final current = switch (session.phase) {
      ArkExitPhase.funding => 0,
      ArkExitPhase.exiting => 1,
      ArkExitPhase.waiting => 2,
      ArkExitPhase.claiming => 3,
      ArkExitPhase.done || ArkExitPhase.failed => 4,
    };
    final waitDetail =
        claimable == null || tip == null
            ? null
            : t.ark_wallet.exit_step_wait_detail(
              time: claimable - tip > 0 ? arkBlocksLaterText(claimable - tip) : arkExpiryText(claimable - tip),
            );
    final secondary = CoconutTypography.body3_12.setColor(colors.secondaryText);
    final steps = <(String, Widget?, String?)>[
      (t.ark_wallet.exit_step_fund, Text(_fundLine(context, unit), style: secondary), null),
      (
        t.ark_wallet.exit_step_send,
        session.txTotal == 0
            ? null
            : ArkExitTxCells(
              done: session.txDone,
              total: session.txTotal,
              maxWidth: MediaQuery.sizeOf(context).width - 32 - 20 - 12,
            ),
        t.ark_wallet.exit_step_send_tooltip,
      ),
      (
        t.ark_wallet.exit_step_wait,
        waitDetail == null ? null : Text(waitDetail, style: secondary),
        t.ark_wallet.exit_step_wait_tooltip,
      ),
      (t.ark_wallet.exit_step_claim, null, null),
    ];
    final lastStep = steps.length - 1;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Text(t.ark_wallet.exit_receive, style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
            CoconutLayout.spacing_100h,
            BitcoinAmountUnit(
              currentUnit: unit,
              unitStyle: CoconutTypography.heading4_18_Number.setColor(colors.primaryText),
              spacing: CoconutLayout.spacing_100w,
              child: Text(
                unit.displayBitcoinAmount(session.receiveSats),
                style: CoconutTypography.heading2_28_NumberBold.setColor(colors.primaryText),
              ),
            ),
            CoconutLayout.spacing_500h,
            if (failed)
              Text(
                session.failure == ArkExitFailure.spent
                    ? t.ark_wallet.exit_phase_spent
                    : t.ark_wallet.exit_phase_expired,
                key: const Key('ark-exit-failed'),
                style: CoconutTypography.body2_14_Bold.setColor(colors.danger),
              )
            else
              for (final (index, (title, detail, tooltip)) in steps.indexed)
                _ArkExitStep(
                  key: ValueKey('ark-exit-step-$index'),
                  title: title,
                  tooltip: tooltip,
                  tooltipKey: Key(index == 1 ? 'ark-exit-send-tooltip' : 'ark-exit-wait-tooltip'),
                  detail:
                      index == lastStep
                          ? _ArkExitAddress(session: session)
                          : index == 0 || index == current
                          ? detail
                          : null,
                  state:
                      index < current
                          ? _StepState.done
                          : index == current
                          ? _StepState.current
                          : _StepState.next,
                  isLast: index == steps.length - 1,
                ),
          ],
        ),
        if (session.isSettled)
          FixedBottomButton(
            buttonKey: const Key('ark-exit-dismiss'),
            text: t.confirm,
            onButtonClicked: wallet.dismissExit,
          ),
      ],
    );
  }
}

enum _StepState { done, current, next }

class _ArkExitStep extends StatelessWidget {
  const _ArkExitStep({
    super.key,
    required this.title,
    required this.detail,
    required this.state,
    required this.isLast,
    this.tooltip,
    this.tooltipKey,
  });

  final String title;
  final Widget? detail;

  /// 있으면 제목 옆 인포 말풍선
  final String? tooltip;
  final Key? tooltipKey;
  final _StepState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final active = state != _StepState.next;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              SizedBox.square(
                dimension: 20,
                child: switch (state) {
                  _StepState.done => SvgPicture.asset(
                    CommonFormIconPath.circleCheck,
                    colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
                  ),
                  _StepState.current => Center(
                    child: ArkGlow(
                      key: const Key('ark-exit-step-glow'),
                      builder:
                          (context, strength) => Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.primaryText,
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primaryText.withValues(alpha: 0.2 + 0.5 * strength),
                                  blurRadius: 4 + 8 * strength,
                                  spreadRadius: 1 + 2 * strength,
                                ),
                              ],
                            ),
                          ),
                    ),
                  ),
                  _StepState.next => SvgPicture.asset(
                    CommonFormIconPath.circle,
                    colorFilter: ColorFilter.mode(colors.tertiaryText, BlendMode.srcIn),
                  ),
                },
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 4), color: colors.divider),
                ),
            ],
          ),
          CoconutLayout.spacing_300w,
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: (state == _StepState.current
                                ? CoconutTypography.body2_14_Bold
                                : CoconutTypography.body2_14)
                            .setColor(active ? colors.primaryText : colors.tertiaryText),
                      ),
                      if (tooltip != null) ArkInfoTooltip(message: tooltip!, iconKey: tooltipKey),
                    ],
                  ),
                  if (detail != null) ...[CoconutLayout.spacing_200h, detail!],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 온체인 보내기 완료 화면과 같은 모양: 위 30%에 완료 체크와 제목, 받은 금액과 줄들, 아래 확인
class _ArkExitDoneView extends StatelessWidget {
  const _ArkExitDoneView({required this.session, required this.onDismiss});

  final ArkExitSession session;
  final Future<void> Function() onDismiss;

  String _took() {
    final finished = session.finishedAt;
    if (finished == null) return '-';
    final minutes = finished.difference(session.startedAt).inMinutes;
    if (minutes < 60) return t.ark_wallet.duration_minutes(n: minutes < 1 ? 1 : minutes);
    if (minutes < 60 * 24) return t.ark_wallet.duration_hours(n: minutes ~/ 60);
    final days = minutes ~/ (60 * 24);
    return days == 1 ? t.ark_wallet.duration_one_day : t.ark_wallet.duration_days(n: days);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
    String sats(int value) => unit.displayBitcoinAmount(value, withUnit: true);
    final received = session.receivedSats ?? session.receiveSats;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 40),
                Center(child: SvgPicture.asset(CommonStateIconPath.completionCheck)),
                CoconutLayout.spacing_400h,
                Center(
                  child: Text(
                    t.ark_wallet.exit_phase_done,
                    style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText),
                  ),
                ),
                CoconutLayout.spacing_400h,
                Center(
                  child: BitcoinAmountUnit(
                    currentUnit: unit,
                    unitStyle: CoconutTypography.heading4_18_Number.setColor(colors.primaryText),
                    spacing: CoconutLayout.spacing_100w,
                    child: Text(
                      unit.displayBitcoinAmount(received),
                      key: const Key('ark-exit-received'),
                      style: CoconutTypography.heading2_28_NumberBold.setColor(colors.primaryText),
                    ),
                  ),
                ),
                CoconutLayout.spacing_500h,
                ArkInfoBox(
                  key: const Key('ark-exit-done-box'),
                  children: [
                    ArkInfoRow(label: t.ark_wallet.exit_amount_done, value: sats(session.amountSats), isNumber: true),
                    ArkInfoRow(
                      label: t.ark_wallet.exit_claim_fee,
                      value: sats(session.amountSats - received),
                      isNumber: true,
                    ),
                    ArkInfoRow(label: t.ark_wallet.exit_took, value: _took()),
                    ArkCopyRow(
                      key: const Key('ark-exit-done-address'),
                      label: t.ark_wallet.from,
                      value: session.destination,
                      detail: session.destinationPath,
                    ),
                  ],
                ),
              ],
            ),
            FixedBottomButton(
              buttonKey: const Key('ark-exit-dismiss'),
              showSurroundings: false,
              text: t.confirm,
              onButtonClicked: () async {
                final navigator = Navigator.of(context);
                await onDismiss();
                navigator.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 진행 화면의 받기 단계 아래 받을 주소와 파생 경로, 다른 단계 보조 글자와 같은 모양. 누르면 주소만 복사
class _ArkExitAddress extends StatelessWidget {
  const _ArkExitAddress({required this.session});

  final ArkExitSession session;

  @override
  Widget build(BuildContext context) {
    final style = CoconutTypography.body3_12_Number.setColor(context.coconutColors.secondaryText);
    return GestureDetector(
      key: const Key('ark-exit-progress-address'),
      behavior: HitTestBehavior.opaque,
      onTap: () => ClipboardCopyUtil.copyWithToast(context, text: session.destination),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(session.destination, style: style),
          if (session.destinationPath != null) Text(session.destinationPath!, style: style),
        ],
      ),
    );
  }
}
