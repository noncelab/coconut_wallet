import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../repository/realm/test_realm_manager.dart';
import 'pending_sync_harness.dart';

void main() {
  test('확정·미확정 거래가 함께 오면 두 거래의 이전 거래를 함께 받기 시작하고, 거래 기록을 만들 때 다시 받지 않는다', () async {
    NetworkType.setNetworkType(NetworkType.regtest);
    final realm = TestRealmManager();
    addTearDown(realm.dispose);
    final signer = walletSigners(0x10).first;
    final wallet = SyncedWallet(realm, signer.item, purpose: signer.purpose, addressCount: 2);
    final sender = SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, 0x55)));

    // 서로 다른 남의 이전 거래에서 같은 내 주소로 오는 정상 입금 두 개. 하나는 확정, 하나는 미확정
    final parents = [
      fundingTransaction([(sender.getAddress(0), 50000)], 1),
      fundingTransaction([(sender.getAddress(0), 50000)], 2),
    ];
    final incoming = [
      for (final parent in parents)
        Transaction.withInputsAndOutputs(
          [TransactionInput.forPayment(parent.transactionHash, 0)],
          [TransactionOutput.forPayment(49000, wallet.address(0))],
          AddressType.p2wpkh,
        ),
    ];
    for (final (index, tx) in incoming.indexed) {
      signP2wpkhInput(tx, 0, parents[index].outputs.single, sender.keyStore.hdWallet.derive(0).derive(0));
    }
    wallet.publish([...parents, ...incoming]);

    // 이전 거래 응답을 막아 두고, 미확정 쪽 응답이 오기 전에 확정 쪽 요청도 시작됐는지 본다
    final confirmedParent = parents[0].transactionHash;
    final pendingParent = parents[1].transactionHash;
    final pendingRequested = Completer<void>();
    final release = Completer<void>();
    final requested = <String>[];
    wallet.server.transactionSource = (txHash) async {
      if (txHash == confirmedParent || txHash == pendingParent) {
        requested.add(txHash == confirmedParent ? 'confirmed' : 'pending');
        if (txHash == pendingParent && !pendingRequested.isCompleted) pendingRequested.complete();
        await release.future;
      }
      return wallet.server.rawByHash[txHash] ?? (throw StateError('unavailable $txHash'));
    };

    final syncing = wallet.sync([history(incoming[0], 100), history(incoming[1], 0)]);
    await pendingRequested.future;
    await Future<void>.delayed(Duration.zero);
    final requestedBeforeRelease = List.of(requested);
    release.complete();
    await syncing;

    expect(requestedBeforeRelease, unorderedEquals(['confirmed', 'pending']));
    expect(requested, unorderedEquals(['confirmed', 'pending']));
    // 수수료는 이전 거래가 있어야 계산된다(50,000 − 49,000). 확정 거래 기록도 3-1의 이전 거래로 만들었는지 본다
    for (final tx in incoming) {
      final record = wallet.txs.getTransactionRecord(walletId, tx.transactionHash);
      expect(record?.amount, 49000);
      expect(record?.fee, 1000);
    }
  });
}
