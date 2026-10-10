import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_item_card.dart';
import 'package:provider/provider.dart';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_dialog.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/text/icon_title_description.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';

enum MoveToVaultDestination { noBalance, noWatchOnlyWallet, selectWatchOnlyWallet, send }

MoveToVaultDestination resolveMoveToVaultDestination(int balance, int watchOnlyWalletCount) {
  if (balance <= 0) return MoveToVaultDestination.noBalance;
  if (watchOnlyWalletCount == 0) return MoveToVaultDestination.noWatchOnlyWallet;
  if (watchOnlyWalletCount >= 2) return MoveToVaultDestination.selectWatchOnlyWallet;
  return MoveToVaultDestination.send;
}

class ShowVaultNoBalanceBottomSheet extends StatelessWidget {
  final int walletId;
  const ShowVaultNoBalanceBottomSheet({super.key, required this.walletId});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconTitleDescription(
          svgIconPath: CommonStateIconPath.circleInfo,
          title: t.wallet_detail_screen.vault_intro,
          description: t.wallet_detail_screen.vault_description,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Divider(height: 1, color: context.coconutColors.divider),
        ),
        SvgPicture.asset(
          CommonStateIconPath.circleWarning,
          width: 36,
          height: 36,
          colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
        ),
        CoconutLayout.spacing_400h,
        Text(
          t.wallet_detail_screen.vault_no_balance_title,
          style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
        ),
        CoconutLayout.spacing_100h,
        Text(
          t.wallet_detail_screen.vault_no_balance_description,
          style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
        ),
        CoconutLayout.spacing_800h,
        InlineActionButton(
          onPressed: () async {
            final navigator = Navigator.of(context);
            final sheetRoute = ModalRoute.of(context);
            navigator.pop();
            await sheetRoute?.completed;
            if (!navigator.mounted) return;
            navigator.pushNamed(AppRouteNames.receiveAddress, arguments: ReceiveAddressRouteArgs(id: walletId));
          },
          text: t.receive,
        ),
      ],
    );
  }
}

class ShowVaultNoWatchOnlyWalletBottomSheet extends StatelessWidget {
  final int walletId;
  const ShowVaultNoWatchOnlyWalletBottomSheet({super.key, required this.walletId});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconTitleDescription(
          svgIconPath: CommonStateIconPath.circleInfo,
          title: t.wallet_detail_screen.vault_intro,
          description: t.wallet_detail_screen.vault_description,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Divider(height: 1, color: context.coconutColors.divider),
        ),
        IconTitleDescription(
          svgIconPath: FeatureWalletIconPath.walletEyes,
          title: t.wallet_detail_screen.vault_watch_only_title,
          description: t.wallet_detail_screen.vault_watch_only_description,
        ),
        CoconutLayout.spacing_800h,
        InlineActionButton(
          onPressed: () async {
            final navigator = Navigator.of(context);
            final sheetRoute = ModalRoute.of(context);
            navigator.pop();
            await sheetRoute?.completed;
            if (!navigator.mounted) return;
            WalletAddDialog.showBottomSheet(
              navigator.context,
              WalletAddDialogMode.watchOnlySource,
              replaceCurrentRouteOnWalletSelected: true,
            );
          },
          text: t.wallet_detail_screen.vault_connect_watch_only_wallet,
        ),
      ],
    );
  }
}

class ShowVaultSelectWalletBottomSheet extends StatelessWidget {
  final int walletId;
  final List<WalletItemBase> watchOnlyWallets;
  final ScrollController? scrollController;
  const ShowVaultSelectWalletBottomSheet({
    super.key,
    required this.walletId,
    required this.watchOnlyWallets,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<PreferenceProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final availableWallets =
        watchOnlyWallets
            .where((wallet) => !wallet.hasLocalKey && walletProvider.walletItemList.any((item) => item.id == wallet.id))
            .toList();
    final wallets = [
      for (final id in preferences.walletOrder) ...availableWallets.where((wallet) => wallet.id == id),
      ...availableWallets.where((wallet) => !preferences.walletOrder.contains(wallet.id)),
    ];
    final list = SingleChildScrollView(
      controller: scrollController,
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < wallets.length; index++)
            Padding(
              padding: EdgeInsets.only(bottom: index == wallets.length - 1 ? 0 : 12),
              child: WalletItemCard(
                key: ValueKey(wallets[index].id),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                walletItem: wallets[index],
                animatedBalanceData: AnimatedBalanceData(
                  walletProvider.getWalletBalance(wallets[index].id).total,
                  walletProvider.getWalletBalance(wallets[index].id).total,
                ),
                currentUnit: preferences.currentUnit,
                isLastItem: index == wallets.length - 1,
                isStarVisible: false,
                shrinkContentOnly: true,
                backgroundColor: context.coconutColors.homeSurface,
                pressedOverlayColor: context.coconutColors.homeSurfacePressOverlay,
                pressedOverlayOpacity: context.coconutColors.homeSurfacePressOverlayOpacity,
                watchedAddressCount: walletProvider.getWatchedAddressCount(wallets[index].id),
                rightWidget: SvgPicture.asset(
                  CommonNavigationIconPath.arrowRight,
                  width: 6,
                  height: 10,
                  colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
                ),
                onPressed: () => Navigator.of(context).pop(wallets[index].id),
              ),
            ),
        ],
      ),
    );
    if (scrollController == null) return list;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Center(
                    child: Text(
                      t.wallet_detail_screen.vault_select_receiving_wallet,
                      style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close_rounded, size: 24, color: context.coconutColors.iconPrimary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: list)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
