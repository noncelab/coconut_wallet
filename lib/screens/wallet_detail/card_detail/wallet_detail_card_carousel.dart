import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
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
import 'package:coconut_wallet/widgets/features/wallet/amount/wallet_balance_sync_shimmer.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 지갑 상세 위쪽의 가로 카드 휠. 가운데 카드 양옆으로 이웃 카드의 기울어진 가장자리가 보인다.
class WalletDetailCardCarousel extends StatefulWidget {
  final List<WalletItemBase> wallets;
  final int initialIndex;
  final ValueChanged<WalletItemBase> onFocusChanged;

  /// 넘기는 중인 페이지 위치(예: 1.3은 두 번째와 세 번째 카드 사이).
  final ValueChanged<double>? onPageScrolled;
  final Widget Function(BuildContext context, WalletItemBase wallet, bool isFocused) cardBuilder;

  const WalletDetailCardCarousel({
    super.key,
    required this.wallets,
    required this.initialIndex,
    required this.onFocusChanged,
    required this.cardBuilder,
    this.onPageScrolled,
  });

  /// 카드 폭은 화면 폭의 [widthFraction], 높이는 폭의 [aspect] 배.
  static const double widthFraction = 0.86;
  static const double aspect = 0.66;

  static double heightFor(double screenWidth) => screenWidth * widthFraction * aspect;

  @override
  State<WalletDetailCardCarousel> createState() => _WalletDetailCardCarouselState();
}

class _WalletDetailCardCarouselState extends State<WalletDetailCardCarousel> {
  static const double _tilt = 0.09;
  static const double _neighborScale = 0.9;
  static const double _gap = 16;

  PageController? _controller;
  late int _focused = widget.initialIndex;

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

  double get _page {
    final controller = _controller!;
    return controller.hasClients && controller.position.haveDimensions
        ? controller.page ?? _focused.toDouble()
        : _focused.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.sizeOf(context).width * WalletDetailCardCarousel.widthFraction;
    return SizedBox(
      height: WalletDetailCardCarousel.heightFor(MediaQuery.sizeOf(context).width) + 16,
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
                child: widget.cardBuilder(context, widget.wallets[index], index == _focused),
              ),
            ),
      ),
    );
  }
}

/// 지갑 상세 카드. 이름·아이콘, 잔액·법정화폐 금액, 동작 버튼을 담는다.
class WalletDetailCard extends StatelessWidget {
  static const int _actionSlots = 4;
  static const double _actionGap = 6;

  final WalletItemBase wallet;
  final WalletAppearance appearance;
  final int balance;
  final BitcoinUnit unit;
  final bool isSyncing;
  final VoidCallback? onBalanceTap;
  final List<WalletDetailCardAction> actions;

  const WalletDetailCard({
    super.key,
    required this.wallet,
    required this.appearance,
    required this.balance,
    required this.unit,
    required this.actions,
    this.isSyncing = false,
    this.onBalanceTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.homeSurface,
        borderRadius: BorderRadius.circular(28),
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
                    style: CoconutTypography.body2_14_Bold.copyWith(color: colors.secondaryText),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    WalletBalanceSyncShimmer(
                      isRefreshing: isSyncing,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: BitcoinAmountUnit(
                          currentUnit: unit,
                          unitStyle: CoconutTypography.heading4_18_NumberBold.copyWith(color: colors.primaryText),
                          child: AnimatedBalance(
                            key: const Key('wallet-detail-card-balance'),
                            prevValue: balance,
                            value: balance,
                            currentUnit: unit,
                            textStyle: CoconutTypography.heading2_28_NumberBold.copyWith(color: colors.primaryText),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FiatPrice(
                      satoshiAmount: balance,
                      textStyle: CoconutTypography.body3_12.copyWith(color: colors.secondaryText),
                    ),
                    const SizedBox(height: 10),
                  ],
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
    required VoidCallback onDetails,
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
      key: const Key('wallet-detail-action-details'),
      label: t.wallet_card_detail_screen.details,
      iconPath: FeatureSettingsIconPath.settings,
      onPressed: onDetails,
    ),
  ];
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
