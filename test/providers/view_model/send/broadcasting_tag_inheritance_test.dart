import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_draft.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/broadcasting_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/payjoin_session_repository.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_send_attempt.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/transaction_mock.dart';
import '../../../mock/utxo_mock.dart';
import '../../../repository/realm/test_realm_manager.dart';

const _inputHash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _previousHash = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

class _WalletProvider extends Fake implements WalletProvider {
  final WalletItemBase wallet;
  final Set<String> ownedAddresses = {};

  _WalletProvider(this.wallet);

  @override
  WalletItemBase getWalletById(int id) => wallet;

  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) =>
      walletId == wallet.id && ownedAddresses.contains(address);
}

class _NodeProvider extends Fake implements NodeProvider {
  int broadcasts = 0;
  int reconnects = 0;
  bool fails = false;
  bool connected = true;
  Completer<bool>? reconnecting;
  void Function()? duringBroadcast;

  @override
  String host = 'localhost';

  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async =>
      connected ? Result.success(BlockTimestamp(100, DateTime(2026))) : Result.failure(ErrorCodes.nodeConnectionError);

  @override
  Future<Result<bool>> reconnect() => throw StateError('broadcast must not wait for wallet subscription');

  @override
  Future<bool> reconnectWithoutWaitingForSync() {
    reconnects++;
    return reconnecting?.future ?? Future.value(true);
  }

  /// 앞에서부터 차례로 쓰는 전송 결과 (비면 [fails]를 따름)
  final List<AppError?> broadcastErrors = [];
  int lookups = 0;
  bool transactionFound = false;
  Completer<void>? lookingUp;
  Completer<void>? resending;

  @override
  Future<Result<String>> broadcast(Transaction signedTx) async {
    broadcasts++;
    duringBroadcast?.call();
    if (broadcasts > 1) await resending?.future;
    if (broadcastErrors.isNotEmpty) {
      final error = broadcastErrors.removeAt(0);
      return error == null ? Result.success(signedTx.transactionHash) : Result.failure(error);
    }
    return fails ? Result.failure(ErrorCodes.broadcastError) : Result.success(signedTx.transactionHash);
  }

  @override
  Future<Result<String>> getTransaction(String txHash) async {
    lookups++;
    await lookingUp?.future;
    return transactionFound ? Result.success('raw') : Result.failure(ErrorCodes.nodeUnknown);
  }
}

/// Ends with [outcome], or throws when it is null.
class _Attempt extends Fake implements PayjoinSendAttempt {
  final PayjoinSendOutcome? outcome;

  _Attempt(this.outcome);

  @override
  Future<PayjoinSendOutcome> run({
    required int walletId,
    required String bip21,
    required String signedOriginalPsbt,
    required String originalTxHex,
    required double feeRateSatPerVb,
  }) async => outcome ?? (throw StateError('the directory is unreachable'));
}

class _TransactionProvider extends Fake implements TransactionProvider {
  TransactionRecord? previous;

  @override
  TransactionRecord? getTransactionRecord(int walletId, String txHash) =>
      walletId == 1 && previous?.transactionHash == txHash ? previous : null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestRealmManager manager;
  late UtxoRepository repository;
  late _NodeProvider node;
  late _TransactionProvider transactions;
  late _WalletProvider wallets;
  late SingleSignatureVault vault;
  late BroadcastingViewModel viewModel;
  late UtxoTagProvider tags;
  late SendInfoProvider sendInfo;

  setUpAll(() {
    NetworkType.setNetworkType(NetworkType.testnet);
    vault = SingleSignatureVault.fromEntropy(Uint8List(16));
  });

  setUp(() {
    manager = TestRealmManager();
    repository = UtxoRepository(manager);
    node = _NodeProvider();
    transactions = _TransactionProvider();
    wallets = _WalletProvider(
      SinglesigWalletItem(id: 1, name: 'Test', colorIndex: 0, iconIndex: 0, descriptor: vault.descriptor),
    );
    tags = UtxoTagProvider(repository);
    manager.realm.write(() {
      manager.realm.add(
        UtxoMock.createUnspentRealmUtxo(walletId: 1, address: vault.getAddress(0), transactionHash: _inputHash),
      );
    });
    expect(repository.getUtxoState(1, getUtxoId(_inputHash, 0)), isNotNull);
  });

  tearDown(() {
    tags.dispose();
    manager.dispose();
  });

