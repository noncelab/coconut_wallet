import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/widgets.dart';

class WatchOnlyWalletStackView extends StatelessWidget {
  final List<WalletItemBase> wallets;
  final VoidCallback? onPressed;

  const WatchOnlyWalletStackView({super.key, required this.wallets, this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty) {
      final colors = context.coconutColors;
      return GestureDetector(
        key: const Key('watch-only-stack-empty'),
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(20)),
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  t.wallet_list.empty_watch_only,
                  textAlign: TextAlign.center,
                  style: CoconutTypography.body3_12.copyWith(color: colors.secondaryText),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final wallet = wallets.first;
    return WalletCard(
      key: ValueKey('watch-only-stack-card-${wallet.id}'),
      wallet: wallet,
      appearance: WalletAppearance.of(wallet),
      size: WalletCardSize.small,
      onPressed: onPressed,
    );
  }
}
