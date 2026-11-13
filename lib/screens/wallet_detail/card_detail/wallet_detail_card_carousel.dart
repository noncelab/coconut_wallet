import 'dart:ui' show lerpDouble;
import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/widgets/features/transaction/icon/pending_transaction_lottie_icon.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/widgets/common/amount/animated_balance.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/side_safe_area.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:coconut_wallet/widgets/common/buttons/custom_underlined_button.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 지갑 상세 위쪽의 가로 카드 휠. 가운데 카드 양옆으로 이웃 카드의 기울어진 가장자리가 보인다.
class WalletDetailCardCarousel extends StatefulWidget {
  final List<WalletItemBase> wallets;
  final int initialIndex;
  final ValueChanged<WalletItemBase> onFocusChanged;

  /// 넘기는 중인 페이지 위치(예: 1.3은 두 번째와 세 번째 카드 사이).
  final ValueChanged<double>? onPageScrolled;
  final ValueChanged<bool>? onScrollActivityChanged;
  final Widget Function(BuildContext context, WalletItemBase wallet, ValueChanged<double> onHeightChanged)?
  footerBuilder;
  final Widget Function(
    BuildContext context,
    WalletItemBase wallet,
    bool isFocused,
    Widget Function(Widget) surfaceBuilder,
  )
  cardBuilder;

  const WalletDetailCardCarousel({
    super.key,
    required this.wallets,
    required this.initialIndex,
    required this.onFocusChanged,
    required this.cardBuilder,
    this.onPageScrolled,
    this.onScrollActivityChanged,
    this.footerBuilder,
  });

  /// 카드 폭은 화면 폭의 [widthFraction], 높이는 폭의 [aspect] 배 또는 확대된 내용의 높이.
  static const double widthFraction = 0.86;
  static const double aspect = 0.66;

  static double heightFor(BuildContext context) {
    ({double height, double baseline}) line(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final metrics = (
        height: painter.height,
        baseline: painter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
      );
      painter.dispose();
      return metrics;
    }

    final header = line('지갑', CoconutTypography.body2_14_Bold);
    final amount = line('0', CoconutTypography.heading2_28_NumberBold);
    final unit = line(
      BitcoinUnit.values.map((unit) => unit.symbol).join(' '),
      CoconutTypography.heading4_18_NumberBold,
    );
    final small = line('₩ 0', CoconutTypography.body3_12);
    final amountHeight =
        math.max(amount.baseline, unit.baseline) +
        math.max(amount.height - amount.baseline, unit.height - unit.baseline);
    // Include the button's 1px border on both sides, as well as the existing card padding and gaps.
    final contentHeight =
        32 +
        math.max(36, header.height) +
        amountHeight +
        2 +
        small.height +
        10 +
        _ActionButton.size +
        2 +
        4 +
        small.height;
    return math.max(
      math.max(210, MediaQuery.sizeOf(context).width * widthFraction * aspect),
      contentHeight.ceilToDouble(),
    );
  }

  @override
  State<WalletDetailCardCarousel> createState() => _WalletDetailCardCarouselState();
}

class _WalletDetailCardCarouselState extends State<WalletDetailCardCarousel> {
  static const double _tilt = 0.09;
  static const double _neighborScale = 0.9;
  static const double _gap = 16;

  PageController? _controller;
  late int _focused = widget.initialIndex;
  double _footerHeight = 0;
  bool _userScrolling = false;

