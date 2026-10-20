import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/broadcasting_view_model.dart';
import 'package:coconut_wallet/providers/view_model/send/send_confirm_view_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/safety_store.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/security/hot_wallet_signing_service.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../mock/utxo_mock.dart';
import '../repository/realm/test_realm_manager.dart';
import '../services/safety/safety_fakes.dart';

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
  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async => Result.success(BlockTimestamp(100, DateTime(2026)));
  @override
  Future<Result<String>> broadcast(Transaction signedTx) async {
    broadcasts++;
    recordedBeforeBroadcast = SafetyStore(SharedPrefsRepository()).load().isAppCreated(signedTx.transactionHash);
    return failBroadcast ? Result.failure(ErrorCodes.broadcastError) : Result.success(signedTx.transactionHash);
  }
}

class _Transactions extends Fake implements TransactionProvider {}

// Keep native Realm I/O outside the fake clock used to verify the broadcast deadline.
class _ImmediateTagUtxos extends UtxoRepository {
  _ImmediateTagUtxos(super.realm);

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
    transaction.utxoList.add(Utxo(inputHash, 0, 1000000, '${vault.derivationPath}/0/0'));
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

  Future<BroadcastingViewModel> broadcasting({UtxoRepository? repository}) async {
    final psbt = Psbt.fromTransaction(transaction, vault);
    final signed = Psbt.parse(vault.addSignatureToPsbt(psbt.serialize())).getSignedTransaction(AddressType.p2wpkh);
    send
      ..setTxWaitingForSign(psbt.serialize())
      ..setSignedResult(signed.serialize());
    final model = BroadcastingViewModel(
      send,
      wallets,
      tags,
      true,
      node,
      _Transactions(),
      TransactionDraftRepository(realm),
      repository ?? utxos,
      null,
    );
    addTearDown(model.dispose);
    await model.setTxInfo();
    return model;
  }

  test('records signed hash before network call and success after broadcast', () async {
    final model = await broadcasting();
    final result = await model.broadcast(inheritedTagIds: []);
    await Future<void>.delayed(Duration.zero);
    expect(result.isSuccess, isTrue);
    expect(node.recordedBeforeBroadcast, isTrue);
    expect(store.load().appTxidPrefixes, {SafetyState.txidPrefix(model.signedTx!.transactionHash)});
    expect(store.load().lastBroadcast!.txid, model.signedTx!.transactionHash);
  });
  test('recording write failure never blocks or changes broadcast result', () async {
    final model = await broadcasting();
    disk.fails = true;
    final result = await model.broadcast(inheritedTagIds: []);
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
      final result = await broadcast;
      expect(result.isSuccess, isTrue);
      expect(node.recordedBeforeBroadcast, isTrue);
      expect(result.value, model.signedTx!.transactionHash);
      expect(store.load().lastBroadcast!.txid, result.value);
      expect(disk.writes, 2);
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
  test('network failure keeps pre-record and does not write a success marker', () async {
    final model = await broadcasting();
    node.failBroadcast = true;
    expect((await model.broadcast(inheritedTagIds: [])).isFailure, isTrue);
    expect(store.load().appTxidPrefixes, {SafetyState.txidPrefix(model.signedTx!.transactionHash)});
    expect(store.load().lastBroadcast, isNull);
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
