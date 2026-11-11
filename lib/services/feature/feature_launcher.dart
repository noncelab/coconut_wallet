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

/// 기능을 연 곳(홈 바로가기 / 모든 기능). 지금은 Wallet Health 진입 구분(T5-03)에만 쓴다
enum FeatureSurface { homeShortcut, allFeatures }

typedef WalletPicker = Future<int?> Function(BuildContext context, List<int> candidateWalletIds);

class FeatureLauncher {
  final List<WalletItemBase> Function() wallets;
  final WalletPicker pickWallet;

  const FeatureLauncher({required this.wallets, required this.pickWallet});

  /// 기능을 연 곳. 기능의 launch가 (동기로) 불리는 그 순간에만 값이 있고, 그 밖에서는 null이다
  static FeatureSurface? get launchingSurface => _launchingSurface;
  static FeatureSurface? _launchingSurface;

  static Future<void> _invoke(
    FeatureLaunch launch,
    BuildContext context,
    WalletItemBase? wallet,
    FeatureSurface? surface,
  ) {
    _launchingSurface = surface;
    try {
      return launch(context, wallet);
    } finally {
      _launchingSurface = null;
    }
  }

  Future<FeatureLaunchResult> launch(
    BuildContext context,
    FeatureItem item, {
    ShortcutWalletContext? walletContext,
    FeatureSurface? surface,
  }) async {
    final launch = item.launch;
    if (launch == null) return FeatureLaunchResult.unavailable;
    if (item.isAvailable != null && !item.isAvailable!(context)) return FeatureLaunchResult.unavailable;

    if (item.context == FeatureContext.none) {
      await FeatureEntryRoutes.instance.launching(() => _invoke(launch, context, null, surface));
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
    if (walletId == null || !context.mounted) return FeatureLaunchResult.cancelled;
    if (choice.kind == WalletChoiceKind.ask && !choice.candidates.contains(walletId)) {
      return FeatureLaunchResult.unavailable;
    }
    // A picker may stay open while a wallet is removed or its capabilities change.
    final wallet = wallets().firstWhereOrNull((w) => w.id == walletId && item.supportsWallet(w));
    if (wallet == null || (item.isAvailable != null && !item.isAvailable!(context))) {
      return FeatureLaunchResult.unavailable;
    }
    await FeatureEntryRoutes.instance.launching(() => _invoke(launch, context, wallet, surface));
    return FeatureLaunchResult.launched;
  }
}
