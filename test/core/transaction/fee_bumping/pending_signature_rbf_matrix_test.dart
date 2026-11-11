// 미확정 거래 서명 확인(동기화) + 수수료 올리기 원래 거래 확인(RbfPreparer) + 거래 번호 확인(ElectrumService)을 함께 본다.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/core/exceptions/rbf_creation/rbf_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_builder.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_preparer.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../providers/node_provider/transaction/pending_sync_harness.dart';
import '../../../repository/realm/test_realm_manager.dart';
import '../../../services/network/electrum/electrum_service_test.mocks.dart';

SingleSignatureVault _vault(int byte) => SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, byte)));

void main() {
  NetworkType.setNetworkType(NetworkType.regtest);
  final signer = walletSigners(0x10).first;
  final shop = _vault(0x77).getAddress(0);
  final attacker = _vault(0x88).getAddress(0);
  late TestRealmManager realm;
  late SyncedWallet wallet;
  late Transaction deposit;
  late UtxoState coin;
  late Transaction own;

  setUp(() async {
    realm = TestRealmManager();
    wallet = SyncedWallet(realm, signer.item, purpose: signer.purpose);
    final funded = signer.funded([100000], 1);
    deposit = funded.funding;
    coin = funded.coins.single;
    own = signer.pay([coin], {shop: 30000});
    wallet.publish([deposit, own]);
    await wallet.sync([history(deposit, 100)], unspentList: wallet.unspent(deposit, 100));
    await wallet.sync([history(deposit, 100), history(own, 0)]);
  });
  tearDown(() => realm.dispose());

  /// 수수료 올리기 화면과 같은 방법으로 원래 거래를 준비한다(서버가 준 원문을 쓴다)
  RbfPreparer prepare(Transaction pending) => RbfPreparer.fromPendingTx(
    pendingTx: wallet.txs.getTransactionRecord(walletId, pending.transactionHash)!,
    rawTx: wallet.server.rawByHash[pending.transactionHash]!,
    getUtxos: (utxoId) => wallet.utxos.getUtxoState(walletId, utxoId),
    isMyAddress:
        (address, {bool isChange = false}) => wallet.addresses.containsAddress(walletId, address, isChange: isChange),
    getDerivationPath: (address) => wallet.addresses.getDerivationPath(walletId, address),
  );

  /// 앱의 수수료 올리기와 같은 방법으로 [pending]을 대체하는 거래를 만들어 서명한다
  Transaction bump(Transaction pending, double feeRate, int changeIndex) {
    final result = RbfBuilder(
      preparer: prepare(pending),
      walletItemBase: signer.item,
      nextChangeAddress: WalletAddress(
        wallet.address(changeIndex, isChange: true),
        '${signer.purpose}/1/$changeIndex',
        changeIndex,
        true,
        false,
        0,
        0,
        0,
      ),
    ).build(newFeeRate: feeRate);
    expect(result.isSuccess, isTrue, reason: '${result.exception}');
    return signer.sign(result.transaction!);
  }

  /// 대체 거래가 퍼지면 서버는 원래 거래를 더는 주지 않는다
  Future<void> replace(Transaction previous, Transaction replacement) async {
    wallet.server.rawByHash.remove(previous.transactionHash);
    wallet.publish([replacement]);
    await wallet.sync([history(deposit, 100), history(replacement, 0)]);
  }

  final unverified = isA<RbfCreationException>().having((e) => e.message, 'message', contains('could not be verified'));

  test('바꿔치기 뒤에도 내 결제로 수수료를 올릴 수 있고, 대체 거래는 원래 받는 사람에게 보낸다', () async {
    final fake = withGarbageSignatures(own, attacker, AddressType.p2wpkh);
    wallet.publish([fake]);
    await wallet.sync([history(deposit, 100), history(fake, 0)]);
    expect(wallet.txs.getTransactionRecord(walletId, fake.transactionHash), isNull);

    final replacement = bump(own, 5, 1);
    expect(replacement.outputs.where((o) => o.getAddress() == shop).single.amount, 30000);
    expect(replacement.outputs.map((o) => o.getAddress()), isNot(contains(attacker)));
    await replace(own, replacement);

    expect(wallet.txs.getTransactionRecord(walletId, replacement.transactionHash)?.blockHeight, 0);
    expect(wallet.coin(coin.transactionHash, 0)?.spentByTransactionHash, replacement.transactionHash);
    expect(wallet.snapshot()['rbf'], contains('${own.transactionHash}>${replacement.transactionHash}'));
    expect(wallet.leavesNoTrace(fake.transactionHash), isTrue);
  });

  test('대체 거래를 한 번 더 올려도(두 번 올리기) 모두 확인해 넣고, 마지막 거래만 보내는 중으로 남는다', () async {
    final second = bump(own, 5, 1);
    await replace(own, second);
    final third = bump(second, 10, 2);
    await replace(second, third);

    expect(
      wallet.txs.getUnconfirmedTransactionRecordList(walletId, excludeReplaced: true).map((r) => r.transactionHash),
      [third.transactionHash],
    );
    expect(wallet.coin(coin.transactionHash, 0)?.spentByTransactionHash, third.transactionHash);
    expect(wallet.snapshot()['rbf'], contains('${own.transactionHash}>${second.transactionHash}'));
    expect(third.outputs.where((o) => o.getAddress() == shop).single.amount, 30000);
  });

  test('업데이트 전에 저장된 가짜로는 수수료를 올릴 수 없고(A), 업데이트 뒤 동기화도 그 거래를 다시 넣지 않는다', () async {
    final fake = withGarbageSignatures(own, attacker, AddressType.p2wpkh);
    wallet.publish([fake]);
    // 이 수정 전 앱이 저장한 그대로: 거래 기록과 코인 상태
    final record = await TransactionRecordService(
      wallet.server,
      wallet.addresses,
    ).createTransactionRecord(walletId, fake, previousTxs: [deposit], now: DateTime(2026, 11, 11));
    await wallet.txs.addAllTransactions(walletId, [record]);
    await wallet.utxos.markUtxoAsOutgoing(walletId, fake);

    expect(() => prepare(fake), throwsA(unverified));

    final before = wallet.snapshot();
    await wallet.sync([history(deposit, 100), history(fake, 0)]);
    expect(wallet.snapshot(), before);
    expect(() => prepare(fake), throwsA(unverified));
  });

  test('서버가 내 결제 번호에 다른 거래를 주면(B, 실제 ElectrumService) 그 응답을 쓰지 않고 내 결제를 지우지 않는다', () async {
    final fake = withGarbageSignatures(own, attacker, AddressType.p2wpkh);
    final foreign = _vault(0x55);
    final foreignFunding = fundingTransaction([(foreign.getAddress(0), 80000)], 93);
    final incoming = Transaction.withInputsAndOutputs(
      [TransactionInput.forPayment(foreignFunding.transactionHash, 0)],
      [
        TransactionOutput.forPayment(40000, wallet.address(0)),
        TransactionOutput.forPayment(39000, foreign.getAddress(1)),
      ],
      AddressType.p2wpkh,
    );
    signP2wpkhInput(
      incoming,
      0,
      TransactionOutput.forPayment(80000, foreign.getAddress(0)),
      foreign.keyStore.hdWallet.derive(0).derive(0),
    );
    wallet.publish([foreignFunding, incoming]);
    final served = {...wallet.server.rawByHash, own.transactionHash: fake.serialize()};

    final socket = MockSocketManager();
    final electrum = ElectrumService(socketManager: socket);
    final requested = <int, String>{};
    when(socket.connect(any, any, ssl: anyNamed('ssl'))).thenAnswer((_) async => true);
    await electrum.connect('localhost', 50001, ssl: false);
    when(socket.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(socket.send(any)).thenAnswer((invocation) async {
      final request = jsonDecode(invocation.positionalArguments[0] as String) as Map<String, dynamic>;
      requested[request['id'] as int] = (request['params'] as List).first as String;
    });
    when(socket.setCompleter(any, any)).thenAnswer((invocation) {
      final id = invocation.positionalArguments[0] as int;
      (invocation.positionalArguments[1] as Completer).complete({'id': id, 'result': served[requested[id]]});
    });
    wallet.server.transactionSource = electrum.getTransaction;
    await expectLater(electrum.getTransaction(own.transactionHash), throwsA(isA<FormatException>()));

    await wallet.sync([history(deposit, 100), history(own, 0), history(incoming, 0)]);

    expect(wallet.txs.getTransactionRecord(walletId, incoming.transactionHash), isNotNull);
    expect(wallet.txs.getTransactionRecord(walletId, own.transactionHash)?.blockHeight, 0);
    expect(wallet.coin(coin.transactionHash, 0)?.spentByTransactionHash, own.transactionHash);
  });
}
