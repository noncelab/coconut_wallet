import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_dialog.dart';
import 'package:coconut_wallet/analytics/wallet_add_analytics.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/screens/home/wallet_stack_list_screen.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// 지갑 스택 종류: 핫월렛만, 보기 전용 지갑만, 모든 지갑
enum WalletStackKind { hot, watchOnly, all }

/// [kind]에 맞는 지갑을 지갑 순서대로
List<WalletItemBase> orderStackWallets(
  List<WalletItemBase> wallets,
  List<int> walletOrder, {
  required WalletStackKind kind,
}) {
  final filtered = switch (kind) {
    WalletStackKind.hot => wallets.where((wallet) => wallet.hasLocalKey).toList(),
    WalletStackKind.watchOnly => wallets.where((wallet) => !wallet.hasLocalKey).toList(),
    WalletStackKind.all => [...wallets],
  };
  final rank = {for (var i = 0; i < walletOrder.length; i++) walletOrder[i]: i};
  final indexed = [for (var i = 0; i < filtered.length; i++) (i, filtered[i])];
  indexed.sort((a, b) {
    final rankA = rank[a.$2.id] ?? walletOrder.length + a.$1;
    final rankB = rank[b.$2.id] ?? walletOrder.length + b.$1;
    return rankA.compareTo(rankB);
  });
  return [for (final entry in indexed) entry.$2];
}

String walletStackName(WalletStackKind kind) => switch (kind) {
  WalletStackKind.hot => t.home_widgets.hot_wallet_stack,
  WalletStackKind.watchOnly => t.home_edit.watch_only_wallet_stack,
  WalletStackKind.all => t.home_widgets.all_wallet_stack,
};

String walletStackEmptyText(WalletStackKind kind) => switch (kind) {
  WalletStackKind.hot => t.wallet_list.empty_hot_wallet,
  WalletStackKind.watchOnly => t.wallet_list.empty_watch_only,
  WalletStackKind.all => t.home_widgets.empty_all_wallets,
};

/// 지갑 스택. 각 종류는 홈에 하나만 두고, 크기는 2×2와 4×2 중에서 바꿀 수 있다.
class WalletStackDefinition extends HomeItemDefinition {
  final WalletStackKind stackKind;

  WalletStackDefinition(this.stackKind)
    : super(
        id: switch (stackKind) {
          WalletStackKind.hot => HomeItemIds.hotWalletStack,
          WalletStackKind.watchOnly => HomeItemIds.watchOnlyWalletStack,
          WalletStackKind.all => HomeItemIds.allWalletStack,
        },
        kind: HomeItemKind.widget,
        supportedSpans: const [HomeSpan.small, HomeSpan.wide],
        category: HomeItemCategory.wallets,
        needsConfigureBeforeAdd: true,
        settings: const HomeWidgetSettingsSpec(sizes: [HomeSpan.wide, HomeSpan.small]),
      );

  @override
  String displayName() => walletStackName(stackKind);

  @override
  Widget build(BuildContext context, HomeItem item) {
    final viewModel = context.watch<HomeWidgetsViewModel>();
    final isWide = item.span == HomeSpan.wide;
    if (viewModel.isWalletDataLoading) return HomeWidgetSkeleton(wide: isWide);
    final now = DateTime.now();
    return WalletStackView(
      key: ValueKey('$id-${item.id}-${item.span.toJson()}'),
      keyPrefix: id,
      wallets: switch (stackKind) {
        WalletStackKind.hot => viewModel.hotWallets,
        WalletStackKind.watchOnly => viewModel.watchOnlyWallets,
        WalletStackKind.all => viewModel.wallets,
      },
      size: isWide ? WalletCardSize.wide : WalletCardSize.small,
      emptyText: walletStackEmptyText(stackKind),
      balanceTextOf:
          isWide
              ? (wallet) => viewModel.unit.displayBitcoinAmount(viewModel.balanceOf(wallet.id), withUnit: true)
              : null,
      secondaryTextOf:
          isWide
              ? null
              : (wallet) {
                final last = viewModel.lastTransactionTime(wallet.id);
                return last == null ? null : formatHomeRelativeTime(last, now);
              },
      onPressed: () => WalletStackListScreen.open(context, kind: stackKind),
      onOpen: (request) => WalletStackListScreen.open(context, kind: stackKind, request: request),
      emptyActionText: switch (stackKind) {
        WalletStackKind.hot => t.wallet_home_screen.wallet_type_selection.hot_wallet.title,
        WalletStackKind.watchOnly => t.wallet_home_screen.wallet_type_selection.watch_only.title,
        WalletStackKind.all => t.home_widgets.add_wallet,
      },
      onEmptyPressed: () => openWalletAddFor(context, stackKind),
    );
  }
}

/// 모든 지갑이면 지갑 수에 따라 지갑 추가 화면이나 탑 시트를 열고, 한 종류면 그 종류의 추가 시트를 연다.
void openWalletAddFor(BuildContext context, WalletStackKind kind) {
  context.read<AnalyticsService>().logWalletAddButtonClicked(entrySource: WalletAddEntrySource.homeEmpty);
  switch (kind) {
    case WalletStackKind.all:
      WalletAddScreen.openByWalletCount(context);
    case WalletStackKind.hot:
      WalletAddDialog.show(context, WalletAddDialogMode.hotWalletAction);
    case WalletStackKind.watchOnly:
      WalletAddDialog.show(context, WalletAddDialogMode.watchOnlySource);
  }
}

List<HomeItemDefinition> walletStackDefinitions() => [
  WalletStackDefinition(WalletStackKind.all),
  WalletStackDefinition(WalletStackKind.watchOnly),
  WalletStackDefinition(WalletStackKind.hot),
];
