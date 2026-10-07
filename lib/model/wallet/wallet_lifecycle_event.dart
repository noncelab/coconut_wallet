import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';

sealed class WalletLifecycleEvent {
  final int walletId;

  const WalletLifecycleEvent(this.walletId);
}

class WalletAdded extends WalletLifecycleEvent {
  const WalletAdded(super.walletId);
}

class WalletRemoved extends WalletLifecycleEvent {
  const WalletRemoved(super.walletId);
}

class WalletUpdated extends WalletLifecycleEvent {
  const WalletUpdated(super.walletId);
}

class WalletSnapshot {
  final int id;
  final String name;
  final int colorIndex;
  final int iconIndex;
  final bool hasLocalKey;

  const WalletSnapshot({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.iconIndex,
    required this.hasLocalKey,
  });

  factory WalletSnapshot.of(WalletItemBase wallet) {
    return WalletSnapshot(
      id: wallet.id,
      name: wallet.name,
      colorIndex: wallet.colorIndex,
      iconIndex: wallet.iconIndex,
      hasLocalKey: wallet.hasLocalKey,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WalletSnapshot &&
        other.id == id &&
        other.name == name &&
        other.colorIndex == colorIndex &&
        other.iconIndex == iconIndex &&
        other.hasLocalKey == hasLocalKey;
  }

  @override
  int get hashCode => Object.hash(id, name, colorIndex, iconIndex, hasLocalKey);
}

Map<int, WalletSnapshot> snapshotWallets(List<WalletItemBase> wallets) {
  return {for (final wallet in wallets) wallet.id: WalletSnapshot.of(wallet)};
}

List<WalletLifecycleEvent> diffWalletSnapshots(Map<int, WalletSnapshot> before, Map<int, WalletSnapshot> after) {
  final events = <WalletLifecycleEvent>[];
  for (final id in before.keys) {
    if (!after.containsKey(id)) events.add(WalletRemoved(id));
  }
  for (final entry in after.entries) {
    final previous = before[entry.key];
    if (previous == null) {
      events.add(WalletAdded(entry.key));
    } else if (previous != entry.value) {
      events.add(WalletUpdated(entry.key));
    }
  }
  return events;
}