  void addTag(String id, String source, {int walletId = 1}) {
    manager.realm.write(() {
      manager.realm.add(RealmUtxoTag(id, walletId, id, 0, DateTime(2026), utxoIdList: [source]));
    });
  }

  List<String> tagIds(String utxoId, {int walletId = 1}) =>
      repository.getUtxoTagsByTxHash(walletId, utxoId).value.map((tag) => tag.id).toList();

  Future<void> initializeTransaction(
    Transaction transaction, {
    bool returnPsbt = false,
    FeeBumpingType? feeBumpingType,
    SelectedUtxoExcludedStatus? expectedExcludedStatus,
  }) async {
    transaction.changeAddressDerivationPath = "${vault.derivationPath}/1/1";
    final original = Psbt.fromTransaction(transaction, vault);
    final signed = Psbt.parse(vault.addSignatureToPsbt(original.serialize()));
    if (returnPsbt) {
      // Some signers retain input derivation but omit optional output metadata.
      signed.psbtMap['outputs'][0].clear();
    }
    sendInfo =
        SendInfoProvider()
          ..setWalletId(1)
          ..setFeeBumpingType(feeBumpingType)
          ..setTxWaitingForSign(original.serialize())
          ..setSignedResult(
            returnPsbt ? signed.serialize() : signed.getSignedTransaction(AddressType.p2wpkh).serialize(),
          );
    viewModel = BroadcastingViewModel(
      sendInfo,
      wallets,
      tags,
      true,
      node,
      transactions,
      TransactionDraftRepository(manager),
      repository,
      null,
    );
    addTearDown(viewModel.dispose);
    expect(await viewModel.setTxInfo(), expectedExcludedStatus);
    expect(viewModel.isInitDone, expectedExcludedStatus == null);
  }

  Future<void> initialize({
    bool ownOutput = true,
    bool outputDerivation = true,
    bool returnPsbt = false,
    int outputAmount = 999000,
    FeeBumpingType? feeBumpingType,
    SelectedUtxoExcludedStatus? expectedExcludedStatus,
  }) async {
    final recipient = ownOutput ? vault.getAddress(1, isChange: true) : vault.getAddress(10);
    final transaction = Transaction.withInputsAndOutputs(
      [TransactionInput.forPayment(_inputHash, 0, sequence: 0xfffffffd)],
      [
        TransactionOutput.forPayment(
          outputAmount,
          recipient,
          derivationPath: ownOutput && outputDerivation ? "${vault.derivationPath}/1/1" : null,
          isChangeOutput: ownOutput && outputDerivation,
        ),
      ],
      AddressType.p2wpkh,
    );
    transaction.utxoList.add(Utxo(_inputHash, 0, 1000000, "${vault.derivationPath}/0/0"));
    await initializeTransaction(
      transaction,
      returnPsbt: returnPsbt,
      feeBumpingType: feeBumpingType,
      expectedExcludedStatus: expectedExcludedStatus,
    );
  }

  String targetId() => getUtxoId(viewModel.signedTx!.transactionHash, 0);
  final inputId = getUtxoId(_inputHash, 0);
  final realmInputId = getRealmUtxoId(1, _inputHash, 0);

  test('output details preserve transaction indices with change at any position', () async {
    for (final changeIndex in [0, 1, 2]) {
      final outputs = [
        TransactionOutput.forPayment(200000, vault.getAddress(10)),
        TransactionOutput.forPayment(200000, vault.getAddress(11)),
      ]..insert(
        changeIndex,
        TransactionOutput.forPayment(
          599000,
          vault.getAddress(1, isChange: true),
          derivationPath: '${vault.derivationPath}/1/1',
          isChangeOutput: true,
        ),
      );
      final transaction = Transaction.withInputsAndOutputs(
        [TransactionInput.forPayment(_inputHash, 0, sequence: 0xfffffffd)],
        outputs,
        AddressType.p2wpkh,
      );
      transaction.utxoList.add(Utxo(_inputHash, 0, 1000000, '${vault.derivationPath}/0/0'));
      await initializeTransaction(transaction);

      expect(viewModel.outputDetailItems.map((item) => item.outputIndex), [0, 1, 2]);
      expect(
        viewModel.outputDetailItems.where((item) => !item.isChange).map((item) => item.outputIndex),
        [0, 1, 2].where((index) => index != changeIndex),
      );
      expect(viewModel.externalOutputAmounts, [200000, 200000]);
      expect(viewModel.changeOutputAmounts, [599000]);
      expect(viewModel.fee, 1000);
      for (final item in viewModel.outputDetailItems) {
        expect(item.address, viewModel.signedTx!.outputs[item.outputIndex].getAddress());
        expect(item.amount, viewModel.signedTx!.outputs[item.outputIndex].amount);
      }
    }
  });

