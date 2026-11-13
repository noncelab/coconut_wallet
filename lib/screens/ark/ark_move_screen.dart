import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/ark/ark_move_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/ark/hot_wallet_unlock.dart';
import 'package:coconut_wallet/screens/send/ark_payment_screen.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/utils/send_amount_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

/// 같은 지갑의 온체인·아크 잔액 사이 옮기기. P2P 계산기처럼 카드 두 장 사이에 방향 바꾸기 버튼
class ArkMoveScreen extends StatefulWidget {
  const ArkMoveScreen({super.key, required this.walletId});

  final int walletId;

  @override
  State<ArkMoveScreen> createState() => _ArkMoveScreenState();
}

class _ArkMoveScreenState extends State<ArkMoveScreen> {
  static const double _cardHeight = 160;

  late final ArkMoveViewModel _viewModel = ArkMoveViewModel(
    context.read<ArkProvider>(),
    context.read<WalletProvider>(),
    context.read<NodeProvider>(),
    context.read<UtxoRepository>(),
    widget.walletId,
  );
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  /// 이 화면에서 쓰는 단위, 단위를 누르면 BTC ↔ sats
  late BitcoinUnit _unit =
      context.read<PreferenceProvider>().currentUnit.isBasedOnSatoshi ? BitcoinUnit.sats : BitcoinUnit.btc;

