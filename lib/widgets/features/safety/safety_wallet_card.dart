import 'package:coconut_design_system/coconut_design_system.dart' show CoconutStyles;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart' show kHomeTileMaxTextScale;
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_caution_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 안전 화면의 지갑 카드(가이드·Assist 공용, POLISH H1): Epic 2 WalletCard wide, 4×2 홈 타일 높이.
/// 잔액은 앱 잔액 표시 설정을 따른다(숨김이면 없음, 가짜 잔액이면 가짜 금액, 실제 잔액은 안 보임).
/// 높이가 고정이라 홈 타일과 같은 배율에서 글자 확대를 멈춘다(GPT M4)
class SafetyWalletCard extends StatelessWidget {
  const SafetyWalletCard({super.key, required this.walletId, this.animateBadge = false});

  final int walletId;

  /// 사용 주의 배지가 나타날 때 커지며 들어온다(동작 줄이기면 없음)
  final bool animateBadge;

  @override
  Widget build(BuildContext context) {
    final wallets = context.watch<WalletProvider?>();
    final wallet = wallets?.walletItemList.firstWhereOrNull((w) => w.id == walletId);
    if (wallets == null || wallet == null) return const SizedBox.shrink();
    final preferences = context.watch<PreferenceProvider?>();
    String? balance;
    if (preferences != null && !preferences.isBalanceHidden) {
      final sats =
          preferences.isFakeBalanceActive
              ? preferences.getFakeBalance(walletId).round()
              : wallets.getWalletBalance(walletId).total;
      balance = preferences.currentUnit.displayBitcoinAmount(sats, withUnit: true);
    }
    var badge = safetyCautionBadgeFor(context, walletId);
    if (badge != null && animateBadge && !safetyReduceMotion(context)) {
      badge = badge.scaleInAnimation(delay: const Duration(milliseconds: 300));
    }
    final colors = context.coconutColors;
    return SizedBox(
      height: 148,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: kHomeTileMaxTextScale,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          // 라이트는 카드(homeSurface)와 단계 화면 바탕이 같은 흰색이라 얇은 테두리로 카드 경계를 남긴다
          decoration:
              colors.homeSurface == colors.background
                  ? BoxDecoration(
                    border: Border.all(color: colors.border.withValues(alpha: 0.21)),
                    borderRadius: BorderRadius.circular(CoconutStyles.radius_300),
                  )
                  : const BoxDecoration(),
          child: WalletCard(
            wallet: wallet,
            appearance: WalletAppearance.of(wallet),
            size: WalletCardSize.wide,
            balanceDisplay: balance,
            statusBadge: badge,
          ),
        ),
      ),
    );
  }
}
