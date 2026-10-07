import 'package:coconut_wallet/model/wallet/wallet_lifecycle_event.dart';
import 'package:flutter_test/flutter_test.dart';

WalletSnapshot _snapshot(int id, {String name = 'w', int colorIndex = 0, int iconIndex = 0, bool hasLocalKey = false}) {
  return WalletSnapshot(id: id, name: name, colorIndex: colorIndex, iconIndex: iconIndex, hasLocalKey: hasLocalKey);
}

Map<int, WalletSnapshot> _map(List<WalletSnapshot> snapshots) => {for (final s in snapshots) s.id: s};

void main() {
  test('a wallet present only after the change is reported as added', () {
    final events = diffWalletSnapshots(_map([_snapshot(1)]), _map([_snapshot(1), _snapshot(2)]));

    expect(events, hasLength(1));
    expect(events.single, isA<WalletAdded>());
    expect(events.single.walletId, 2);
  });

  test('a wallet present only before the change is reported as removed', () {
    final events = diffWalletSnapshots(_map([_snapshot(1), _snapshot(2)]), _map([_snapshot(1)]));

    expect(events.single, isA<WalletRemoved>());
    expect(events.single.walletId, 2);
  });

  test('a renamed wallet is reported once as updated, not as removed and added', () {
    final events = diffWalletSnapshots(_map([_snapshot(1, name: 'old')]), _map([_snapshot(1, name: 'new')]));

    expect(events, hasLength(1));
    expect(events.single, isA<WalletUpdated>());
    expect(events.single.walletId, 1);
  });

  test('a color, icon, or key-ownership change is reported as updated', () {
    expect(diffWalletSnapshots(_map([_snapshot(1)]), _map([_snapshot(1, colorIndex: 3)])).single, isA<WalletUpdated>());
    expect(diffWalletSnapshots(_map([_snapshot(1)]), _map([_snapshot(1, iconIndex: 2)])).single, isA<WalletUpdated>());
    expect(
      diffWalletSnapshots(_map([_snapshot(1, hasLocalKey: true)]), _map([_snapshot(1)])).single,
      isA<WalletUpdated>(),
    );
  });

  test('an unchanged list produces no events', () {
    expect(diffWalletSnapshots(_map([_snapshot(1), _snapshot(2)]), _map([_snapshot(1), _snapshot(2)])), isEmpty);
  });
}
