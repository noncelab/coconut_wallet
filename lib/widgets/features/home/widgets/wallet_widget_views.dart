import 'dart:async';
import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/cupertino.dart';

/// 스택을 눌러 지갑 목록을 열 때 넘기는 값. 목록의 카드는 [heroTagOf]로 스택 카드와 이어지고,
/// 목록에서 지갑을 넘기면 [showWallet]으로 스택도 그 지갑을 맨 앞에 둔다.
class WalletStackOpenRequest {
  final WalletItemBase front;
  final Object Function(int walletId) heroTagOf;
  final void Function(int walletId) showWallet;

  const WalletStackOpenRequest({required this.front, required this.heroTagOf, required this.showWallet});
}

/// 지갑 카드가 포개진 위젯. 왼쪽으로 넘기면 앞 카드는 작아지며 왼쪽으로 물러나고, 다음 카드는 오른쪽에서 커지며 들어온다.
class WalletStackView extends StatefulWidget {
  static const frontEndScale = 0.85;
  static const frontEndOpacity = 0.5;
  static const backStartScale = 0.6;
  static const backStartOffset = 0.6;

  final String keyPrefix;
  final List<WalletItemBase> wallets;
  final WalletCardSize size;
  final String emptyText;
  final String? Function(WalletItemBase wallet)? balanceTextOf;
  final String? Function(WalletItemBase wallet)? secondaryTextOf;
  final VoidCallback? onPressed;

  /// 있으면 카드를 누를 때 [onPressed] 대신 부른다.
  final void Function(WalletStackOpenRequest request)? onOpen;

  /// 지갑이 없을 때 [emptyText] 대신 보여 주는 추가 문구와 누르면 할 일
  final String? emptyActionText;
  final VoidCallback? onEmptyPressed;

  const WalletStackView({
    super.key,
    required this.keyPrefix,
    required this.wallets,
    required this.size,
    required this.emptyText,
    this.balanceTextOf,
    this.secondaryTextOf,
    this.onPressed,
    this.onOpen,
    this.emptyActionText,
    this.onEmptyPressed,
  });

  @override
  State<WalletStackView> createState() => _WalletStackViewState();
}

class _WalletStackViewState extends State<WalletStackView> {
  static const _indicatorHideDelay = Duration(milliseconds: 800);

  final PageController _controller = PageController();
  bool _indicatorVisible = false;
  Timer? _hideIndicator;

