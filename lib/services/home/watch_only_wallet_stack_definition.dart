import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/watch_only_wallet_list_screen.dart';
import 'package:coconut_wallet/widgets/features/home/watch_only_wallet_stack_view.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

List<WalletItemBase> orderWatchOnlyWallets(List<WalletItemBase> wallets, List<int> walletOrder) {
  final watchOnly = wallets.where((wallet) => !wallet.hasLocalKey).toList();
  final rank = {for (var i = 0; i < walletOrder.length; i++) walletOrder[i]: i};
  final indexed = [for (var i = 0; i < watchOnly.length; i++) (i, watchOnly[i])];
  indexed.sort((a, b) {
    final rankA = rank[a.$2.id] ?? walletOrder.length + a.$1;
    final rankB = rank[b.$2.id] ?? walletOrder.length + b.$1;
    return rankA.compareTo(rankB);
  });
  return [for (final entry in indexed) entry.$2];
}

class WatchOnlyWalletStackDefinition extends HomeItemDefinition {
  WatchOnlyWalletStackDefinition()
    : super(
        id: HomeItemIds.watchOnlyWalletStack,
        kind: HomeItemKind.widget,
        supportedSpans: const [HomeSpan.small],
        category: 'wallets',
      );

  @override
  String displayName() => t.home_edit.watch_only_wallet_stack;

  @override
  Widget build(BuildContext context, HomeItem item) {
    final walletOrder = context.select<PreferenceProvider, List<int>>((preferences) => preferences.walletOrder);
    return ValueListenableBuilder<List<WalletItemBase>>(
      valueListenable: context.read<WalletProvider>().walletItemListNotifier,
      builder:
          (context, wallets, _) => WatchOnlyWalletStackView(
            wallets: orderWatchOnlyWallets(wallets, walletOrder),
            onPressed: () => WatchOnlyWalletListScreen.open(context),
          ),
    );
  }
}
