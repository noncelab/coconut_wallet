import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/broadcasting_view_model.dart';
import 'package:coconut_wallet/providers/view_model/send/send_confirm_view_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/safety_store.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/security/hot_wallet_signing_service.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:coconut_wallet/screens/safety/security_guide_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../mock/utxo_mock.dart';
import '../mock/transaction_mock.dart';
import '../repository/realm/test_realm_manager.dart';
import '../services/safety/safety_fakes.dart';
import '../screens/safety/safety_test_harness.dart' as guide;

class _Disk extends InMemorySharedPreferencesStore {
  _Disk() : super.withData({});
  bool fails = false;
  bool stalls = false;
  int writes = 0;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    writes++;
    if (fails) throw StateError('disk unavailable');
    if (stalls) return Completer<bool>().future;
    return super.setValue(valueType, key, value);
  }
}

class _Node extends SafetyNodeFake {
  bool failBroadcast = false;
  int broadcasts = 0;
  bool recordedBeforeBroadcast = false;
  final broadcastHashes = <String>[];
  final recordingChecks = <bool>[];
  final broadcastErrors = <AppError?>[];
  Completer<void>? resending;
  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async => Result.success(BlockTimestamp(100, DateTime(2026)));
  @override
  Future<Result<String>> broadcast(Transaction signedTx) async {
    broadcasts++;
    broadcastHashes.add(signedTx.transactionHash);
    recordedBeforeBroadcast = SafetyStore(SharedPrefsRepository()).load().isAppCreated(signedTx.transactionHash);
    recordingChecks.add(recordedBeforeBroadcast);
    if (broadcasts > 1) await resending?.future;
    if (broadcastErrors.isNotEmpty) {
      final error = broadcastErrors.removeAt(0);
      return error == null ? Result.success(signedTx.transactionHash) : Result.failure(error);
    }
    return failBroadcast ? Result.failure(ErrorCodes.broadcastError) : Result.success(signedTx.transactionHash);
  }

  @override
  Future<Result<String>> getTransaction(String txHash) async => Result.failure(ErrorCodes.nodeUnknown);
}

class _Transactions extends Fake implements TransactionProvider {}

// Keep native Realm I/O outside the fake clock used to verify the broadcast deadline.
class _ImmediateTagUtxos extends UtxoRepository {
  _ImmediateTagUtxos(super.realm);

  @override
  Future<void> markUnspentInputsAsOutgoing(int walletId, Transaction transaction) async {}

  @override
  Future<Result<void>> applyInheritedTags(
    int walletId, {
    required List<String> sourceUtxoIds,
    required List<String> targetUtxoIds,
    required List<String> tagIds,
  }) async => Result.success(null);
}

class _Signer extends Fake implements HotWalletSigningService {
  _Signer(this.vault);
  final SingleSignatureVault vault;
  int calls = 0;
  @override
  Future<String> sign(HotWalletSigningRequest request) async {
    calls++;
    return vault.addSignatureToPsbt(request.unsignedPsbt);
  }
}