  BorderRadius _containerRadius(int index) {
    final footer = index == _focused ? (_footerHeight / 40).clamp(0.0, 1.0) : 0.0;
    return BorderRadius.vertical(top: const Radius.circular(28), bottom: Radius.circular(lerpDouble(28, 16, footer)!));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final fraction = WalletDetailCardCarousel.widthFraction + _gap / screenWidth;
    final previous = _controller;
    if (previous != null && previous.viewportFraction == fraction) return;
    _controller = PageController(initialPage: _focused, viewportFraction: fraction)..addListener(_reportPage);
    previous?.dispose();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _reportPage() => widget.onPageScrolled?.call(_page);

  /// 레이아웃 도중의 알림은 프레임이 끝난 뒤 전달
  void _reportScrollActivity(bool moving) {
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      widget.onScrollActivityChanged?.call(moving);
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && _userScrolling == moving) widget.onScrollActivityChanged?.call(moving);
    });
  }

  double get _page {
    final controller = _controller!;
    return controller.hasClients && controller.position.haveDimensions
        ? controller.page ?? _focused.toDouble()
        : _focused.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.sizeOf(context).width * WalletDetailCardCarousel.widthFraction;
    final cardHeight = WalletDetailCardCarousel.heightFor(context);
    final carousel = SizedBox(
      height: cardHeight + 16 + _footerHeight,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth != 0 || notification.metrics.axis != Axis.horizontal) return false;
          // 레이아웃 중 페이지 맞춤 같은 자동 스크롤은 넘김으로 보지 않음
          if (notification is ScrollStartNotification && notification.dragDetails != null && !_userScrolling) {
            _userScrolling = true;
            _reportScrollActivity(true);
          }
          if (notification is ScrollEndNotification && _userScrolling) {
            _userScrolling = false;
            _reportScrollActivity(false);
          }
          return false;
        },
        child: PageView.builder(
          key: const Key('wallet-detail-carousel'),
          controller: _controller,
          clipBehavior: Clip.none,
          itemCount: widget.wallets.length,
          onPageChanged: (index) {
            _focused = index;
            widget.onFocusChanged(widget.wallets[index]);
          },
          itemBuilder:
              (context, index) => AnimatedBuilder(
                animation: _controller!,
                builder: (context, child) {
                  final distance = (_page - index).clamp(-1.5, 1.5);
                  final shrink = 1 - (1 - _neighborScale) * math.min(distance.abs(), 1.0);
                  return Transform.translate(
                    offset: Offset(distance * cardWidth * (1 - shrink) / 2, 0),
                    child: Transform.rotate(
                      angle: -distance * _tilt,
                      child: Transform.scale(scale: shrink, child: child),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _gap / 2, vertical: 8),
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: widget.cardBuilder(
                      context,
                      widget.wallets[index],
                      index == _focused,
                      (face) => DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: _containerRadius(index),
                          boxShadow: WalletCard.elevationOf(context),
                        ),
                        child: ClipRRect(
                          key: ValueKey('wallet-detail-card-container-${widget.wallets[index].id}'),
                          borderRadius: _containerRadius(index),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: cardHeight, child: face),
                              if (widget.footerBuilder != null && index == _focused)
                                widget.footerBuilder!(context, widget.wallets[index], (height) {
                                  if (mounted && index == _focused && _footerHeight != height) {
                                    setState(() => _footerHeight = height);
                                  }
                                }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
    // 루트가 적용한 옆 여백을 구독해 창 크기가 같아도 좌우가 바뀌면 클립을 갱신한다.
    // 이웃 카드가 상태 열에 복제되지 않도록
    // 카드 옆 여백의 절반(최대 32pt)을 배경으로 남기되 카드 크기와 페이지 위치는 바꾸지 않는다.
    final sides = SideSafeArea.insetsOf(context);
    final guard = math.min(32.0, (MediaQuery.sizeOf(context).width - cardWidth) / 4);
    final hasSideInset = sides.left > 0 || sides.right > 0;
    // 항상 같은 트리를 유지한다. 옆 여백이 없으면 클립 레이어나 추가 페인트를 만들지 않는다.
    return ClipRect(
      clipBehavior: hasSideInset ? Clip.hardEdge : Clip.none,
      clipper:
          hasSideInset
              ? _CarouselSideClipper(
                left: sides.left > 0 ? guard : 0,
                right: sides.right > 0 ? guard : 0,
                windowHeight: MediaQuery.sizeOf(context).height,
              )
              : null,
      child: carousel,
    );
  }
}

class _CarouselSideClipper extends CustomClipper<Rect> {
  final double left;
  final double right;
  final double windowHeight;

  const _CarouselSideClipper({required this.left, required this.right, required this.windowHeight});

  @override
  Rect getClip(Size size) => Rect.fromLTRB(left, -windowHeight, size.width - right, size.height + windowHeight);

  @override
  bool shouldReclip(_CarouselSideClipper oldClipper) =>
      left != oldClipper.left || right != oldClipper.right || windowHeight != oldClipper.windowHeight;
}

/// 지갑 상세 카드. 이름·아이콘, 잔액·법정화폐 금액, 동작 버튼을 담는다.
class WalletDetailCard extends StatelessWidget {
  static const int _actionSlots = 4;
  static const double _actionGap = 6;

  final WalletItemBase wallet;
  final WalletAppearance appearance;
  final int balance;

  /// 온체인·아크로 나눠 보여 줄 때만 값이 있음
  final ({int onchain, int ark})? breakdown;

  final ({bool receiving, bool sending}) onchainPending;
  final ({bool receiving, bool sending}) arkPending;
  final BitcoinUnit unit;
  final VoidCallback? onBalanceTap;

  /// 아크가 잠겨 있을 때만 값이 있음
  final VoidCallback? onUnlockArk;
  final List<WalletDetailCardAction> actions;
  final BorderRadius borderRadius;

  const WalletDetailCard({
    super.key,
    required this.wallet,
    required this.appearance,
    required this.balance,
    this.breakdown,
    this.onchainPending = (receiving: false, sending: false),
    this.arkPending = (receiving: false, sending: false),
    required this.unit,
    required this.actions,
    this.onBalanceTap,
    this.onUnlockArk,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
  });

  List<Widget> _pendingIcons(({bool receiving, bool sending}) pending, String source) => [
    for (final (isIncoming, isPending) in [(true, pending.receiving), (false, pending.sending)])
      if (isPending) ...[
        const SizedBox(width: 4),
        PendingTransactionLottieIcon(
          key: Key('wallet-detail-card-pending-$source-${isIncoming ? 'receiving' : 'sending'}'),
          isIncoming: isIncoming,
          size: 12,
          backgroundAlpha: 0,
        ),
      ],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.homeSurface,
        borderRadius: borderRadius,
        boxShadow: WalletCard.elevationOf(context),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                WalletCard.iconOf(wallet, appearance),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    wallet.name,
                    key: const Key('wallet-detail-card-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoconutTypography.body2_14_Bold.copyWith(
                      color: colors.secondaryText,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(padding: const EdgeInsets.only(right: 12), child: WalletCard.typeLabelOf(wallet)),
              ],
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBalanceTap,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: BitcoinAmountUnit(
                            currentUnit: unit,
                            unitStyle: CoconutTypography.heading4_18_NumberBold.copyWith(color: colors.primaryText),
                            child: AnimatedBalance(
                              key: const Key('wallet-detail-card-balance'),
                              prevValue: balance,
                              value: balance,
                              duration: 400,
                              currentUnit: unit,
                              textStyle: CoconutTypography.heading2_28_NumberBold.copyWith(color: colors.primaryText),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FiatPrice(
                              satoshiAmount: balance,
                              textStyle: CoconutTypography.body3_12.copyWith(color: colors.secondaryText),
                            ),
                            if (breakdown == null)
                              ..._pendingIcons((
                                receiving: onchainPending.receiving || arkPending.receiving,
                                sending: onchainPending.sending || arkPending.sending,
                              ), 'total'),
                          ],
                        ),
                        if (breakdown case final parts?) ...[
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              key: const Key('wallet-detail-card-balance-breakdown'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${t.ark.balance.onchain} ${unit.displayBitcoinAmount(parts.onchain)}',
                                  style: CoconutTypography.body3_12_Number.copyWith(color: colors.secondaryText),
                                ),
                                ..._pendingIcons(onchainPending, 'onchain'),
                                Text(
                                  '  ·  ${t.ark.balance.ark} ${unit.displayBitcoinAmount(parts.ark)}',
                                  style: CoconutTypography.body3_12_Number.copyWith(color: colors.secondaryText),
                                ),
                                ..._pendingIcons(arkPending, 'ark'),
                              ],
                            ),
                          ),
                        ],
                        if (onUnlockArk case final unlock?) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            key: const Key('wallet-detail-card-unlock-ark'),
                            behavior: HitTestBehavior.opaque,
                            onTap: unlock,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  CommonSecurityIconPath.lock,
                                  width: 12,
                                  height: 12,
                                  colorFilter: ColorFilter.mode(colors.secondaryText, BlendMode.srcIn),
                                ),
                                const SizedBox(width: 4),
                                CustomUnderlinedButton(
                                  text: t.ark.unlock.action,
                                  onTap: unlock,
                                  padding: EdgeInsets.zero,
                                  defaultColor: colors.secondaryText,
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final slotWidth = (constraints.maxWidth - _actionGap * (_actionSlots - 1)) / _actionSlots;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: _actionGap,
                  children: [
                    for (final action in actions) SizedBox(width: slotWidth, child: _ActionButton(action: action)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class WalletDetailCardAction {
  final Key key;
  final String label;
  final String iconPath;
  final VoidCallback onPressed;

  const WalletDetailCardAction({
    required this.key,
    required this.label,
    required this.iconPath,
    required this.onPressed,
  });

  static List<WalletDetailCardAction> standard({
    required VoidCallback onReceive,
    required VoidCallback onSend,
    required VoidCallback onOrganize,
    required VoidCallback onChart,
    required bool hasBalance,
  }) => [
    WalletDetailCardAction(
      key: const Key('wallet-detail-action-receive'),
      label: t.receive,
      iconPath: FeatureTransactionIconPath.receivePlane,
      onPressed: onReceive,
    ),
    if (hasBalance)
      WalletDetailCardAction(
        key: const Key('wallet-detail-action-send'),
        label: t.send,
        iconPath: FeatureShortcutIconPath.send,
        onPressed: onSend,
      ),
    if (hasBalance)
      WalletDetailCardAction(
        key: const Key('wallet-detail-action-organize'),
        label: t.feature_registry.utxo_organizer_short,
        iconPath: FeatureUtxoIconPath.mergeUtxos,
        onPressed: onOrganize,
      ),
    WalletDetailCardAction(
      key: const Key('wallet-detail-action-chart'),
      label: t.wallet_balance_history_screen.title,
      iconPath: FeatureWidgetIconPath.chart,
      onPressed: onChart,
    ),
  ];
}

/// Only the visible face is mounted, so hidden card actions cannot receive taps.
class WalletDetailFlipCard extends StatefulWidget {
  final bool isFocused;
  final Widget Function(VoidCallback flip) frontBuilder;
  final Widget Function(VoidCallback flip) backBuilder;
  final Widget Function(Widget) surfaceBuilder;

  const WalletDetailFlipCard({
    super.key,
    required this.isFocused,
    required this.frontBuilder,
    required this.backBuilder,
    required this.surfaceBuilder,
  });

  @override
  State<WalletDetailFlipCard> createState() => _WalletDetailFlipCardState();
}

class _WalletDetailFlipCardState extends State<WalletDetailFlipCard> {
  bool _showChart = false;

  @override
  void didUpdateWidget(covariant WalletDetailFlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isFocused) _showChart = false;
  }

  void _flip() {
    if (!widget.isFocused) return;
    setState(() => _showChart = !_showChart);
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: _showChart ? 1 : 0),
    duration: Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 600),
    curve: Curves.easeInOutCubic,
    builder: (context, progress, _) {
      final back = progress >= 0.5;
      return Transform(
        key: const Key('wallet-detail-card-flip'),
        alignment: Alignment.center,
        transform:
            Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(math.pi * (back ? progress - 1 : progress)),
        child: IgnorePointer(
          ignoring: !widget.isFocused,
          child: widget.surfaceBuilder(back ? widget.backBuilder(_flip) : widget.frontBuilder(_flip)),
        ),
      );
    },
  );
}

class _ActionButton extends StatelessWidget {
  static const double size = 44;

  final WalletDetailCardAction action;

  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShrinkAnimationButton(
          key: action.key,
          onPressed: action.onPressed,
          defaultColor: colors.homeSurfaceButton,
          pressedOverlayColor: colors.surfacePressOverlay,
          pressedOverlayOpacity: colors.surfacePressOverlayOpacity,
          borderRadius: size / 2,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: SvgPicture.asset(
                action.iconPath,
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(colors.surfaceButtonText, BlendMode.srcIn),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            action.label,
            maxLines: 1,
            style: CoconutTypography.body3_12.copyWith(color: colors.secondaryText),
          ),
        ),
      ],
    );
  }
}
