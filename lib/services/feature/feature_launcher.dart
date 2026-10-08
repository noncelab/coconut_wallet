import 'package:coconut_wallet/app/router/feature_entry_routes.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/model/home/shortcut_wallet_context.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

enum WalletChoiceKind { direct, ask, unavailable }

class WalletChoice {
  final WalletChoiceKind kind;
  final int? walletId;
  final List<int> candidates;

  const WalletChoice.direct(int this.walletId) : kind = WalletChoiceKind.direct, candidates = const [];

  const WalletChoice.ask(this.candidates) : kind = WalletChoiceKind.ask, walletId = null;

  const WalletChoice.unavailable() : kind = WalletChoiceKind.unavailable, walletId = null, candidates = const [];

  @override
  bool operator ==(Object other) =>
      other is WalletChoice &&
      other.kind == kind &&
      other.walletId == walletId &&
      const ListEquality<int>().equals(other.candidates, candidates);

  @override
  int get hashCode => Object.hash(kind, walletId, Object.hashAll(candidates));

  @override
  String toString() => 'WalletChoice($kind, $walletId, $candidates)';
}

WalletChoice resolveWallet(FeatureItem item, List<WalletItemBase> wallets, ShortcutWalletContext? walletContext) {
  final supported = wallets.where(item.supportsWallet).toList();
  if (supported.isEmpty) return const WalletChoice.unavailable();

  final preferredId = walletContext?.mode == ShortcutWalletMode.wallet ? walletContext!.walletId : null;
  if (preferredId != null && supported.any((wallet) => wallet.id == preferredId)) {
    return WalletChoice.direct(preferredId);
  }
  if (supported.length == 1) return WalletChoice.direct(supported.single.id);
  return WalletChoice.ask(supported.map((wallet) => wallet.id).toList());
}

enum FeatureLaunchResult { launched, cancelled, unavailable }

typedef WalletPicker = Future<int?> Function(BuildContext context, List<int> candidateWalletIds);

class FeatureLauncher {
  final List<WalletItemBase> Function() wallets;
  final WalletPicker pickWallet;

  const FeatureLauncher({required this.wallets, required this.pickWallet});

  Future<FeatureLaunchResult> launch(
    BuildContext context,
    FeatureItem item, {
    ShortcutWalletContext? walletContext,
  }) async {
    final launch = item.launch;
    if (launch == null) return FeatureLaunchResult.unavailable;
    if (item.isAvailable != null && !item.isAvailable!(context)) return FeatureLaunchResult.unavailable;

    if (item.context == FeatureContext.none) {
      await FeatureEntryRoutes.instance.launching(() => launch(context, null));
      return FeatureLaunchResult.launched;
    }

    final allWallets = wallets();
    final choice = resolveWallet(item, allWallets, walletContext);
    int? walletId;
    switch (choice.kind) {
      case WalletChoiceKind.unavailable:
        return FeatureLaunchResult.unavailable;
      case WalletChoiceKind.direct:
        walletId = choice.walletId;
      case WalletChoiceKind.ask:
        walletId = await pickWallet(context, choice.candidates);
    }
    final wallet = allWallets.firstWhereOrNull((w) => w.id == walletId);
    if (wallet == null || !context.mounted) return FeatureLaunchResult.cancelled;
    await FeatureEntryRoutes.instance.launching(() => launch(context, wallet));
    return FeatureLaunchResult.launched;
  }
}