void main() {
  // 앱 전체가 함께 쓰는 Safety 메모리와 쓰기 줄을 테스트마다 비운다
  tearDown(SafetyStore.resetForTest);
  TestWidgetsFlutterBinding.ensureInitialized();
  const inputHash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  late _Disk disk;
  late TestRealmManager realm;
  late SingleSignatureVault vault;
  late SafetyWalletsFake wallets;
  late SendInfoProvider send;
  late Transaction transaction;
  late _Node node;
  late UtxoRepository utxos;
  late UtxoTagProvider tags;
  late SafetyStore store;
  setUp(() async {
    NetworkType.setNetworkType(NetworkType.testnet);
    SharedPreferences.setMockInitialValues({});
    disk = _Disk();
    SharedPreferencesStorePlatform.instance = disk;
    await SharedPrefsRepository().init();
    store = SafetyStore(SharedPrefsRepository());
    realm = TestRealmManager();
    vault = SingleSignatureVault.fromEntropy(Uint8List(16));
    wallets = SafetyWalletsFake([safetyWallet(hot: true)]);
    node = _Node();
    utxos = UtxoRepository(realm);
    tags = UtxoTagProvider(utxos);
    realm.realm.write(
      () => realm.realm.add(
        UtxoMock.createUnspentRealmUtxo(walletId: 1, address: vault.getAddress(0), transactionHash: inputHash),
      ),
    );
    transaction = Transaction.withInputsAndOutputs(
      [TransactionInput.forPayment(inputHash, 0)],
      [TransactionOutput.forPayment(999000, vault.getAddress(5))],
      AddressType.p2wpkh,
    );
    // develop 335fdf6f3부터 PSBT를 만들기 전에 UTXO가 지갑 주소인지 확인하므로, 주소를 가진 UtxoState로 넣는다
    transaction.utxoList.add(
      UtxoState(
        transactionHash: inputHash,
        index: 0,
        amount: 1000000,
        derivationPath: '${vault.derivationPath}/0/0',
        blockHeight: 1,
        to: vault.getAddress(0),
        timestamp: DateTime(2026),
      ),
    );
    send =
        SendInfoProvider()
          ..setWalletId(1)
          ..setTransaction(transaction);
  });
  tearDown(() {
    tags.dispose();
    node.dispose();
    wallets.dispose();
    realm.dispose();
  });

  Future<BroadcastingViewModel> broadcasting({
    UtxoRepository? repository,
    int? draftId,
    TransactionProvider? transactions,
  }) async {
    if (draftId == null) {
      final psbt = Psbt.fromTransaction(transaction, vault);
      final signed = Psbt.parse(vault.addSignatureToPsbt(psbt.serialize())).getSignedTransaction(AddressType.p2wpkh);
      send
        ..setTxWaitingForSign(psbt.serialize())
        ..setSignedResult(signed.serialize());
    }
    final model = BroadcastingViewModel(
      send,
      wallets,
      tags,
      true,
      node,
      transactions ?? _Transactions(),
      TransactionDraftRepository(realm),
      repository ?? utxos,
      draftId,
    );
    addTearDown(model.dispose);
    await model.setTxInfo();
    return model;
  }

  test('records signed hash before network call and success after broadcast', () async {
    final model = await broadcasting();
    final result = (await model.broadcast(inheritedTagIds: []))!;
    await Future<void>.delayed(Duration.zero);
    expect(result.isSuccess, isTrue);
    expect(node.recordedBeforeBroadcast, isTrue);
    expect(store.load().appTxidPrefixes, {SafetyState.txidPrefix(model.signedTx!.transactionHash)});
    expect(store.load().lastBroadcast!.txid, model.signedTx!.transactionHash);
  });
  Future<void> seedIncidents() => store
      .update(
        (s) => s.copyWith(
          incidents: [
            SafetyIncident(
              walletId: 1,
              txid: 'incident',
              detectedAt: DateTime(2026),
            ).respond(IncidentResponseMode.premium),
            SafetyIncident(
              walletId: 1,
              txid: 'other-incident',
              detectedAt: DateTime(2026),
            ).respond(IncidentResponseMode.premium),
            SafetyIncident(
              walletId: 2,
              txid: 'incident',
              detectedAt: DateTime(2026),
            ).respond(IncidentResponseMode.premium),
          ],
        ),
      )
      .then((_) {});

  testWidgets('M02 draft: save, fresh send session, broadcast, then resume and finish the real guide', (tester) async {
    guide.usePhoneSize(tester);
    final sent =
        (await tester.runAsync(() async {
          FlutterSecureStorage.setMockInitialValues({});
          wallets.walletItemListNotifier.value = [safetyWallet()]; // The supported non-local-key draft path.
          final recovery = SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, 1)));
          final inputs = transaction.utxoList.toList();
          transaction = Transaction.withInputsAndOutputs(
            [TransactionInput.forPayment(inputHash, 0)],
            [TransactionOutput.forPayment(999000, recovery.getAddress(0))],
            AddressType.p2wpkh,
          )..utxoList.addAll(inputs);
          await seedIncidents();
          await store.update(
            (s) => s.copyWith(
              incidents: [s.incidents.first.withGuideStep(2, assistStartedAt: DateTime(2026)), ...s.incidents.skip(1)],
            ),
          );
          send
            ..setTransaction(transaction)
            ..setSafetyIncidentId('1:incident')
            ..setFeeRate(10)
            ..setIsMaxMode(true);
          final first = await broadcasting();
          expect(first.canUseTransactionDrafts, isTrue);
          expect(first.feeBumpingType, isNull);
          final expected = first.signedTx!.transactionHash;
          final saved = await first.saveTransactionDraft();
          expect(saved.isSuccess, isTrue);
          expect(node.broadcasts, 0);
          expect(store.load().incidents.first.responseTxid, isNull);
          expect(store.load().draftResponseIncidents, {expected: '1:incident'});
          first.dispose();
          send = SendInfoProvider();
          final resumed = await broadcasting(draftId: saved.value.id);
          expect(resumed.signedTx!.transactionHash, expected);
          expect(send.safetyIncidentId, isNull);
          expect((await resumed.broadcast(inheritedTagIds: []))!.isSuccess, isTrue);
          final state = SafetyStore(SharedPrefsRepository()).load();
          expect(state.lastBroadcast!.txid, expected);
          expect(state.isAppCreated(expected), isTrue);
          expect(state.draftResponseIncidents, isEmpty);
          return (state: state, txid: expected);
        }))!;
    final safety = SafetyProvider.fixed(null, state: sent.state);
    addTearDown(safety.dispose);
    await tester.pumpWidget(guide.safetyTestApp(guide.origin(), safety: safety));
    unawaited(SecurityGuide.resume(guide.originContext(tester), '1:incident'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-guide-submitted')), findsOneWidget);
    expect(safety.incidentFor(1, 'incident')!.responseTxid, sent.txid);
    expect(safety.incidentFor(1, 'incident')!.guideStep, 3);
    for (final text in [
      t.safety_guide.continue_review,
      t.safety_guide.step3.mark,
      t.safety_guide.next_step,
      t.safety_guide.step4.complete,
    ]) {
      await guide.tapVisible(tester, guide.findText(text));
    }
    expect(find.byKey(const Key('safety-guide-done')), findsOneWidget);
    expect(guide.findText(t.safety_guide.complete.sent), findsOneWidget);
    expect(guide.findText(t.safety_guide.complete.none), findsNothing);
  });

  for (final incidentId in [null, '2:incident', '1:missing']) {
    test('M02 draft: restore ignores an absent or mismatched incident link ($incidentId)', () async {
      FlutterSecureStorage.setMockInitialValues({});
      wallets.walletItemListNotifier.value = [safetyWallet()];
      await seedIncidents();
      send
        ..setSafetyIncidentId(incidentId)
        ..setFeeRate(10)
        ..setIsMaxMode(true);
      final original = await broadcasting();
      final saved = await original.saveTransactionDraft();
      expect(saved.isSuccess, isTrue);
      expect(store.load().toJson()['draftResponseIncidents'], isEmpty);
      original.dispose();
      send = SendInfoProvider()..setSafetyIncidentId('1:other-incident');
      final resumed = await broadcasting(draftId: saved.value.id);
      expect(send.safetyIncidentId, isNull);
      expect((await resumed.broadcast(inheritedTagIds: []))!.isSuccess, isTrue);
      expect(store.load().incidents.map((i) => i.id), ['1:incident', '1:other-incident', '2:incident']);
      expect(store.load().incidents.every((i) => i.responseTxid == null), isTrue);
    });
  }

  for (final saveAfterAccepted in [false, true]) {
    test('M02 response map: retry and late draft save never leave a consumed link ($saveAfterAccepted)', () async {
      FlutterSecureStorage.setMockInitialValues({});
      wallets.walletItemListNotifier.value = [safetyWallet()];
      await seedIncidents();
      send
        ..setSafetyIncidentId('1:incident')
        ..setFeeRate(10)
        ..setIsMaxMode(true);
      final model = await broadcasting();
      final txid = model.signedTx!.transactionHash;
      if (!saveAfterAccepted) {
        expect((await model.saveTransactionDraft()).isSuccess, isTrue);
        expect(store.load().toJson()['draftResponseIncidents'], {txid: '1:incident'});
        node.failBroadcast = true;
        expect((await model.broadcast(inheritedTagIds: []))!.isFailure, isTrue);
        expect(store.load().incidents.first.responseTxid, isNull);
        expect(store.load().toJson()['draftResponseIncidents'], {txid: '1:incident'});
        node.failBroadcast = false;
      }
      expect((await model.broadcast(inheritedTagIds: []))!.isSuccess, isTrue);
      if (saveAfterAccepted) expect((await model.saveTransactionDraft()).isSuccess, isTrue);
      expect(store.load().incidents.first.responseTxid, txid);
      expect(store.load().toJson()['draftResponseIncidents'], isEmpty);
    });
  }

  test('successful Assist broadcast persists its response on exactly the originating incident', () async {
    await seedIncidents();
    send.setSafetyIncidentId('1:incident');
    final model = await broadcasting();
    // The broadcast owns its context even if navigation clears/reuses the shared send provider.
    send.clear();
    send.setSafetyIncidentId('1:other-incident');
    expect((await model.broadcast(inheritedTagIds: []))!.isSuccess, isTrue);
    final incidents = SafetyStore(SharedPrefsRepository()).load().incidents;
    expect(incidents.map((i) => i.id), ['1:incident', '1:other-incident', '2:incident']);
    expect(incidents[0].responseTxid, model.signedTx!.transactionHash);
    expect(incidents.skip(1).every((i) => i.responseTxid == null), isTrue);
    expect(incidents.every((i) => i.state == IncidentState.responding), isTrue);
  });

  for (final scenario in ['rbf', 'rbf rejected', 'rbf unrelated', 'cpfp', 'ordinary', 'confirmed conflict']) {
    test('M02 N1: $scenario updates only an accepted replacement of the exact response', () async {
      final previousHash = scenario == 'cpfp' ? inputHash : 'b' * 64;
      final responseHash = scenario == 'rbf unrelated' ? 'c' * 64 : previousHash;
      await seedIncidents();
      await store.update(
        (s) => s.copyWith(
          incidents: [
            s.incidents[0].withResponseTxid(responseHash),
            s.incidents[1],
            s.incidents[2].withResponseTxid(responseHash),
          ],
        ),
      );
      final repository = TransactionRepository(realm);
      realm.realm.write(() => realm.realm.add(RealmWalletBase(1, 0, 0, vault.descriptor, 'Test', 'singleSignature')));
      await repository.addAllTransactions(1, [
        TransactionMock.createMockTransactionRecord(
          transactionHash: previousHash,
          blockHeight: scenario == 'confirmed conflict' ? 100 : 0,
        ),
      ]);
      final transactions = TransactionProvider(repository);
      addTearDown(transactions.dispose);
      if (scenario != 'ordinary' && scenario != 'cpfp') {
        realm.realm.write(() {
          final input = realm.realm.find<RealmUtxo>(getRealmUtxoId(1, inputHash, 0))!;
          input.status = 'outgoing';
          input.spentByTransactionHash = previousHash;
        });
      }
      send.setFeeBumpingType(
        scenario == 'ordinary'
            ? null
            : scenario == 'cpfp'
            ? FeeBumpingType.cpfp
            : FeeBumpingType.rbf,
      );
      node.failBroadcast = scenario == 'rbf rejected';
      final model = await broadcasting(transactions: transactions);
      expect(send.safetyIncidentId, isNull);
      expect(store.load().incidents.first.responseTxid, responseHash);
      final result = (await model.broadcast(inheritedTagIds: []))!;
      expect(result.isSuccess, scenario != 'rbf rejected');
      final incidents = SafetyStore(SharedPrefsRepository()).load().incidents;
      expect(incidents.map((i) => i.id), ['1:incident', '1:other-incident', '2:incident']);
      expect(incidents[0].responseTxid, scenario == 'rbf' ? model.signedTx!.transactionHash : responseHash);
      expect(incidents[1].responseTxid, isNull);
      expect(incidents[2].responseTxid, responseHash);
      expect(incidents.every((i) => i.state == IncidentState.responding), isTrue);
    });
  }

  for (final context in ['ordinary', 'cleared', 'wrong-wallet', 'missing-incident']) {
    test('successful $context broadcast never creates a response association', () async {
      await seedIncidents();
      if (context == 'cleared') {
        send.setSafetyIncidentId('1:incident');
        send.clear();
        send.setWalletId(1);
        send.setTransaction(transaction);
      } else if (context != 'ordinary') {
        send.setSafetyIncidentId(context == 'wrong-wallet' ? '2:incident' : '1:missing');
      }
      final model = await broadcasting();
      expect((await model.broadcast(inheritedTagIds: []))!.isSuccess, isTrue);
      expect(store.load().incidents.map((i) => i.id), ['1:incident', '1:other-incident', '2:incident']);
      expect(store.load().incidents.every((i) => i.responseTxid == null), isTrue);
    });
  }

  test('recording write failure never blocks or changes broadcast result', () async {
    final model = await broadcasting();
    disk.fails = true;
    final result = (await model.broadcast(inheritedTagIds: []))!;
    await Future<void>.delayed(Duration.zero);
    expect(result.isSuccess, isTrue);
    expect(node.broadcasts, 1);
    expect(result.value, model.signedTx!.transactionHash);
    expect(disk.writes, 2);
  });
  testWidgets(
    'stalled platform writes delay broadcast by at most 500 ms with the same recorded hash',
    (tester) async {
      final model = await broadcasting(repository: _ImmediateTagUtxos(realm));
      disk.stalls = true;
      final broadcast = model.broadcast(inheritedTagIds: []);
      await tester.pump();
      expect(disk.writes, 1);
      expect(store.load().appTxidPrefixes, {SafetyState.txidPrefix(model.signedTx!.transactionHash)});
      await tester.pump(const Duration(milliseconds: 499));
      expect(node.broadcasts, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(node.broadcasts, 1);
      final result = (await broadcast)!;
      expect(result.isSuccess, isTrue);
      expect(node.recordedBeforeBroadcast, isTrue);
      expect(result.value, model.signedTx!.transactionHash);
      expect(store.load().lastBroadcast!.txid, result.value);
      // 쓰기는 차례대로라 전송 기록은 멈춘 쓰기 뒤에서 기다린다(메모리에는 이미 있다, M08)
      expect(disk.writes, 1);
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
  test('network failure keeps pre-record and does not write a success marker', () async {
    await seedIncidents();
    send.setSafetyIncidentId('1:incident');
    final model = await broadcasting();
    node.failBroadcast = true;
    expect((await model.broadcast(inheritedTagIds: []))!.isFailure, isTrue);
    expect(store.load().appTxidPrefixes, {SafetyState.txidPrefix(model.signedTx!.transactionHash)});
    expect(store.load().lastBroadcast, isNull);
    expect(store.load().incidents.every((i) => i.responseTxid == null), isTrue);
  });
  test('cancelled broadcast keeps pre-record without sending or writing a success marker', () async {
    await seedIncidents();
    send.setSafetyIncidentId('1:incident');
    disk.writes = 0;
    final model = await broadcasting();
    model.cancelPendingBroadcast();

    expect(await model.broadcast(inheritedTagIds: []), isNull);
    expect(node.broadcasts, 0);
    expect(model.isBroadcastDispatched, isFalse);
    expect(store.load().appTxidPrefixes, {SafetyState.txidPrefix(model.signedTx!.transactionHash)});
    expect(store.load().lastBroadcast, isNull);
    expect(store.load().incidents.every((i) => i.responseTxid == null), isTrue);
    expect(disk.writes, 1);
  });
  testWidgets('cancelling during a stalled safety write prevents dispatch after the disk deadline', (tester) async {
    final model = await broadcasting(repository: _ImmediateTagUtxos(realm));
    disk.stalls = true;
    final pending = model.broadcast(inheritedTagIds: []);
    await tester.pump();
    expect(disk.writes, 1);
    expect(node.broadcasts, 0);
    model.cancelPendingBroadcast();

    await tester.pump(const Duration(milliseconds: 500));

    expect(await pending, isNull);
    expect(node.broadcasts, 0);
    expect(model.isBroadcastDispatched, isFalse);
    expect(store.load().appTxidPrefixes, {SafetyState.txidPrefix(model.signedTx!.transactionHash)});
    expect(store.load().lastBroadcast, isNull);
    expect(store.load().incidents.every((i) => i.responseTxid == null), isTrue);
    expect(disk.writes, 1);
  });
  testWidgets('a retry accepted after the unknown-result deadline records the same hash exactly once', (tester) async {
    await seedIncidents();
    send.setSafetyIncidentId('1:incident');
    disk.writes = 0;
    final model = await broadcasting(repository: _ImmediateTagUtxos(realm));
    final txid = model.signedTx!.transactionHash;
    node.broadcastErrors.addAll([ErrorCodes.nodeIsolateError, null]);
    node.resending = Completer<void>();

    final pending = model.broadcast(inheritedTagIds: []);
    await tester.pump();
    expect(node.broadcastHashes, [txid, txid]);
    expect(node.recordingChecks, [true, true]);
    expect(store.load().lastBroadcast, isNull);
    expect(store.load().incidents.every((i) => i.responseTxid == null), isTrue);
    expect(disk.writes, 1);
    await tester.pump(const Duration(seconds: 15));

    final result = (await pending)!;
    expect(result.error.code, ErrorCodes.nodeIsolateError.code);
    expect(model.isBroadcastResultUnknown, isTrue);
    expect(model.isTransactionAccepted, isFalse);
    expect(store.load().lastBroadcast, isNull);
    expect(store.load().incidents.every((i) => i.responseTxid == null), isTrue);
    expect(store.load().appTxidPrefixes, {SafetyState.txidPrefix(txid)});
    expect(disk.writes, 1);

    model.dispose();
    send.clear();
    node.resending!.complete();
    await tester.pump();

    expect(model.isTransactionAccepted, isTrue);
    expect(store.load().lastBroadcast!.walletId, 1);
    expect(store.load().lastBroadcast!.txid, txid);
    expect(store.load().incidents.first.responseTxid, txid);
    expect(store.load().appTxidPrefixes, {SafetyState.txidPrefix(txid)});
    expect(disk.writes, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(disk.writes, 2);
    expect(node.broadcasts, 2);
  });
  test('PSBT signing handoff records the same hash as the signed transaction', () async {
    final model = SendConfirmViewModel(send, wallets);
    addTearDown(model.dispose);
    await model.setEstimatedFeeAndTotalUsedAmount();
    model.setTxWaitingForSign();
    await Future<void>.delayed(Duration.zero);
    final signed = Psbt.parse(
      vault.addSignatureToPsbt(send.txWaitingForSign!),
    ).getSignedTransaction(AddressType.p2wpkh);
    expect(store.load().appTxidPrefixes, {SafetyState.txidPrefix(signed.transactionHash)});
  });
  test('failed safety recording does not delay or prevent hot-wallet signing', () async {
    final signer = _Signer(vault);
    final model = SendConfirmViewModel(send, wallets, hotWalletSigningService: signer);
    addTearDown(model.dispose);
    await model.setEstimatedFeeAndTotalUsedAmount();
    disk.fails = true;
    await model.signHotWallet();
    await Future<void>.delayed(Duration.zero);
    expect(signer.calls, 1);
    expect(send.signedResult, isNotNull);
    final signed = Psbt.parse(send.signedResult!).getSignedTransaction(AddressType.p2wpkh);
    expect(store.load().appTxidPrefixes, {SafetyState.txidPrefix(signed.transactionHash)});
  });
}
