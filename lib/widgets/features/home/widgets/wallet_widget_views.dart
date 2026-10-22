import 'dart:async';
import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show listEquals;

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

  /// 있으면 실제 지갑 뒤에 추가 페이지를 보여 준다.
  final VoidCallback? onAddPressed;

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
    this.onAddPressed,
  });

  @override
  State<WalletStackView> createState() => _WalletStackViewState();
}

class _WalletStackViewState extends State<WalletStackView> {
  static const _indicatorHideDelay = Duration(milliseconds: 800);

  final PageController _controller = PageController();
  bool _indicatorVisible = false;
  Timer? _hideIndicator;

  int get _pageCount => widget.wallets.length + (widget.onAddPressed == null ? 0 : 1);

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
            for (var i = 0; i < _pageCount; i++)
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
    if (widget.onAddPressed != null && _page.round() >= widget.wallets.length) {
      widget.onAddPressed!();
      return;
    }
    final onOpen = widget.onOpen;
    if (onOpen == null) {
      widget.onPressed?.call();
      return;
    }
    final index = _page.round().clamp(0, widget.wallets.length - 1);
    onOpen(WalletStackOpenRequest(front: widget.wallets[index], heroTagOf: _heroTagOf, showWallet: _showWallet));
  }

  Widget _card(WalletItemBase wallet) {
    final appearances = context.watchWalletAppearance();
    return WalletCard(
      key: ValueKey('${widget.keyPrefix}-card-${wallet.id}'),
      wallet: wallet,
      appearance: appearances?.appearanceOf(wallet) ?? WalletAppearance.of(wallet),
      backgroundPhoto: appearances?.photoFileFor(wallet.id),
      size: widget.size,
      balanceDisplay: widget.balanceTextOf?.call(wallet),
      secondaryText: widget.secondaryTextOf?.call(wallet),
    );
  }

  Widget _emptyCard(BuildContext context, {bool addPage = false}) {
    final colors = context.coconutColors;
    final actionText = widget.emptyActionText;
    return HomeWidgetCard(
      key: Key('${widget.keyPrefix}-${addPage ? 'add' : 'empty'}'),
      onPressed: addPage ? null : widget.onEmptyPressed ?? widget.onPressed,
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

  Widget _pageCard(BuildContext context, int index, {bool hero = false}) {
    if (index == widget.wallets.length) return _emptyCard(context, addPage: true);
    final wallet = widget.wallets[index];
    final card = _card(wallet);
    return hero && widget.onOpen != null ? Hero(tag: _heroTagOf(wallet.id), child: card) : card;
  }

  @override
  Widget build(BuildContext context) {
    final wallets = widget.wallets;
    if (wallets.isEmpty) return _emptyCard(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onOpen == null && widget.onPressed == null && widget.onAddPressed == null ? null : _onTap,
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
                      final page = _page.clamp(0.0, (_pageCount - 1).toDouble());
                      final front = page.floor();
                      final progress = page - front;
                      final back = front + 1;
                      return Stack(
                        children: [
                          if (back < _pageCount)
                            Opacity(
                              key: ValueKey('${widget.keyPrefix}-back'),
                              opacity: progress,
                              child: Transform.translate(
                                offset: Offset(width * WalletStackView.backStartOffset * (1 - progress), 0),
                                child: Transform.scale(
                                  scale:
                                      WalletStackView.backStartScale + (1 - WalletStackView.backStartScale) * progress,
                                  child: _pageCard(context, back),
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
                                child: _pageCard(context, front, hero: true),
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
                      itemCount: _pageCount,
                      itemBuilder: (context, index) => const SizedBox.expand(),
                    ),
                  ),
                ),
                if (_pageCount > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 6,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        key: Key('${widget.keyPrefix}-indicator'),
                        opacity: _indicatorVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: _indicator(context))),
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
    const strokeRatio = 0.2;
    // The center square's diagonal must fit inside the donut hole.
    final centerFraction = (1 - 2 * strokeRatio) / math.sqrt2;
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
                  strokeRatio: strokeRatio,
                  reveal: reveal,
                ),
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: centerFraction,
                    heightFactor: centerFraction,
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
        canvas.drawPath(
          _roundedSector(
            size.center(Offset.zero),
            radius - stroke / 2,
            radius + stroke / 2,
            -math.pi / 2,
            math.pi * 2 * shown,
            stroke * 0.1,
          ),
          Paint()..color = colors[visible.single],
        );
      }
      return;
    }
    final gap = size.shortestSide * 0.014 / radius;
    final sweeps = [for (final i in visible) math.pi * 2 * values[i] / total];
    final limit = math.pi * 2 * shown;
    var start = 0.0;
    for (var n = 0; n < visible.length; n++) {
      final sweep = sweeps[n];
      final before = math.min(gap, math.min(sweep, sweeps[(n + sweeps.length - 1) % sweeps.length]) * 0.08) / 2;
      final after = math.min(gap, math.min(sweep, sweeps[(n + 1) % sweeps.length]) * 0.08) / 2;
      final from = start + before;
      final until = math.min(start + sweep - after, limit);
      if (until > from) {
        canvas.drawPath(
          _roundedSector(
            size.center(Offset.zero),
            radius - stroke / 2,
            radius + stroke / 2,
            from - math.pi / 2,
            until - from,
            stroke * 0.1,
          ),
          Paint()..color = colors[visible[n]],
        );
      }
      start += sweep;
    }
  }

  /// Fillet circles tangent to both the radial edge and the concentric arc.
  /// Limit their radius so neighboring corners stay inside the true slice angle.
  Path _roundedSector(Offset center, double inner, double outer, double start, double sweep, double corner) {
    final halfSine = math.sin(math.min(sweep, math.pi) / 2);
    final radius =
        math.min(corner, math.min(outer * halfSine / (1 + halfSine), inner * halfSine / (1 - halfSine))) * (1 - 1e-9);
    final outerInset = math.asin((radius / (outer - radius)).clamp(0.0, 1.0));
    final innerInset = math.asin((radius / (inner + radius)).clamp(0.0, 1.0));
    final outerTangent = math.sqrt(outer * (outer - 2 * radius));
    final innerTangent = math.sqrt(inner * (inner + 2 * radius));
    Offset point(double angle, double r) => center + Offset(math.cos(angle), math.sin(angle)) * r;
    final end = start + sweep;
    final p = point(start, outerTangent);
    return Path()
      ..moveTo(p.dx, p.dy)
      ..arcToPoint(point(start + outerInset, outer), radius: Radius.circular(radius))
      ..arcTo(Rect.fromCircle(center: center, radius: outer), start + outerInset, sweep - 2 * outerInset, false)
      ..arcToPoint(point(end, outerTangent), radius: Radius.circular(radius))
      ..lineTo(point(end, innerTangent).dx, point(end, innerTangent).dy)
      ..arcToPoint(point(end - innerInset, inner), radius: Radius.circular(radius))
      ..arcTo(Rect.fromCircle(center: center, radius: inner), end - innerInset, -sweep + 2 * innerInset, false)
      ..arcToPoint(point(start, innerTangent), radius: Radius.circular(radius))
      ..close();
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      !listEquals(values, oldDelegate.values) ||
      !listEquals(colors, oldDelegate.colors) ||
      emptyColor != oldDelegate.emptyColor ||
      strokeRatio != oldDelegate.strokeRatio ||
      reveal != oldDelegate.reveal;
}