  test('normal broadcast persists input tags on a PSBT-owned output and clears only consumed links', () async {
    addTag('savings', inputId);
    addTag('unrelated', 'another-utxo');
    addTag('other-wallet', inputId, walletId: 2);
    await initialize(returnPsbt: true);
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), ['savings']);

    final result = await viewModel.broadcast(inheritedTagIds: ['savings']);

    expect(result!.isSuccess, isTrue);
    expect(tagIds(targetId()), ['savings']);
    expect(tagIds(inputId), isEmpty);
    expect(tagIds('another-utxo'), ['unrelated']);
    expect(tagIds(inputId, walletId: 2), ['other-wallet']);
    expect(viewModel.tagInheritanceFailed, isFalse);
    expect(tags.isUpdatedTagList, isTrue);
  });

  test('address ownership recognizes self-send outputs without PSBT output derivation', () async {
    addTag('savings', inputId);
    wallets.ownedAddresses.add(vault.getAddress(1, isChange: true));
    await initialize(outputDerivation: false);
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), ['savings']);
    await viewModel.broadcast(inheritedTagIds: ['savings']);
    expect(tagIds(targetId()), ['savings']);
  });

  test('failed broadcast preserves source links and retry uses the original snapshot', () async {
    addTag('savings', inputId);
    await initialize();
    viewModel.prepareTagInheritance();
    node.fails = true;
    expect((await viewModel.broadcast(inheritedTagIds: ['savings']))!.isFailure, isTrue);
    expect(tagIds(inputId), ['savings']);
    expect(tagIds(targetId()), isEmpty);

    manager.realm.write(() => manager.realm.find<RealmUtxoTag>('savings')!.utxoIdList.clear());
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), ['savings']);
    node.fails = false;
    expect((await viewModel.broadcast(inheritedTagIds: ['savings']))!.isSuccess, isTrue);
    expect(tagIds(targetId()), ['savings']);
    expect(node.broadcasts, 2);
  });

  test('sync removing source associations during broadcast cannot erase the captured tags', () async {
    addTag('savings', inputId);
    await initialize();
    viewModel.prepareTagInheritance();
    node.duringBroadcast = () {
      manager.realm.write(() => manager.realm.find<RealmUtxoTag>('savings')!.utxoIdList.clear());
    };
    await viewModel.broadcast(inheritedTagIds: ['savings']);
    expect(tagIds(targetId()), ['savings']);
  });

  test('normal broadcast marks the spent input as outgoing before sync', () async {
    await initialize();

    final result = await viewModel.broadcast(inheritedTagIds: const []);

    expect(result!.isSuccess, isTrue);
    expect(node.reconnects, 0);
    final input = repository.getUtxoState(1, inputId)!;
    expect(input.status, UtxoStatus.outgoing);
    expect(input.spentByTransactionHash, viewModel.signedTx!.transactionHash);
  });

  test('disconnected broadcast waits only for the connection, not wallet subscription', () async {
    node.connected = false;
    await initialize();

    final result = await viewModel.broadcast(inheritedTagIds: const []);

    expect(result!.isSuccess, isTrue);
    expect(node.reconnects, 1);
    expect(node.broadcasts, 1);
  });

  test('leaving the screen while reconnecting never sends the transaction', () async {
    node.connected = false;
    node.reconnecting = Completer<bool>();
    await initialize();

    final pending = viewModel.broadcast(inheritedTagIds: const []);
    await Future<void>.delayed(Duration.zero);
    viewModel.dispose();
    node.reconnecting!.complete(true);

    expect(await pending, isNull);
    expect(node.broadcasts, 0);
    expect(repository.getUtxoState(1, inputId)!.status, UtxoStatus.unspent);
  });

  test('a reconnect that fails reports a connection error without sending', () async {
    node.connected = false;
    node.reconnecting = Completer<bool>()..complete(false);
    await initialize();

    final result = await viewModel.broadcast(inheritedTagIds: const []);

    expect(result!.error.code, ErrorCodes.nodeConnectionError.code);
    expect(
      BroadcastingViewModel.broadcastFailureMessage(result.error.message),
      t.broadcasting_screen.dialog.not_sent_no_connection,
    );
    expect(node.broadcasts, 0);
  });

  testWidgets('waiting for the connection gives up after 15 seconds without sending', (tester) async {
    node.connected = false;
    node.reconnecting = Completer<bool>();
    await tester.runAsync(() => initialize());

    Result<String>? result;
    viewModel.broadcast(inheritedTagIds: const []).then((value) => result = value);
    await tester.pump(const Duration(seconds: 14));
    expect(result, isNull);
    await tester.pump(const Duration(seconds: 1));

    expect(result!.error.code, ErrorCodes.nodeConnectionError.code);
    expect(
      BroadcastingViewModel.broadcastFailureMessage(result!.error.message),
      t.broadcasting_screen.dialog.not_sent_no_connection,
    );
    expect(node.broadcasts, 0);
  });

  testWidgets('a Tor connection waits up to 120 seconds without sending', (tester) async {
    node.host = 'example.onion';
    node.connected = false;
    node.reconnecting = Completer<bool>();
    await tester.runAsync(() => initialize());

    Result<String>? result;
    viewModel.broadcast(inheritedTagIds: const []).then((value) => result = value);
    await tester.pump(const Duration(seconds: 119));
    expect(result, isNull);
    await tester.pump(const Duration(seconds: 1));

    expect(result!.error.code, ErrorCodes.nodeConnectionError.code);
    expect(node.broadcasts, 0);
  });

  test('going to the background while reconnecting stops waiting and never sends', () async {
    node.connected = false;
    node.reconnecting = Completer<bool>();
    await initialize();

    final pending = viewModel.broadcast(inheritedTagIds: const []);
    await Future<void>.delayed(Duration.zero);
    viewModel.cancelPendingBroadcast();

    expect(await pending, isNull);
    expect(node.broadcasts, 0);
    expect(repository.getUtxoState(1, inputId)!.status, UtxoStatus.unspent);
  });

  test('a cancel requested before the broadcast starts is honored, then cleared for the next send', () async {
    await initialize();

    viewModel.cancelPendingBroadcast();
    expect(await viewModel.broadcast(inheritedTagIds: const []), isNull);
    expect(node.broadcasts, 0);

    expect((await viewModel.broadcast(inheritedTagIds: const []))!.isSuccess, isTrue);
    expect(node.broadcasts, 1);
  });

  test('a cancel after the transaction is handed to the node does not change the result', () async {
    await initialize();
    node.duringBroadcast = viewModel.cancelPendingBroadcast;

    expect((await viewModel.broadcast(inheritedTagIds: const []))!.isSuccess, isTrue);
    expect(node.broadcasts, 1);
    expect(repository.getUtxoState(1, inputId)!.status, UtxoStatus.outgoing);
  });

  test('transaction is marked as dispatched only once it is handed to the node', () async {
    node.connected = false;
    node.reconnecting = Completer<bool>();
    await initialize();
    bool? dispatchedDuringBroadcast;
    node.duringBroadcast = () => dispatchedDuringBroadcast = viewModel.isBroadcastDispatched;

    final pending = viewModel.broadcast(inheritedTagIds: const []);
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.isBroadcastDispatched, isFalse);
    node.reconnecting!.complete(true);
    await pending;

    expect(dispatchedDuringBroadcast, isTrue);
    expect(viewModel.isBroadcastDispatched, isTrue);
  });

  test('failed broadcast is no longer dispatched so the user can leave', () async {
    node.fails = true;
    await initialize();

    await viewModel.broadcast(inheritedTagIds: const []);

    expect(viewModel.isBroadcastDispatched, isFalse);
  });

  test('an unanswered broadcast that reached the node is reported as sent', () async {
    node.broadcastErrors.add(ErrorCodes.nodeIsolateError);
    node.transactionFound = true;
    await initialize();

    final result = await viewModel.broadcast(inheritedTagIds: const []);

    expect(result!.isSuccess, isTrue);
    expect(result.value, viewModel.signedTx!.transactionHash);
    expect(node.lookups, 1);
    expect(viewModel.isBroadcastResultUnknown, isFalse);
    expect(node.broadcasts, 1);
    expect(repository.getUtxoState(1, inputId)!.status, UtxoStatus.outgoing);
  });

  test('an unanswered broadcast not found on the node is sent once more as the same transaction', () async {
    node.broadcastErrors.addAll([ErrorCodes.nodeUnknown, null]);
    await initialize();

    final result = await viewModel.broadcast(inheritedTagIds: const []);

    expect(result!.isSuccess, isTrue);
    expect(node.lookups, 1);
    expect(node.broadcasts, 2);
    expect(repository.getUtxoState(1, inputId)!.status, UtxoStatus.outgoing);
  });

  test('a broadcast whose result stays unknown asks the user to send the same transaction again', () async {
    node.broadcastErrors.addAll([ErrorCodes.nodeIsolateError, ErrorCodes.nodeIsolateError]);
    await initialize();

    final result = await viewModel.broadcast(inheritedTagIds: const []);

    expect(
      BroadcastingViewModel.broadcastFailureMessage(result!.error.message),
      t.broadcasting_screen.dialog.result_unknown,
    );
    expect(node.broadcasts, 2);
    expect(viewModel.isBroadcastResultUnknown, isTrue);
    expect(viewModel.isBroadcastDispatched, isFalse);
    expect(repository.getUtxoState(1, inputId)!.status, UtxoStatus.unspent);
  });

  group('payjoin send session', () {
    const sessionId = 'payjoin-send';
    late PayjoinSessionRepository sessions;

    setUp(() {
      sessions = PayjoinSessionRepository(manager)..create(id: sessionId, walletId: 1, role: PayjoinRole.send);
    });

    bool isOpen() => sessions.openSessions(role: PayjoinRole.send).any((session) => session.id == sessionId);

    test('closes with the broadcast txid once the node accepts the transaction', () async {
      await initialize();
      viewModel.settlePayjoinSessionOnAccept(sessions, sessionId);

      expect((await viewModel.broadcast(inheritedTagIds: const []))!.isSuccess, isTrue);

      expect(isOpen(), isFalse);
      expect(sessions.readValue(sessionId, PayjoinSendValues.broadcastTxid), viewModel.signedTx!.transactionHash);
    });

    test('stays open when the node rejects the transaction', () async {
      node.fails = true;
      await initialize();
      viewModel.settlePayjoinSessionOnAccept(sessions, sessionId);

      expect((await viewModel.broadcast(inheritedTagIds: const []))!.isFailure, isTrue);

      expect(isOpen(), isTrue);
      expect(sessions.readValue(sessionId, PayjoinSendValues.broadcastTxid), isNull);
    });

    test('a receiver that does not join leaves the Original to send, and its acceptance closes the session', () async {
      await initialize();
      sendInfo.setPayjoinUri('bitcoin:tb1qreceiver?pj=https://example.com/pj');
      final original = viewModel.signedTx!.transactionHash;

      final sentAsPayjoin = await viewModel.attemptPayjoin(
        sessions,
        _Attempt(const PayjoinSendFallsBack(sessionId, 'the receiver did not answer in time')),
        signProposal: (_) => throw StateError('there is no proposal to sign'),
      );

      expect(sentAsPayjoin, isFalse);
      expect(viewModel.signedTx!.transactionHash, original);
      expect(isOpen(), isTrue);
      expect((await viewModel.broadcast(inheritedTagIds: const []))!.isSuccess, isTrue);
      expect(isOpen(), isFalse);
      expect(sessions.readValue(sessionId, PayjoinSendValues.broadcastTxid), original);
    });

    test('an attempt that fails sends the Original', () async {
      await initialize();
      sendInfo.setPayjoinUri('bitcoin:tb1qreceiver?pj=https://example.com/pj');
      final original = viewModel.signedTx!.transactionHash;

      final sentAsPayjoin = await viewModel.attemptPayjoin(
        sessions,
        _Attempt(null),
        signProposal: (_) => throw StateError('there is no proposal to sign'),
      );

      expect(sentAsPayjoin, isFalse);
      expect(viewModel.signedTx!.transactionHash, original);
    });

    test('closes when an unanswered broadcast turns out to have reached the node', () async {
      node.broadcastErrors.add(ErrorCodes.nodeIsolateError);
      node.transactionFound = true;
      await initialize();
      viewModel.settlePayjoinSessionOnAccept(sessions, sessionId);

      expect((await viewModel.broadcast(inheritedTagIds: const []))!.isSuccess, isTrue);

      expect(isOpen(), isFalse);
    });
  });

  test('a node rejection is reported as is without checking or resending', () async {
    node.broadcastErrors.add(ErrorCodes.broadcastError);
    await initialize();

    final result = await viewModel.broadcast(inheritedTagIds: const []);

    expect(result!.error.code, ErrorCodes.broadcastError.code);
    expect(node.lookups, 0);
    expect(viewModel.isBroadcastResultUnknown, isFalse);
    expect(node.broadcasts, 1);
  });

  testWidgets('a confirmation that ran past the limit never resends afterwards', (tester) async {
    node.broadcastErrors.add(ErrorCodes.nodeIsolateError);
    node.lookingUp = Completer<void>();
    await tester.runAsync(() => initialize());

    Result<String>? result;
    viewModel.broadcast(inheritedTagIds: const []).then((value) => result = value);
    await tester.pump(const Duration(seconds: 15));
    expect(viewModel.isBroadcastResultUnknown, isTrue);
    node.lookingUp!.complete();
    await tester.pump(const Duration(seconds: 1));

    expect(result, isNotNull);
    expect(node.lookups, 1);
    expect(node.broadcasts, 1);
  });

  testWidgets('a resend that succeeds after the limit still finishes inputs, tags and drafts', (tester) async {
    addTag('savings', inputId);
    node.broadcastErrors.addAll([ErrorCodes.nodeIsolateError, null]);
    node.resending = Completer<void>();
    await tester.runAsync(() => initialize());
    final drafts = TransactionDraftRepository(manager);
    final draft = await tester.runAsync(
      () => drafts.saveUnsignedDraft(
        walletId: 1,
        feeRate: 1,
        isMaxMode: false,
        isFeeSubtractedFromSendAmount: false,
        recipients: [RecipientDraft(address: vault.getAddress(10), amount: 1000000)],
        bitcoinUnit: BitcoinUnit.btc,
      ),
    );
    sendInfo.setUnsignedDraftId(draft!.value.id);

    viewModel.broadcast(inheritedTagIds: ['savings']).ignore();
    await tester.pump(const Duration(seconds: 15));
    expect(viewModel.isBroadcastResultUnknown, isTrue);
    expect(node.broadcasts, 2);
    viewModel.dispose();
    sendInfo.clear();
    node.resending!.complete();
    for (var i = 0; i < 40 && drafts.getAllUnsignedDrafts().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    }

    expect(repository.getUtxoState(1, inputId)!.status, UtxoStatus.outgoing);
    expect(tagIds(targetId()), ['savings']);
    expect(drafts.getAllUnsignedDrafts(), isEmpty);
  });

  Future<void> prepareSignedDraftSave() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    sendInfo
      ..setTransaction(viewModel.signedTx!)
      ..setFeeRate(1)
      ..setIsMaxMode(false);
  }

  int signedDraftCount() => manager.realm.all<RealmTransactionDraft>().length;

  for (final saveFirst in [true, false]) {
    testWidgets(
      'a draft saved after the result was unknown is removed once the late success lands (saveFirst=$saveFirst)',
      (tester) async {
        node.broadcastErrors.addAll([ErrorCodes.nodeIsolateError, null]);
        node.resending = Completer<void>();
        await tester.runAsync(() => initialize());
        await prepareSignedDraftSave();

        viewModel.broadcast(inheritedTagIds: const []).ignore();
        await tester.pump(const Duration(seconds: 15));
        expect(viewModel.isBroadcastResultUnknown, isTrue);

        Future<void> settle() async {
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 50));
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          }
        }

        if (saveFirst) {
          expect((await tester.runAsync(viewModel.saveTransactionDraft))!.isSuccess, isTrue);
          expect(signedDraftCount(), 1);
          node.resending!.complete();
          await settle();
        } else {
          node.resending!.complete();
          await settle();
          expect(repository.getUtxoState(1, inputId)!.status, UtxoStatus.outgoing);
          expect((await tester.runAsync(viewModel.saveTransactionDraft))!.isSuccess, isTrue);
          await settle();
        }

        expect(signedDraftCount(), 0);
      },
    );
  }

  testWidgets('checking an unanswered broadcast gives up after 15 seconds', (tester) async {
    node.broadcastErrors.add(ErrorCodes.nodeIsolateError);
    node.lookingUp = Completer<void>();
    await tester.runAsync(() => initialize());

    Result<String>? result;
    viewModel.broadcast(inheritedTagIds: const []).then((value) => result = value);
    await tester.pump(const Duration(seconds: 14));
    expect(result, isNull);
    expect(viewModel.isBroadcastDispatched, isTrue);
    await tester.pump(const Duration(seconds: 1));

    expect(
      BroadcastingViewModel.broadcastFailureMessage(result!.error.message),
      t.broadcasting_screen.dialog.result_unknown,
    );
    expect(node.broadcasts, 1);
  });

  test('failed broadcast leaves the input spendable', () async {
    node.fails = true;
    await initialize();

    await viewModel.broadcast(inheritedTagIds: const []);

    expect(repository.getUtxoState(1, inputId)!.status, UtxoStatus.unspent);
  });

  test('a normal send whose input is already outgoing is reported before broadcasting', () async {
    manager.realm.write(() {
      final input = manager.realm.find<RealmUtxo>(realmInputId)!;
      input.status = 'outgoing';
      input.spentByTransactionHash = _previousHash;
    });

    await initialize(expectedExcludedStatus: SelectedUtxoExcludedStatus.used);
  });

  test('RBF keeps the predecessor as the spender of an already outgoing input', () async {
    manager.realm.write(() {
      final input = manager.realm.find<RealmUtxo>(realmInputId)!;
      input.status = 'outgoing';
      input.spentByTransactionHash = _previousHash;
    });
    transactions.previous = TransactionMock.createUnconfirmedTransactionRecord(transactionHash: _previousHash);
    await initialize(feeBumpingType: FeeBumpingType.rbf);

    await viewModel.broadcast(inheritedTagIds: const []);

    expect(repository.getUtxoState(1, inputId)!.spentByTransactionHash, _previousHash);
  });

  test('RBF inherits predecessor output tags before its output UTXO is synchronized', () async {
    final previousOutput = getUtxoId(_previousHash, 1);
    addTag('savings', previousOutput);
    manager.realm.write(() {
      final input = manager.realm.find<RealmUtxo>(realmInputId)!;
      input.status = 'outgoing';
      input.spentByTransactionHash = _previousHash;
    });
    transactions.previous = TransactionMock.createUnconfirmedTransactionRecord(transactionHash: _previousHash);
    expect(repository.getUtxoState(1, previousOutput), isNull);
    await initialize(feeBumpingType: FeeBumpingType.rbf);
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), ['savings']);
    await viewModel.broadcast(inheritedTagIds: ['savings']);
    expect(tagIds(targetId()), ['savings']);
    expect(tagIds(previousOutput), isEmpty);
    expect(node.broadcasts, 1);
  });

  test('confirmed predecessor output tags are not candidates for another transaction', () async {
    addTag('savings', getUtxoId(_previousHash, 1));
    manager.realm.write(() {
      final input = manager.realm.find<RealmUtxo>(realmInputId)!;
      input.status = 'outgoing';
      input.spentByTransactionHash = _previousHash;
    });
    transactions.previous = TransactionMock.createConfirmedTransactionRecord(transactionHash: _previousHash);
    await initialize(feeBumpingType: FeeBumpingType.rbf);
    expect(viewModel.prepareTagInheritance(), isEmpty);
  });

  test('second RBF unions immediate predecessor tags with extra input tags onto every own output', () async {
    addTag('savings', inputId);
    await initialize();
    await viewModel.broadcast(inheritedTagIds: ['savings']);
    final originalHash = viewModel.signedTx!.transactionHash;
    manager.realm.write(() {
      final input = manager.realm.find<RealmUtxo>(realmInputId)!;
      input.status = 'outgoing';
      input.spentByTransactionHash = originalHash;
    });
    transactions.previous = TransactionMock.createUnconfirmedTransactionRecord(transactionHash: originalHash);

    await initialize(outputAmount: 998000, feeBumpingType: FeeBumpingType.rbf);
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), ['savings']);
    await viewModel.broadcast(inheritedTagIds: ['savings']);
    final firstBumpHash = viewModel.signedTx!.transactionHash;
    final firstBumpOutput = getUtxoId(firstBumpHash, 0);
    addTag('reviewed', firstBumpOutput);
    const extraHash = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    final extraInputId = getUtxoId(extraHash, 3);
    addTag('salary', extraInputId);
    manager.realm.write(() {
      manager.realm.find<RealmUtxo>(realmInputId)!.spentByTransactionHash = firstBumpHash;
      manager.realm.add(
        UtxoMock.createUnspentRealmUtxo(
          walletId: 1,
          address: vault.getAddress(1),
          amount: 300000,
          transactionHash: extraHash,
          index: 3,
          addressIndex: 1,
        ),
      );
    });
    transactions.previous = TransactionMock.createUnconfirmedTransactionRecord(transactionHash: firstBumpHash);
    wallets.ownedAddresses.add(vault.getAddress(2));
    final secondBump = Transaction.withInputsAndOutputs(
      [
        TransactionInput.forPayment(_inputHash, 0, sequence: 0xfffffffd),
        TransactionInput.forPayment(extraHash, 3, sequence: 0xfffffffd),
      ],
      [
        TransactionOutput.forPayment(400000, vault.getAddress(10)),
        TransactionOutput.forPayment(400000, vault.getAddress(2)),
        TransactionOutput.forPayment(
          497000,
          vault.getAddress(1, isChange: true),
          derivationPath: "${vault.derivationPath}/1/1",
          isChangeOutput: true,
        ),
      ],
      AddressType.p2wpkh,
    );
    secondBump.utxoList.addAll([
      Utxo(_inputHash, 0, 1000000, "${vault.derivationPath}/0/0"),
      Utxo(extraHash, 3, 300000, "${vault.derivationPath}/0/1"),
    ]);
    await initializeTransaction(secondBump, feeBumpingType: FeeBumpingType.rbf);
    const expectedTags = ['savings', 'reviewed', 'salary'];
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), unorderedEquals(expectedTags));
    expect((await viewModel.broadcast(inheritedTagIds: expectedTags))!.isSuccess, isTrue);
    final secondBumpHash = viewModel.signedTx!.transactionHash;
    expect(tagIds(getUtxoId(secondBumpHash, 0)), isEmpty);
    for (final index in [1, 2]) {
      expect(tagIds(getUtxoId(secondBumpHash, index)), unorderedEquals(expectedTags));
    }
    for (final source in [inputId, extraInputId, getUtxoId(originalHash, 0), firstBumpOutput]) {
      expect(tagIds(source), isEmpty);
    }
    expect(node.broadcasts, 3);
  });

  test('CPFP inherits the spent incoming output tags while preserving a sibling output', () async {
    addTag('incoming', inputId);
    final siblingId = getUtxoId(_inputHash, 1);
    addTag('sibling', siblingId);
    manager.realm.write(() {
      final input = manager.realm.find<RealmUtxo>(realmInputId)!;
      input.status = 'incoming';
      input.blockHeight = 0;
    });
    await initialize();
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), ['incoming']);
    await viewModel.broadcast(inheritedTagIds: ['incoming']);
    expect(tagIds(targetId()), ['incoming']);
    expect(tagIds(inputId), isEmpty);
    expect(tagIds(siblingId), ['sibling']);
    expect(node.broadcasts, 1);
  });

  test('full send has no consent candidates and removes source links only after success', () async {
    addTag('savings', inputId);
    await initialize(ownOutput: false);
    expect(viewModel.prepareTagInheritance(), isEmpty);
    expect(tagIds(inputId), ['savings']);
    await viewModel.broadcast(inheritedTagIds: []);
    expect(tagIds(inputId), isEmpty);
    expect(tagIds(targetId()), isEmpty);
  });

  test('declining inheritance keeps tag definitions but clears consumed associations', () async {
    addTag('savings', inputId);
    await initialize();
    viewModel.prepareTagInheritance();
    await viewModel.broadcast(inheritedTagIds: []);
    expect(tagIds(inputId), isEmpty);
    expect(tagIds(targetId()), isEmpty);
    expect(repository.getUtxoTags(1).value.map((tag) => tag.id), ['savings']);
  });

  test('unknown or more than five selected tags are rejected before network broadcast', () async {
    for (var i = 0; i < 6; i++) {
      addTag('tag$i', inputId);
    }
    await initialize();
    final candidates = viewModel.prepareTagInheritance().map((tag) => tag.id).toList();
    expect(candidates, hasLength(6));
    await expectLater(viewModel.broadcast(inheritedTagIds: ['unknown']), throwsArgumentError);
    await expectLater(viewModel.broadcast(inheritedTagIds: candidates), throwsArgumentError);
    expect(node.broadcasts, 0);
    expect(tagIds(inputId), hasLength(6));

    await viewModel.broadcast(inheritedTagIds: candidates.take(5).toList());
    expect(tagIds(targetId()), unorderedEquals(candidates.take(5)));
    expect(tagIds(inputId), isEmpty);
  });

  test('tag persistence failure after node acceptance never reports transaction failure', () async {
    addTag('savings', inputId);
    await initialize();
    viewModel.prepareTagInheritance();
    node.duringBroadcast = () {
      manager.realm.write(() => manager.realm.delete(manager.realm.find<RealmUtxoTag>('savings')!));
    };
    expect((await viewModel.broadcast(inheritedTagIds: ['savings']))!.isSuccess, isTrue);
    expect(viewModel.tagInheritanceFailed, isTrue);
    expect(node.broadcasts, 1);
  });
}
