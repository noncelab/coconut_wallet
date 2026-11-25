import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ark_test_fakes.dart';

ArkMovement _round({required String status, required List<String> inputs}) => ArkMovement.fromBark(
  bark.Movement(
    id: 5,
    status: status,
    subsystemName: 'bark.round',
    subsystemKind: 'refresh',
    metadataJson: '{}',
    intendedBalanceSats: 0,
    effectiveBalanceSats: 0,
    offchainFeeSats: 0,
    sentToAddresses: const [],
    receivedOnAddresses: const [],
    inputVtxoIds: inputs,
    outputVtxoIds: const [],
    exitedVtxoIds: const [],
    createdAt: '2026-11-25T14:00:00Z',
    updatedAt: '2026-11-25T14:00:00Z',
  ),
);

ArkBalance _balance({required int spendable, required int inRound}) => ArkBalance(
  spendable: spendable,
  pendingInRound: inRound,
  pendingBoard: 0,
  pendingExit: 0,
  pendingLightningSend: 0,
  claimableLightningReceive: 0,
);

void main() {
  test('a renewal waiting for the server counts its VTXOs once, not as spendable and in round', () async {
    final backend =
        FakeArkBackend()
          ..vtxoList = [fakeVtxo('a:0', sats: 7500), fakeVtxo('b:0', sats: 3240), fakeVtxo('c:0', sats: 3240)]
          ..currentBalance = _balance(spendable: 13980, inRound: 13980)
          ..movements = [_round(status: 'pending', inputs: ['a:0', 'b:0', 'c:0'])];
    final wallet = await fakeArkWalletProvider(backend: backend);
    await wallet.createNew();
    await wallet.syncNow();

    expect(wallet.balance.total, 13980);
  });

  test('once the server holds the inputs, they count only in round', () async {
    final backend =
        FakeArkBackend()
          ..vtxoList = [fakeVtxo('a:0', sats: 7500, locked: true)]
          ..currentBalance = _balance(spendable: 0, inRound: 7500)
          ..movements = [_round(status: 'pending', inputs: ['a:0'])];
    final wallet = await fakeArkWalletProvider(backend: backend);
    await wallet.createNew();
    await wallet.syncNow();

    expect(wallet.balance.total, 7500);
  });
}
