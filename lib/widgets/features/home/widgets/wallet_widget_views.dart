import 'dart:async';
import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card_background.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

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
  double? _indicatorDragDistance;
  Offset? _indicatorPointerDown;
  Timer? _indicatorRepeat;
  int _indicatorDragDirection = 0;
  bool _indicatorAutoMode = false;
  static const _indicatorPageDistance = 18.0;
  static const _indicatorRepeatInterval = Duration(milliseconds: 500);
  Timer? _hideIndicator;
  Timer? _cardRepeat;
  double? _cardDragDistance;
  int _cardDragDirection = 0;
  static const _cardRepeatInterval = Duration(milliseconds: 450);

  int get _pageCount => widget.wallets.length + (widget.onAddPressed == null ? 0 : 1);

  @override
  void dispose() {
    _hideIndicator?.cancel();
    _cardRepeat?.cancel();
    _indicatorRepeat?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showIndicator() {
    _hideIndicator?.cancel();
    if (!_indicatorVisible) setState(() => _indicatorVisible = true);
  }

  void _scheduleIndicatorHide() {
    _hideIndicator?.cancel();
    if (_indicatorDragDistance != null || _cardDragDistance != null) return;
    _hideIndicator = Timer(_indicatorHideDelay, () {
      if (mounted) setState(() => _indicatorVisible = false);
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _showIndicator();
    } else if (notification is ScrollEndNotification) {
      _scheduleIndicatorHide();
    }
    return false;
  }

  void _startCardDrag(DragStartDetails details) {
    if (!_controller.hasClients || _pageCount < 2) return;
    _cardRepeat?.cancel();
    _cardDragDistance = 0;
    _cardDragDirection = 0;
    _showIndicator();
    _controller.jumpToPage(_page.round().clamp(0, _pageCount - 1));
  }

  void _updateCardDrag(DragUpdateDetails details) {
    if (_cardDragDistance == null) return;
    final direction = Directionality.of(context) == TextDirection.rtl ? 1 : -1;
    final movement = (details.primaryDelta ?? 0) * direction;
    if (movement == 0) return;
    if (movement.sign == _cardDragDirection) {
      _cardDragDistance = 0;
      return;
    }
    _cardDragDistance = _cardDragDistance! + movement;
    if (_cardDragDistance!.abs() < _indicatorPageDistance) return;
    _cardDragDirection = _cardDragDistance!.sign.toInt();
    _cardDragDistance = 0;
    _cardRepeat?.cancel();
    _advanceCard();
    _cardRepeat = Timer.periodic(_cardRepeatInterval, (_) => _advanceCard());
  }

  void _advanceCard() {
    if (!mounted || !_controller.hasClients || _cardDragDistance == null || _pageCount < 2) {
      _cardRepeat?.cancel();
      return;
    }
    final current = _page.round().clamp(0, _pageCount - 1);
    final next = (current + _cardDragDirection).clamp(0, _pageCount - 1);
    if (next == current) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    if (reduceMotion) {
      _controller.jumpToPage(next);
    } else {
      _controller.animateToPage(next, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
    }
    vibrateExtraLight();
  }

  void _endCardDrag() {
    _cardRepeat?.cancel();
    _cardRepeat = null;
    _cardDragDistance = null;
    _cardDragDirection = 0;
    _scheduleIndicatorHide();
  }

  void _startIndicatorDrag(DragStartDetails details) {
    if (!_controller.hasClients) return;
    _indicatorRepeat?.cancel();
    _indicatorDragDistance = 0;
    _indicatorDragDirection = 0;
    _indicatorAutoMode = false;
    _showIndicator();
    _controller.jumpToPage(_page.round().clamp(0, _pageCount - 1));
    // 제스처 인식에 쓰인 첫 이동도 포함해, 한 번 민 뒤 멈춰도 반복을 시작한다.
    if (_pageCount > 5 && _indicatorPointerDown != null) {
      final direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
      _moveIndicator((details.globalPosition.dx - _indicatorPointerDown!.dx) * direction);
    }
  }

  void _updateIndicatorDrag(DragUpdateDetails details) {
    final direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    _moveIndicator((details.primaryDelta ?? 0) * direction);
  }

  bool get _canRepeatIndicator {
    if (!_controller.hasClients || _pageCount <= 5) return false;
    final current = _page.round();
    return current >= 2 && current <= _pageCount - 3;
  }

  void _stopIndicatorRepeat() {
    _indicatorRepeat?.cancel();
    _indicatorRepeat = null;
    _indicatorDragDirection = 0;
  }

  void _repeatIndicator(int direction) {
    _stopIndicatorRepeat();
    if (!_indicatorAutoMode && !_canRepeatIndicator) return;
    // 같은 드래그에서 시작한 자동 전환은 양 끝 두 페이지에 들어가도 유지한다.
    _indicatorAutoMode = true;
    _indicatorDragDirection = direction;
    _indicatorDragDistance = 0;
    if ((direction < 0 && _page <= 0) || (direction > 0 && _page >= _pageCount - 1)) return;
    _indicatorRepeat = Timer.periodic(_indicatorRepeatInterval, (_) {
      if (!mounted || _indicatorDragDistance == null || !_controller.hasClients || _pageCount <= 5) {
        _stopIndicatorRepeat();
        return;
      }
      _stepIndicator(_indicatorDragDirection);
      if ((_indicatorDragDirection < 0 && _page <= 0) || (_indicatorDragDirection > 0 && _page >= _pageCount - 1)) {
        _indicatorDragDistance = 0;
        _stopIndicatorRepeat();
      }
    });
  }

  void _moveIndicator(double movement) {
    if (_indicatorDragDistance == null || !_controller.hasClients || movement == 0) return;
    if (_indicatorAutoMode || _canRepeatIndicator) {
      _indicatorAutoMode = true;
      // 자동 전환 중에는 같은 방향으로 더 끌어도 페이지를 건너뛰지 않는다.
      if (movement.sign == _indicatorDragDirection) {
        _indicatorDragDistance = 0;
        return;
      }
      _indicatorDragDistance = _indicatorDragDistance! + movement;
      if (_indicatorDragDistance!.abs() < _indicatorPageDistance) return;
      final direction = _indicatorDragDistance!.sign.toInt();
      _indicatorDragDistance = 0;
      _stepIndicator(direction);
      _repeatIndicator(direction);
      return;
    }

    // 양 끝 두 페이지는 손가락 이동량만큼만 전환한다.
    _stopIndicatorRepeat();
    _indicatorDragDistance = _indicatorDragDistance! + movement;
    final steps = (_indicatorDragDistance! / _indicatorPageDistance).truncate();
    if (steps != 0) {
      _indicatorDragDistance = _indicatorDragDistance! - steps * _indicatorPageDistance;
      final current = _page.round();
      final target = (current + steps).clamp(0, _pageCount - 1);
      for (var page = current; page != target;) {
        page += steps.sign;
        _stepIndicator(steps.sign);
        if (_canRepeatIndicator) {
          _repeatIndicator(steps.sign);
          break;
        }
      }
    }
    if ((_page <= 0 && _indicatorDragDistance! < 0) || (_page >= _pageCount - 1 && _indicatorDragDistance! > 0)) {
      _indicatorDragDistance = 0;
    }
  }

  void _stepIndicator(int direction) {
    if (!_controller.hasClients || _pageCount < 2) return;
    final current = _page.round().clamp(0, _pageCount - 1);
    final next = (current + direction).clamp(0, _pageCount - 1);
    if (current == next) return;
    _controller.jumpToPage(next);
    vibrateExtraLight();
  }

  void _endIndicatorDrag() {
    _indicatorRepeat?.cancel();
    _indicatorRepeat = null;
    _indicatorPointerDown = null;
    _indicatorDragDistance = null;
    _indicatorDragDirection = 0;
    _indicatorAutoMode = false;
    _scheduleIndicatorHide();
  }

  Widget _indicator(BuildContext context) {
    final colors = context.coconutColors;
    const slotWidth = 14.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final current = _page.round().clamp(0, _pageCount - 1);
        final visibleCount = math.min(_pageCount, 5);
        final first = (current - 2).clamp(0, _pageCount - visibleCount).toDouble();
        final width = visibleCount * slotWidth;
        final reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
        return Semantics(
          value: '${current + 1}/$_pageCount',
          child: SizedBox(
            key: Key('${widget.keyPrefix}-indicator-window'),
            width: width,
            height: 5,
            child: ClipRect(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: first, end: first),
                duration: Duration(milliseconds: reduceMotion ? 0 : 300),
                // 선택 표시가 먼저 바뀐 뒤 양 끝의 점이 사라지고 나타나며 한 칸 이동한다.
                curve: const Interval(0.5, 1, curve: Curves.easeOutCubic),
                builder: (context, position, _) {
                  final start = math.max(0, position.floor() - 1);
                  final end = math.min(_pageCount, position.ceil() + visibleCount + 1);
                  double visibility(int index) =>
                      (math.min((index - position + 0.5) * slotWidth, width - (index - position + 0.5) * slotWidth) /
                              (slotWidth / 2))
                          .clamp(0.0, 1.0);
                  return Stack(
                    children: [
                      for (var i = start; i < end; i++)
                        Positioned(
                          key: ValueKey('${widget.keyPrefix}-indicator-slot-$i'),
                          left: (i - position) * slotWidth,
                          width: slotWidth,
                          top: 0,
                          bottom: 0,
                          child: Opacity(
                            opacity: visibility(i),
                            child: Transform.scale(
                              scale: visibility(i),
                              child: Center(
                                child: AnimatedContainer(
                                  key: ValueKey('${widget.keyPrefix}-indicator-dot-$i'),
                                  duration: Duration(milliseconds: reduceMotion ? 0 : 150),
                                  width: i == current ? 12 : 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: i == current ? colors.pageIndicatorActive : colors.pageIndicatorInactive,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
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
    final actionText = widget.emptyActionText;
    return WalletEmptyCard(
      key: Key('${widget.keyPrefix}-${addPage ? 'add' : 'empty'}'),
      emptyText: widget.emptyText,
      actionText: actionText,
      actionKey: actionText == null ? null : Key('${widget.keyPrefix}-empty-action'),
      onPressed: addPage ? null : widget.onEmptyPressed ?? widget.onPressed,
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
                    child: GestureDetector(
                      key: Key('${widget.keyPrefix}-card-slider'),
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: _startCardDrag,
                      onHorizontalDragUpdate: _updateCardDrag,
                      onHorizontalDragEnd: (_) => _endCardDrag(),
                      onHorizontalDragCancel: _endCardDrag,
                      child: PageView.builder(
                        key: Key('${widget.keyPrefix}-pager'),
                        controller: _controller,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _pageCount,
                        itemBuilder: (context, index) => const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                if (_pageCount > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 32,
                    child: GestureDetector(
                      key: Key('${widget.keyPrefix}-indicator-scrubber'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _showIndicator();
                        _scheduleIndicatorHide();
                      },
                      onHorizontalDragDown: (details) => _indicatorPointerDown = details.globalPosition,
                      onHorizontalDragStart: _startIndicatorDrag,
                      onHorizontalDragUpdate: _updateIndicatorDrag,
                      onHorizontalDragEnd: (_) => _endIndicatorDrag(),
                      onHorizontalDragCancel: _endIndicatorDrag,
                      child: AnimatedOpacity(
                        key: Key('${widget.keyPrefix}-indicator'),
                        opacity: _indicatorVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: FittedBox(fit: BoxFit.scaleDown, child: _indicator(context)),
                          ),
                        ),
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

/// 지갑이 없을 때의 카드. [actionText]가 있으면 [emptyText] 대신 + 아이콘과 추가 문구를 보여 준다.
class WalletEmptyCard extends StatelessWidget {
  final String emptyText;
  final String? actionText;
  final Key? actionKey;
  final VoidCallback? onPressed;

  const WalletEmptyCard({super.key, required this.emptyText, this.actionText, this.actionKey, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final actionText = this.actionText;
    return HomeWidgetCard(
      onPressed: onPressed,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (actionText != null) ...[const WalletAddIcon(), const SizedBox(height: 8)],
            Text(
              actionText ?? emptyText,
              key: actionKey,
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
}

/// 지갑 추가를 나타내는 원 안의 + 아이콘
class WalletAddIcon extends StatelessWidget {
  final double size;

  const WalletAddIcon({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colors.surfaceMuted, shape: BoxShape.circle),
      child: Center(
        child: SvgPicture.asset(
          CommonActionIconPath.plus,
          width: size * 3 / 7,
          height: size * 3 / 7,
          colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
        ),
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

  /// 배경을 지정한 지갑은 배경 색, 아니면 아이콘 색. 잔액 변화의 기간별 요약 막대와 같은 기준이다.
  static const _strokeRatio = 0.2;

  static Color colorOf(BuildContext context, HomeBalanceShare share, {WalletAppearanceProvider? appearances}) {
    final walletId = share.walletId;
    if (walletId == null) return context.coconutColors.surfaceMuted;
    final background = WalletCardBackground.representativeColorOf(appearances?.backgroundOf(walletId));
    if (background != null) return background;
    final colorIndex = share.colorIndex;
    return colorIndex == null ? context.coconutColors.iconSecondary : WalletVisualStyleUtil.getColorByIndex(colorIndex);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final appearances = context.watchWalletAppearance();
    final shareColors = [for (final share in shares) colorOf(context, share, appearances: appearances)];
    final surface = HomeCardSurface.of(context);
    final shareBorders = [for (final color in shareColors) homeChartSegmentBorderOf(context, color, surface)];
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
                  shareColors,
                  colors.surfaceMuted,
                  borders: shareBorders,
                  strokeRatio: _strokeRatio,
                  reveal: reveal,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final numberStyle = CoconutTypography.body1_16_NumberBold.copyWith(
                      color: colors.primaryText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    );
                    final number = measureHomeTextSize(context, total.number, numberStyle);
                    final width = number.width;
                    final height = number.height;
                    final hole = math.max(0.0, constraints.biggest.shortestSide * (1 - 2 * _strokeRatio) - 8);
                    final diagonal = math.sqrt(width * width + height * height);
                    final scale = diagonal <= hole || diagonal == 0 ? 1.0 : hole / diagonal;
                    return Center(
                      child: SizedBox(
                        width: width * scale,
                        height: height * scale,
                        child: FittedBox(
                          child: Text(total.number, key: const Key('balance-by-wallet-total'), style: numberStyle),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final nameStyle = CoconutTypography.body3_12_Bold.copyWith(color: colors.primaryText);
                final percentStyle = CoconutTypography.body3_12_NumberBold.copyWith(
                  color: colors.primaryText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                );
                final amountStyle = CoconutTypography.caption_10_NumberBold.copyWith(
                  color: colors.primaryText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                );
                final entryHeight =
                    [
                      10.0,
                      measureHomeTextSize(context, '0', nameStyle).height,
                      measureHomeTextSize(context, '0', percentStyle).height,
                    ].reduce(math.max) +
                    measureHomeTextSize(context, '0', amountStyle).height;
                final needed = entryHeight * shares.length;
                final scale = needed > constraints.maxHeight ? constraints.maxHeight / needed : 1.0;
                final entries = Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final share in shares)
                      Column(
                        key: ValueKey('balance-by-wallet-entry-${share.walletId ?? 'others'}'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LayoutBuilder(
                            builder:
                                (context, rowConstraints) => Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: shareColors[shares.indexOf(share)],
                                        border: switch (shareBorders[shares.indexOf(share)]) {
                                          final border? => Border.all(color: border, width: 1),
                                          null => null,
                                        },
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        share.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: nameStyle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(maxWidth: math.max(0, rowConstraints.maxWidth - 22)),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          '${sum == 0 ? '0' : (share.balance * 100 / sum).toStringAsFixed(1)}%',
                                          style: percentStyle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
                                style: amountStyle,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                );
                if (scale == 1) return entries;
                return FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: constraints.maxWidth / scale,
                    height: constraints.maxHeight / scale,
                    child: entries,
                  ),
                );
              },
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

  /// 조각마다 두를 얇은 테두리 색. null이면 두르지 않는다.
  final List<Color?> borders;

  /// 0이면 빈 고리, 1이면 다 그린 고리. 위에서부터 시계 방향으로 차오른다.
  final double reveal;

  _DonutPainter(
    this.values,
    this.colors,
    this.emptyColor, {
    this.strokeRatio = 0.14,
    this.reveal = 1,
    this.borders = const [],
  });

  static const _borderWidth = 1.0;

  Color? _borderAt(int index) => index < borders.length ? borders[index] : null;

  void _outline(Canvas canvas, Path path, Color? color) {
    if (color == null) return;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _borderWidth
        ..color = color,
    );
  }

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
      final border = _borderAt(visible.single);
      if (shown >= 1) {
        canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = colors[visible.single]);
        if (border != null) {
          final outline =
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = _borderWidth
                ..color = border;
          canvas.drawCircle(size.center(Offset.zero), radius + stroke / 2, outline);
          canvas.drawCircle(size.center(Offset.zero), radius - stroke / 2, outline);
        }
      } else if (shown > 0) {
        final path = _roundedSector(
          size.center(Offset.zero),
          radius - stroke / 2,
          radius + stroke / 2,
          -math.pi / 2,
          math.pi * 2 * shown,
          stroke * 0.1,
        );
        canvas.drawPath(path, Paint()..color = colors[visible.single]);
        _outline(canvas, path, border);
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
        final path = _roundedSector(
          size.center(Offset.zero),
          radius - stroke / 2,
          radius + stroke / 2,
          from - math.pi / 2,
          until - from,
          stroke * 0.1,
        );
        canvas.drawPath(path, Paint()..color = colors[visible[n]]);
        _outline(canvas, path, _borderAt(visible[n]));
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
      !listEquals(borders, oldDelegate.borders) ||
      emptyColor != oldDelegate.emptyColor ||
      strokeRatio != oldDelegate.strokeRatio ||
      reveal != oldDelegate.reveal;
}
