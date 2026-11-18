import 'package:coconut_wallet/screens/ccos/ark/ark_vtxo_groups.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../ccos/features/ark/ark_test_fakes.dart';

void main() {
  test('VTXOs group as expiring, spendable and locked, leaving out empty groups', () {
    final due = fakeVtxo('due', expiry: 1100);
    final fine = fakeVtxo('fine', expiry: 5000);
    final locked = fakeVtxo('locked', locked: true);
    final renewing = fakeVtxo('renewing', expiry: 1050);

    final groups = groupArkVtxos([due, fine, locked, renewing], toRenew: [due], isRenewing: (id) => id == 'renewing');

    expect(groups.map((group) => group.kind), ArkVtxoGroupKind.values);
    expect(groups[0].vtxos, [due]);
    expect(groups[1].vtxos, [fine]);
    expect(groups[2].vtxos, [locked, renewing]);
    expect(groupArkVtxos([fine], toRenew: const [], isRenewing: (_) => false).single.kind, ArkVtxoGroupKind.spendable);
  });

  test('locked and renewing VTXOs cannot be picked for renewal, expired ones can', () {
    bool canRenew(vtxo) => canRenewArkVtxo(vtxo, tipHeight: 1000, isRenewing: (id) => id == 'renewing');

    expect(canRenew(fakeVtxo('ok', expiry: 1001)), isTrue);
    expect(canRenew(fakeVtxo('locked', locked: true)), isFalse);
    expect(canRenew(fakeVtxo('renewing')), isFalse);
    expect(canRenew(fakeVtxo('expired', expiry: 1000)), isTrue);
  });

  test('the lifetime used so far runs from expiry minus the server lifetime to expiry', () {
    expect(arkVtxoLifetimeUsed(fakeVtxo('a', expiry: 2000), tipHeight: 1500, lifetime: 1000), 0.5);
    expect(arkVtxoLifetimeUsed(fakeVtxo('a', expiry: 2000), tipHeight: 2500, lifetime: 1000), 1);
    expect(arkVtxoLifetimeUsed(fakeVtxo('a', expiry: 2000), tipHeight: 500, lifetime: 1000), 0);
    expect(arkVtxoLifetimeUsed(fakeVtxo('a', expiry: 2000), tipHeight: null, lifetime: 1000), isNull);
    expect(arkVtxoLifetimeUsed(fakeVtxo('a', expiry: 2000), tipHeight: 1500, lifetime: null), isNull);
  });
}