  @override
  void dispose() {
    _hideIndicator?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _hideIndicator?.cancel();
      if (!_indicatorVisible) setState(() => _indicatorVisible = true);
    } else if (notification is ScrollEndNotification) {
      _hideIndicator?.cancel();
      _hideIndicator = Timer(_indicatorHideDelay, () {
        if (mounted) setState(() => _indicatorVisible = false);
      });
    }
    return false;
  }

  Widget _indicator(BuildContext context) {
    final colors = context.coconutColors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final current = _page.round();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.wallets.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: i == current ? 12 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: i == current ? colors.pageIndicatorActive : colors.pageIndicatorInactive,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        );
      },
    );
  }

  double get _page {
    final position = _controller.hasClients ? _controller.position : null;
    if (position == null || !position.hasContentDimensions || !position.hasPixels) return 0;
    return _controller.page ?? 0;
  }

  Object _heroTagOf(int walletId) => ('wallet-stack', identityHashCode(this), walletId);

  void _showWallet(int walletId) {
    final index = widget.wallets.indexWhere((wallet) => wallet.id == walletId);
    if (index >= 0 && _controller.hasClients && _page.round() != index) _controller.jumpToPage(index);
  }

  void _onTap() {
    final onOpen = widget.onOpen;
    if (onOpen == null) {
      widget.onPressed?.call();
      return;
    }
    final index = _page.round().clamp(0, widget.wallets.length - 1);
    onOpen(WalletStackOpenRequest(front: widget.wallets[index], heroTagOf: _heroTagOf, showWallet: _showWallet));
  }

  Widget _card(WalletItemBase wallet) {
    return WalletCard(
      key: ValueKey('${widget.keyPrefix}-card-${wallet.id}'),
      wallet: wallet,
      appearance: WalletAppearance.of(wallet),
      size: widget.size,
      balanceDisplay: widget.balanceTextOf?.call(wallet),
      secondaryText: widget.secondaryTextOf?.call(wallet),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final wallets = widget.wallets;
    if (wallets.isEmpty) {
      final actionText = widget.emptyActionText;
      return HomeWidgetCard(
        key: Key('${widget.keyPrefix}-empty'),
        onPressed: widget.onEmptyPressed ?? widget.onPressed,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (actionText != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: colors.surfaceMuted, shape: BoxShape.circle),
                  child: Icon(CupertinoIcons.add, size: 16, color: colors.primaryText),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                actionText ?? widget.emptyText,
                key: actionText == null ? null : Key('${widget.keyPrefix}-empty-action'),
                textAlign: TextAlign.center,
                style:
                    actionText == null
                        ? CoconutTypography.body3_12.copyWith(color: colors.secondaryText)
                        : CoconutTypography.body3_12_Bold.copyWith(color: colors.primaryText),
              ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onOpen == null && widget.onPressed == null ? null : _onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final page = _page.clamp(0.0, (wallets.length - 1).toDouble());
                      final front = page.floor();
                      final progress = page - front;
                      final back = front + 1;
                      return Stack(
                        children: [
                          if (back < wallets.length)
                            Opacity(
                              key: ValueKey('${widget.keyPrefix}-back'),
                              opacity: progress,
                              child: Transform.translate(
                                offset: Offset(width * WalletStackView.backStartOffset * (1 - progress), 0),
                                child: Transform.scale(
                                  scale:
                                      WalletStackView.backStartScale + (1 - WalletStackView.backStartScale) * progress,
                                  child: _card(wallets[back]),
                                ),
                              ),
                            ),
                          Opacity(
                            key: ValueKey('${widget.keyPrefix}-front'),
                            opacity: 1 - (1 - WalletStackView.frontEndOpacity) * progress,
                            child: Transform.translate(
                              offset: Offset(-width * progress, 0),
                              child: Transform.scale(
                                scale: 1 - (1 - WalletStackView.frontEndScale) * progress,
                                child:
                                    widget.onOpen == null
                                        ? _card(wallets[front])
                                        : Hero(tag: _heroTagOf(wallets[front].id), child: _card(wallets[front])),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: PageView.builder(
                      key: Key('${widget.keyPrefix}-pager'),
                      controller: _controller,
                      itemCount: wallets.length,
                      itemBuilder: (context, index) => const SizedBox.expand(),
                    ),
                  ),
                ),
                if (wallets.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 6,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        key: Key('${widget.keyPrefix}-indicator'),
                        opacity: _indicatorVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Center(child: _indicator(context)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class BalanceByWalletView extends StatelessWidget {
  final List<HomeBalanceShare> shares;
  final HomeAmount total;
  final String Function(int sats) amountText;
  final VoidCallback? onPressed;

  /// 도넛이 차오른 정도(0~1). 호들 인사이트에서 화면을 열 때 차오르게 한다.
  final double reveal;

  const BalanceByWalletView({
    super.key,
    required this.shares,
    required this.total,
    required this.amountText,
    this.onPressed,
    this.reveal = 1,
  });

  static Color colorOf(BuildContext context, HomeBalanceShare share) =>
      share.walletId == null || share.colorIndex == null
          ? context.coconutColors.surfaceMuted
          : WalletVisualStyleUtil.getColorByIndex(share.colorIndex!);

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final sum = shares.fold<int>(0, (total, share) => total + share.balance);
    return HomeWidgetCard(
      onPressed: onPressed,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _DonutPainter(
                  [for (final share in shares) share.balance.toDouble()],
                  [for (final share in shares) colorOf(context, share)],
                  colors.surfaceMuted,
                  strokeRatio: 0.2,
                  reveal: reveal,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        key: const Key('balance-by-wallet-total'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            total.number,
                            style: CoconutTypography.body1_16_NumberBold.copyWith(
                              color: colors.primaryText,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            total.unit,
                            style: CoconutTypography.body1_16_NumberBold.copyWith(color: colors.primaryText),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final share in shares)
                  Column(
                    key: ValueKey('balance-by-wallet-entry-${share.walletId ?? 'others'}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: colorOf(context, share), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              share.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CoconutTypography.body3_12_Bold.copyWith(color: colors.primaryText),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${sum == 0 ? '0' : (share.balance * 100 / sum).toStringAsFixed(1)}%',
                            style: CoconutTypography.body3_12_NumberBold.copyWith(
                              color: colors.primaryText,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 18),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            total.unit.isEmpty
                                ? amountText(share.balance)
                                : total.unitFirst
                                ? '${total.unit} ${amountText(share.balance)}'
                                : '${amountText(share.balance)} ${total.unit}',
                            maxLines: 1,
                            style: CoconutTypography.caption_10_NumberBold.copyWith(
                              color: colors.primaryText,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color emptyColor;
  final double strokeRatio;

  /// 0이면 빈 고리, 1이면 다 그린 고리. 위에서부터 시계 방향으로 차오른다.
  final double reveal;

  _DonutPainter(this.values, this.colors, this.emptyColor, {this.strokeRatio = 0.14, this.reveal = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * strokeRatio;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final radius = rect.width / 2;
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final visible = [
      for (var i = 0; i < values.length; i++)
        if (values[i] > 0) i,
    ];
    final shown = reveal.clamp(0.0, 1.0);
    if (shown < 1) canvas.drawArc(rect, 0, math.pi * 2, false, Paint.from(paint)..color = emptyColor);
    if (total <= 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = emptyColor);
      return;
    }
    if (visible.length == 1) {
      if (shown >= 1) {
        canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = colors[visible.single]);
      } else if (shown > 0) {
        paint.strokeCap = StrokeCap.round;
        canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * shown, false, paint..color = colors[visible.single]);
      }
      return;
    }
    paint.strokeCap = StrokeCap.round;
    final capAngle = (stroke / 2) / radius;
    final gapAngle = (stroke * 0.35) / radius;
    final limit = math.pi * 2 * shown;
    var start = 0.0;
    for (final i in visible) {
      final sweep = math.pi * 2 * values[i] / total;
      final drawn = math.min(
        math.max(0.0001, sweep - capAngle * 2 - gapAngle),
        limit - start - capAngle - gapAngle / 2,
      );
      if (drawn > 0) {
        canvas.drawArc(rect, -math.pi / 2 + start + capAngle + gapAngle / 2, drawn, false, paint..color = colors[i]);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) => true;
}