  void _toggleUnit() {
    final sats = _viewModel.amountSats;
    setState(() => _unit = _unit == BitcoinUnit.btc ? BitcoinUnit.sats : BitcoinUnit.btc);
    if (sats != null) _amountController.text = SendAmountInputFormatter.display(SendAmountText.fromSats(sats, _unit));
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _onAmountChanged(String text) {
    _viewModel.setAmountSats(SendAmountText.toSats(SendAmountInputFormatter.canonical(text), _unit));
  }

  void _fillMax() {
    final sats = _viewModel.fromBalanceSats;
    _amountController.text = SendAmountInputFormatter.display(SendAmountText.fromSats(sats, _unit));
    _viewModel.setAmountSats(sats, isMax: true);
  }

  Future<void> _move() async {
    if (!_viewModel.canMove) return;
    FocusScope.of(context).unfocus();
    final unlocked = await unlockHotWalletForSigning(
      context,
      needsPassphrase: _viewModel.needsPassphrase,
      validatePassphrase: _viewModel.validatePassphrase,
      screenName: AnalyticsScreenNames.arkMovePassphraseSheet,
    );
    if (!mounted || unlocked == null) return;
    final passphrase = unlocked.passphrase;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: '/ark-payment'),
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder:
            (_, __, ___) => ArkPaymentScreen(
              walletId: widget.walletId,
              pay: () async {
                try {
                  await _viewModel.move(passphrase: passphrase);
                  return const ArkPaymentStart(isDone: true);
                } finally {
                  passphrase?.fillRange(0, passphrase.length, 0);
                }
              },
              isSendStart:
                  (route) => route.settings.name != AppRouteNames.arkMove && route.settings.name != '/ark-payment',
            ),
        transitionsBuilder:
            (_, animation, __, child) =>
                FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic), child: child),
      ),
    );
  }

  String? _problemText() => switch (_viewModel.problem) {
    null => null,
    ArkMoveProblem.exceedsBalance => t.ark.move.exceeds_balance,
    ArkMoveProblem.belowMinimum => t.ark.move.below_minimum(
      amount: _unit.displayBitcoinAmount(_viewModel.minimumSats, withUnit: true),
    ),
    ArkMoveProblem.serverDown => t.ark.move.server_down,
    ArkMoveProblem.estimateFailed => t.ark.move.estimate_failed,
  };

  void _swap() {
    _amountController.clear();
    _viewModel.swapDirection();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final colors = context.coconutColors;
        final toArk = _viewModel.direction == ArkMoveDirection.toArk;
        final problem = _problemText();
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: colors.background,
            appBar: CoconutAppBar.build(context: context, title: t.ark.move.title),
            body: SafeArea(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 160),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            Column(
                              children: [
                                _buildFromCard(context, toArk),
                                CoconutLayout.spacing_600h,
                                _buildToCard(context, toArk),
                              ],
                            ),
                            // 두 카드 사이
                            Positioned(top: _cardHeight + 12 - 26, child: _buildSwapButton(context)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  FixedBottomButton(
                    isVisibleAboveKeyboard: false,
                    isActive: _viewModel.canMove,
                    text: t.ark.move.action,
                    subWidget:
                        problem != null
                            ? Text(problem, style: CoconutTypography.body3_12.setColor(colors.dangerText))
                            : _viewModel.feeExceedsAmount
                            ? Text(
                              t.ark.move.fee_exceeds_amount,
                              style: CoconutTypography.body3_12.setColor(colors.warning),
                            )
                            : null,
                    onButtonClicked: _move,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String label,
    required Widget amount,
    required Widget footer,
    Widget? trailing,
  }) {
    final colors = context.coconutColors;
    return Container(
      height: _cardHeight,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: colors.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 28,
            child: Row(
              children: [
                Expanded(child: Text(label, style: CoconutTypography.body2_14_Bold.setColor(colors.secondaryText))),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Expanded(child: Center(child: amount)),
          footer,
        ],
      ),
    );
  }

  /// [reserved]는 비어 있어도 자리를 차지하는 줄(금액 입력란이 움직이지 않게), 기다리는 동안 스켈레톤
  Widget _footerLines(
    BuildContext context,
    List<String> lines, {
    String? reserved,
    bool showReserved = false,
    bool loadingReserved = false,
  }) {
    final colors = context.coconutColors;
    final style = CoconutTypography.body3_12_Number.setColor(colors.secondaryText);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reserved != null)
          Stack(
            children: [
              Visibility(
                visible: showReserved,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Text(reserved, style: style),
              ),
              if (!showReserved && loadingReserved)
                Positioned.fill(
                  child: Align(alignment: Alignment.centerLeft, child: _skeletonBar(context, width: 120)),
                ),
            ],
          ),
        for (final line in lines) Text(line, style: style),
      ],
    );
  }

  Widget _skeletonBar(BuildContext context, {required double width}) {
    final colors = context.coconutColors;
    final bar = Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(color: colors.surfaceSkeletonBase, borderRadius: BorderRadius.circular(4)),
    );
    if (MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context)) return bar;
    return Shimmer.fromColors(
      baseColor: colors.surfaceSkeletonBase,
      highlightColor: colors.surfaceSkeletonHighlight,
      child: bar,
    );
  }

  String _sats(int value) => _unit.displayBitcoinAmount(value, withUnit: true);

  /// 보내는 쪽: 입력 금액, 현재 잔액과 수수료를 더한 총 나가는 금액
  Widget _buildFromCard(BuildContext context, bool toArk) {
    final colors = context.coconutColors;
    final overBalance = _viewModel.problem == ArkMoveProblem.exceedsBalance;
    final activeColor = overBalance ? colors.dangerText : colors.primaryText;
    final style = CoconutTypography.heading2_28_NumberBold.setColor(activeColor);
    return _buildCard(
      context,
      label: toArk ? t.ark.move.from_onchain : t.ark.move.from_ark,
      amount: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('−', style: style.copyWith(color: _viewModel.amountSats == null ? colors.mutedText : activeColor)),
            const SizedBox(width: 4),
            IntrinsicWidth(
              child: CupertinoTextField(
                key: const Key('ark-move-amount'),
                controller: _amountController,
                focusNode: _amountFocusNode,
                padding: EdgeInsets.zero,
                decoration: null,
                textAlign: TextAlign.center,
                style: style,
                cursorColor: activeColor,
                placeholder: '0',
                placeholderStyle: style.copyWith(color: colors.mutedText),
                keyboardType: TextInputType.numberWithOptions(decimal: !_unit.isBasedOnSatoshi),
                inputFormatters: [SendAmountInputFormatter(isSats: _unit.isBasedOnSatoshi)],
                onChanged: _onAmountChanged,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              key: const Key('ark-move-unit'),
              behavior: HitTestBehavior.opaque,
              onTap: _toggleUnit,
              child: Text(
                _unit.symbol,
                style: style.copyWith(color: _viewModel.amountSats == null ? colors.mutedText : activeColor),
              ),
            ),
          ],
        ),
      ),
      trailing: ShrinkAnimationButton(
        key: const Key('ark-move-max'),
        onPressed: _fillMax,
        defaultColor: colors.surfaceButton,
        pressedOverlayColor: colors.surfacePressOverlay,
        borderRadius: 8,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Text(
            t.ark.move.max,
            style: CoconutTypography.body3_12.setColor(colors.surfaceButtonText).copyWith(height: 1),
          ),
        ),
      ),
      footer: _footerLines(
        context,
        [
          t.ark.move.balance(
            amount:
                _viewModel.fromAfterSats == null
                    ? _sats(_viewModel.fromBalanceSats)
                    : '${_unit.displayBitcoinAmount(_viewModel.fromBalanceSats)} → ${_sats(_viewModel.fromAfterSats!)}',
          ),
        ],
        reserved: t.ark.move.estimated_fee(fee: _sats(_viewModel.feeSats ?? 0)),
        showReserved: _viewModel.feeSats != null,
        loadingReserved: _viewModel.isEstimating,
      ),
    );
  }

  /// 받는 쪽: + 받는 금액, 잔액 지금 → 옮긴 뒤
  Widget _buildToCard(BuildContext context, bool toArk) {
    final colors = context.coconutColors;
    final arrival = _viewModel.arrivalSats;
    final current = _viewModel.toBalanceSats;
    final confirmations = _viewModel.boardTerms?.requiredConfirmations;
    return _buildCard(
      context,
      label: toArk ? t.ark.move.to_ark : t.ark.move.to_onchain,
      amount: FittedBox(
        fit: BoxFit.scaleDown,
        child: Builder(
          builder: (context) {
            final style = CoconutTypography.heading2_28_NumberBold.setColor(
              arrival == null ? colors.mutedText : colors.primaryText,
            );
            if (arrival == null) return Text('-', style: style);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text('+', style: style), const SizedBox(width: 4), Text(_sats(arrival), style: style)],
            );
          },
        ),
      ),
      footer: _footerLines(
        context,
        [
          t.ark.move.balance(
            amount:
                arrival == null
                    ? _sats(current)
                    : '${_unit.displayBitcoinAmount(current)} → ${_sats(current + arrival)}',
          ),
        ],
        reserved: toArk ? t.ark.move.board_note(blocks: confirmations ?? 0) : null,
        showReserved: confirmations != null,
        loadingReserved: _viewModel.isLoadingBoardTerms,
      ),
    );
  }

  Widget _buildSwapButton(BuildContext context) {
    final colors = context.coconutColors;
    return ShrinkAnimationButton(
      key: const Key('ark-move-swap'),
      onPressed: _swap,
      defaultColor: colors.surfaceButton,
      pressedOverlayColor: colors.surfacePressOverlay,
      borderRadius: 26,
      childBuilder:
          (context, isPressed) => SizedBox.square(
            dimension: 52,
            child: Center(
              child: SvgPicture.asset(
                CommonNavigationIconPath.arrowTopDown,
                width: 32,
                height: 32,
                colorFilter: ColorFilter.mode(isPressed ? colors.iconPrimary : colors.iconSecondary, BlendMode.srcIn),
              ),
            ),
          ),
    );
  }
}
