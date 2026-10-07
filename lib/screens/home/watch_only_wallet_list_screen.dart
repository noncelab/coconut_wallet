import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart' show kEntryPointWalletList;
import 'package:coconut_wallet/services/home/watch_only_wallet_stack_definition.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_item_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class WatchOnlyWalletListScreen extends StatelessWidget {
  const WatchOnlyWalletListScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      CupertinoPageRoute(
        settings: const RouteSettings(name: '/watch-only-wallet-list'),
        builder: (_) => const WatchOnlyWalletListScreen(),
      ),
    );
  }

  void _openWalletDetail(BuildContext context, WalletItemBase wallet) {
    Navigator.pushNamed(
      context,
      AppRouteNames.walletDetail,
      arguments: WalletDetailRouteArgs(id: wallet.id, entryPoint: kEntryPointWalletList),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final walletProvider = context.watch<WalletProvider>();
    final preferences = context.watch<PreferenceProvider>();
    final wallets = orderWatchOnlyWallets(walletProvider.walletItemList, preferences.walletOrder);
    final balances = walletProvider.fetchWalletBalanceMap();
    final excluded = preferences.excludedFromTotalBalanceWalletIds;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(
        context: context,
        backgroundColor: colors.background,
        title: t.home_edit.watch_only_wallet_stack,
      ),
      body: SafeArea(
        child:
            wallets.isEmpty
                ? Center(
                  key: const Key('watch-only-wallet-list-empty'),
                  child: Text(
                    t.wallet_list.empty_watch_only,
                    textAlign: TextAlign.center,
                    style: CoconutTypography.body2_14.copyWith(color: colors.secondaryText),
                  ),
                )
                : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 40),
                  itemCount: wallets.length,
                  separatorBuilder: (_, __) => CoconutLayout.spacing_200h,
                  itemBuilder: (context, index) {
                    final wallet = wallets[index];
                    final balance = balances[wallet.id]?.total ?? 0;
                    return WalletItemCard(
                      key: ValueKey('watch-only-wallet-list-item-${wallet.id}'),
                      walletItem: wallet,
                      animatedBalanceData: AnimatedBalanceData(balance, balance),
                      isLastItem: index == wallets.length - 1,
                      currentUnit: preferences.currentUnit,
                      backgroundColor: colors.background,
                      isExcludeFromTotalBalance: excluded.contains(wallet.id),
                      isStarVisible: false,
                      onPressed: () => _openWalletDetail(context, wallet),
                      rightWidget: SvgPicture.asset(
                        CommonNavigationIconPath.arrowRight,
                        width: 6,
                        height: 10,
                        colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
