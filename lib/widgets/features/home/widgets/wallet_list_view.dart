import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 지갑 아이콘, 이름, 잔액을 한 줄로 보여 준다.
class WalletBalanceRow extends StatelessWidget {
  final WalletItemBase wallet;
  final String balanceText;
  final double height;
  final VoidCallback? onTap;

  const WalletBalanceRow({
    super.key,
    required this.wallet,
    required this.balanceText,
    required this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final appearance = context.watchWalletAppearance()?.appearanceOf(wallet) ?? WalletAppearance.of(wallet);
    final row = SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox.square(dimension: 24, child: FittedBox(child: WalletCard.iconOf(wallet, appearance))),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text(
                wallet.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CoconutTypography.body3_12_Bold.copyWith(color: colors.primaryText),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  balanceText,
                  style: CoconutTypography.body2_14_NumberBold.copyWith(color: colors.primaryText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return HomePressableRow(onTap: onTap!, child: row);
  }
}

/// 4×2: 지갑마다 이름과 잔액을 한 줄씩, 최대 [rows]줄
/// 지갑이 더 많으면 마지막 줄을 모두 보기로 쓰고, 칸이 남으면 지갑 추가 줄을 둔다.
/// 보이는 줄 수만큼 높이를 나누되 최소 2등분한다.
class WalletListView extends StatelessWidget {
  static const rows = 4;

  final List<WalletItemBase> wallets;
  final String Function(WalletItemBase wallet) balanceTextOf;
  final void Function(WalletItemBase wallet) onWalletPressed;
  final VoidCallback onShowAllPressed;
  final String emptyText;
  final String? emptyActionText;
  final VoidCallback? onEmptyPressed;

  /// 없으면 칸이 남아도 지갑 추가 줄을 두지 않는다.
  final VoidCallback? onAddPressed;

  const WalletListView({
    super.key,
    required this.wallets,
    required this.balanceTextOf,
    required this.onWalletPressed,
    required this.onShowAllPressed,
    required this.emptyText,
    this.emptyActionText,
    this.onEmptyPressed,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty) {
      return WalletEmptyCard(
        key: const Key('wallet-list-empty'),
        emptyText: emptyText,
        actionText: emptyActionText,
        onPressed: onEmptyPressed,
      );
    }
    final colors = context.coconutColors;
    final overflows = wallets.length > rows;
    final shown = overflows ? wallets.take(rows - 1).toList() : wallets;
    final showsAdd = !overflows && wallets.length < rows && onAddPressed != null;
    final visibleRows = shown.length + (showsAdd || overflows ? 1 : 0);
    final splitRows = math.max(visibleRows, 2);
    Widget divider() => Container(margin: const EdgeInsets.symmetric(horizontal: 16), height: 1, color: colors.divider);
    return HomeWidgetCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rowHeight = (constraints.maxHeight - (splitRows - 1)) / splitRows;
          return Column(
            key: const Key('wallet-list'),
            mainAxisAlignment: visibleRows < splitRows ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              for (final (index, wallet) in shown.indexed) ...[
                if (index > 0) divider(),
                WalletBalanceRow(
                  key: ValueKey('wallet-list-row-${wallet.id}'),
                  wallet: wallet,
                  balanceText: balanceTextOf(wallet),
                  height: rowHeight,
                  onTap: () => onWalletPressed(wallet),
                ),
              ],
              if (showsAdd) ...[
                divider(),
                WalletListActionRow(
                  key: const Key('wallet-list-add'),
                  height: rowHeight,
                  leading: SvgPicture.asset(
                    CommonActionIconPath.plus,
                    width: 12,
                    height: 12,
                    colorFilter: ColorFilter.mode(colors.secondaryText, BlendMode.srcIn),
                  ),
                  text: t.home_widgets.add_wallet,
                  textColor: colors.secondaryText,
                  onTap: onAddPressed!,
                ),
              ],
              if (overflows) ...[
                divider(),
                WalletListActionRow(
                  key: const Key('wallet-list-show-all'),
                  height: rowHeight,
                  text: t.home_widgets.wallet_list_show_all(count: wallets.length),
                  textColor: colors.secondaryText,
                  onTap: onShowAllPressed,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 지갑 목록 끝에 두는 지갑 추가·모두 보기 줄
class WalletListActionRow extends StatelessWidget {
  final double height;
  final Widget? leading;
  final String text;
  final Color textColor;
  final VoidCallback onTap;

  const WalletListActionRow({
    super.key,
    required this.height,
    this.leading,
    required this.text,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HomePressableRow(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 4)],
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CoconutTypography.body3_12_Bold.copyWith(color: textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
