import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card_background.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 지갑 목록 휠 → 지갑 상세 전환. 휠 카드의 배경이 카드 자리에서 화면 전체로 펼쳐지고, 그 위로 상세 화면이 나타난다.
/// 돌아갈 때는 그때 보던 지갑의 카드 자리로 배경이 접혀 들어간다.
class WalletDetailExpandTransition extends StatelessWidget {
  final Animation<double> animation;

  /// 지금 보고 있는 지갑. 상세에서 카드를 넘기면 바뀐다.
  final ValueListenable<int> walletId;

  /// 그 지갑의 휠 카드 자리(화면 좌표). 못 찾으면 화면 가운데에서 펼친다.
  final Rect? Function(int walletId) cardRectOf;

  final Widget child;

  const WalletDetailExpandTransition({
    super.key,
    required this.animation,
    required this.walletId,
    required this.cardRectOf,
    required this.child,
  });

  static const double _cardRadius = 20;

  @override
  Widget build(BuildContext context) {
    final expand = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
    final reveal = CurvedAnimation(parent: animation, curve: const Interval(0.45, 1, curve: Curves.easeOut));
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([animation, walletId]),
          builder: (context, _) {
            if (animation.value >= 1) return const SizedBox.shrink();
            final t = expand.value;
            final screen = Offset.zero & MediaQuery.sizeOf(context);
            final origin = cardRectOf(walletId.value) ?? Rect.fromCenter(center: screen.center, width: 0, height: 0);
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: Rect.lerp(origin, screen, t)!,
                  child: Opacity(
                    opacity: const Interval(0, 0.2).transform(animation.value),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_cardRadius * (1 - t)),
                      child: _background(context, t),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        FadeTransition(opacity: reveal, child: child),
      ],
    );
  }

  Widget _background(BuildContext context, double t) {
    final wallets = context.read<WalletProvider>();
    final appearances = context.readWalletAppearance();
    final wallet = wallets.walletItemList.where((item) => item.id == walletId.value).firstOrNull;
    final background =
        wallet == null ? null : (appearances?.appearanceOf(wallet) ?? WalletAppearance.of(wallet)).background;
    if (background == null) {
      final colors = context.coconutColors;
      return ColoredBox(color: Color.lerp(colors.homeSurface, colors.homeBackground, t)!);
    }
    return WalletCardBackground(background: background, photoFile: appearances?.photoFileFor(walletId.value));
  }
}
