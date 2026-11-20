import 'dart:async';
import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/constants/realm_constants.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_draft.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/balance_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_manager.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/broadcasting_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realm/realm.dart' hide Transaction;

import '../../mock/script_status_mock.dart';
import '../../mock/transaction_mock.dart';
import 'utxo/utxo_sync_service_test.mocks.dart' show MockNodeStateManager;

class _ObservedUtxos extends UtxoRepository {
  String? observedAddress;
  Completer<void>? receivedSaved;
  _ObservedUtxos(super.manager);

  @override
  Future<Result<bool>> addAllUtxos(int walletId, List<UtxoState> values, {Map<String, int>? expectedVersions}) async {
    final result = await super.addAllUtxos(walletId, values, expectedVersions: expectedVersions);
    if (values.any((u) => u.to == observedAddress) && receivedSaved?.isCompleted == false) {
      receivedSaved!.complete();
    }
    return result;
  }
}

class _DiskRealm extends Fake implements RealmManager {
  final String path;
  late Realm _realm;
  _DiskRealm(this.path) {
    reopen();
  }
  void reopen() {
    _realm = Realm(Configuration.local(realmAllSchemas, path: path, schemaVersion: kRealmVersion));
  }

  @override
  Realm get realm => _realm;
  @override
  Set<int> get migratedWalletIds => {};
  @override
  void dispose() => _realm.close();
}

class _Wallets extends Fake implements WalletProvider {
  final WalletItemBase wallet;
  _Wallets(this.wallet);
  @override
  WalletItemBase getWalletById(int id) => wallet;
  @override
  bool containsAddress(int id, String address, {bool? isChange}) =>
      address == wallet.walletBase.getAddress(0) || address == wallet.walletBase.getAddress(0, isChange: true);
}

class _Transactions extends Fake implements TransactionProvider {
  final TransactionRepository repo;
  _Transactions(this.repo);
  @override
  TransactionRecord? getTransactionRecord(int walletId, String hash) => repo.getTransactionRecord(walletId, hash);
}

class _Node extends Fake implements NodeProvider {
  bool unknown = true;
  final submitted = <String>[];
  @override
  String get host => 'localhost';
  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async => Result.success(BlockTimestamp(200, DateTime(2026)));
  @override
  Future<bool> reconnectWithoutWaitingForSync() async => true;
  @override
  Future<Result<String>> getTransaction(String txHash) async => Result.failure(ErrorCodes.nodeUnknown);
  @override
  Future<Result<String>> broadcast(Transaction transaction) async {
    submitted.add(transaction.serialize());
    return unknown ? Result.failure(ErrorCodes.nodeIsolateError) : Result.success(transaction.transactionHash);
  }
}

class _Connectivity extends Fake implements ConnectivityProvider {
  bool online = false;
  @override
  bool get isInternetOn => online;
  @override
  bool get isInternetOff => !online;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

class _Isolate extends Fake implements IsolateManager {
  final SubscriptionService subscriptions;
  _Isolate(this.subscriptions);
  @override
  Future<Result<bool>> subscribeWallet(WalletItemBase wallet) => subscriptions.subscribeWallet(wallet);
  @override
  Future<Result<bool>> syncDormantAddresses(WalletItemBase wallet) async => Result.success(true);
  @override
  Future<void> closeIsolate() async {}
}

class _RefreshNode extends NodeProvider {
  _RefreshNode(_Connectivity connectivity, SubscriptionService subscriptions)
    : super(
        const ElectrumServer('localhost', 50001, false),
        NetworkType.testnet,
        connectivity,
        ValueNotifier(WalletLoadState.loadCompleted),
        ValueNotifier(<WalletItemBase>[]),
        null,
        isolateManager: _Isolate(subscriptions),
      );
  @override
  bool get isConnected => true;
}

class _Electrum extends Fake implements ElectrumService {
  final Transaction funding;
  final Transaction sent;
  final String receive;
  final String change;
  bool accepted = false;
  int sentHeight = 0;
  bool failUnspent = false;
  Completer<void>? receiveUnspentStarted;
  Completer<void>? holdNextReceiveUnspent;
  Completer<void>? sentReadStarted;
  Completer<void>? holdNextSentRead;
  Completer<void>? holdChangeUnspent;
  Transaction? unrelatedDeposit;
  Transaction? extraPending;
  Completer<void>? extraReadStarted;
  Completer<void>? allowExtraRead;
  bool acceptBeforeUnspent = false;
  int unspentCalls = 0;
  int historyCalls = 0;
  int balanceCalls = 0;
  _Electrum(this.funding, this.sent, this.receive, this.change);
  @override
  Future<List<GetTxHistoryRes>> getHistory(AddressType type, String address) async {
    historyCalls++;
    return [
      if (address == receive) GetTxHistoryRes(height: 100, txHash: funding.transactionHash),
      if (accepted && (address == receive || address == change))
        GetTxHistoryRes(height: sentHeight, txHash: sent.transactionHash),
      if (unrelatedDeposit != null && address == change)
        GetTxHistoryRes(height: 101, txHash: unrelatedDeposit!.transactionHash),
    ];
  }

  @override
  Future<GetBalanceRes> getBalance(AddressType type, String address) async {
    balanceCalls++;
    if (!accepted) {
      return GetBalanceRes(
        confirmed: address == receive ? 1000000 : (address == change ? unrelatedDeposit?.outputs.first.amount ?? 0 : 0),
        unconfirmed: 0,
      );
    }
    return GetBalanceRes(
      confirmed: address == change && sentHeight > 0 ? 599000 : 0,
      unconfirmed: address == change && sentHeight == 0 ? 599000 : 0,
    );
  }

  @override
  Future<List<ListUnspentRes>> getUnspentList(AddressType type, String address) async {
    unspentCalls++;
    if (address == change) await holdChangeUnspent?.future;
    if (acceptBeforeUnspent && address == receive) {
      acceptBeforeUnspent = false;
      accepted = true;
    }
    if (failUnspent) throw TimeoutException('synthetic lost listunspent response');
    final result = [
      if (!accepted && address == receive)
        ListUnspentRes(height: 100, txHash: funding.transactionHash, txPos: 0, value: 1000000),
      if (unrelatedDeposit != null && address == change)
        ListUnspentRes(
          height: 101,
          txHash: unrelatedDeposit!.transactionHash,
          txPos: 0,
          value: unrelatedDeposit!.outputs.first.amount,
        ),
      if (accepted && address == change)
        ListUnspentRes(height: sentHeight, txHash: sent.transactionHash, txPos: 1, value: 599000),
    ];
    final hold = holdNextReceiveUnspent;
    if (address == receive && hold != null) {
      holdNextReceiveUnspent = null;
      receiveUnspentStarted!.complete();
      await hold.future;
    }
    return result;
  }

  @override
  Future<String> getTransaction(String hash, {bool? verbose, Duration timeout = const Duration(seconds: 5)}) async {
    if (hash == extraPending?.transactionHash) {
      if (extraReadStarted?.isCompleted == false) extraReadStarted!.complete();
      await allowExtraRead?.future;
      return extraPending!.serialize();
    }
    if (hash == funding.transactionHash) return funding.serialize();
    if (hash == unrelatedDeposit?.transactionHash) return unrelatedDeposit!.serialize();
    if (accepted && hash == sent.transactionHash) {
      final hold = holdNextSentRead;
      if (hold != null) {
        holdNextSentRead = null;
        sentReadStarted!.complete();
        await hold.future;
      }
      return sent.serialize();
    }
    throw StateError('synthetic transaction absent');
  }

  @override
  Future<List<Transaction>> getPreviousTransactions(Transaction tx, {List<Transaction>? existingTxList}) async =>
      tx.transactionHash == sent.transactionHash ? [funding] : [];
  @override
  Future<String?> subscribeScriptForWallet(
    AddressType type,
    String address, {
    required int walletId,
    required Function(String, String?) onUpdate,
  }) async =>
      accepted && (address == receive || address == change)
          ? 'sent-$sentHeight'
          : address == receive
          ? 'funding-history-unchanged'
          : (address == change && unrelatedDeposit != null ? 'new-deposit' : null);
  @override
  Future<bool> unsubscribeScriptForWallet(AddressType type, String address, {required int walletId}) async => true;
  @override
  Future<Map<int, BlockTimestamp>> fetchBlocksByHeight(Set<int> heights) async => {
    for (final height in heights) height: BlockTimestamp(height, DateTime(2026)),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late _DiskRealm manager;
  late _ObservedUtxos utxos;
  late TransactionRepository transactions;
  late AddressRepository addresses;
  late TransactionDraftRepository drafts;
  late ScriptSyncService sync;
  late UtxoSyncService utxoSync;
  late TransactionSyncService txSync;
  late _Electrum electrum;
  late _Node node;
  late SingleSignatureVault vault;
  late SinglesigWalletItem wallet;
  late Transaction signed;
  late Transaction funding;
  late String psbt;
  late String recipient;
  late UtxoTagProvider tags;
  final vms = <BroadcastingViewModel>[];
  late String inputId;

  void openRepositories() {
    utxos = _ObservedUtxos(manager);
    transactions = TransactionRepository(manager);
    addresses = AddressRepository(manager);
    drafts = TransactionDraftRepository(manager);
    final wallets = WalletRepository(manager, drafts);
    final state = MockNodeStateManager();
    final callbacks = ScriptCallbackService();
    utxoSync = UtxoSyncService(electrum, state, utxos, transactions, addresses);
    txSync = TransactionSyncService(
      electrum,
      transactions,
      TransactionRecordService(electrum, addresses),
      state,
      utxos,
      callbacks,
    );
    sync = ScriptSyncService(
      state,
      BalanceSyncService(electrum, state, addresses, wallets),
      txSync,
      utxoSync,
      addresses,
      callbacks,
    )..unsubscribeAddress = (_, __) async {};
    tags = UtxoTagProvider(utxos);
  }

  Future<void> syncBothAddresses() => sync.syncBatchScriptStatusList(
    walletItem: wallet,
    scriptStatuses: [
      ScriptStatusMock.createMockScriptStatus(wallet, 0),
      ScriptStatusMock.createMockScriptStatus(wallet, 0, isChange: true),
    ],
  );

  SubscriptionService subscriptions() =>
      SubscriptionService(electrum, MockNodeStateManager(), addresses, SubscriptionRepository(manager), sync);

  Future<BroadcastingViewModel> createViewModel({int? draftId, SelectedUtxoExcludedStatus? excluded}) async {
    final send =
        SendInfoProvider()
          ..setWalletId(1)
          ..setTransaction(Transaction.parse(signed.serialize()))
          ..setTxWaitingForSign(psbt)
          ..setSignedResult(signed.serialize())
          ..setFeeRate(1)
          ..setIsMaxMode(false);
    final result = BroadcastingViewModel(
      send,
      _Wallets(wallet),
      tags,
      true,
      node,
      _Transactions(transactions),
      drafts,
      utxos,
      draftId,
    );
    vms.add(result);
    expect(await result.setTxInfo(), excluded);
    return result;
  }

  void reopen() {
    for (final model in vms) {
      model.dispose();
    }
    vms.clear();
    tags.dispose();
    manager.dispose();
    manager.reopen();
    openRepositories();
  }

  TransactionBuildResult buildPayment() =>
      TransactionBuilder(
        availableUtxos: utxos.getUtxoStateList(1).where((u) => u.status == UtxoStatus.unspent).toList(),
        recipients: {recipient: 400000},
        feeRate: 2,
        changeDerivationPath: '${vault.derivationPath}/1/0',
        walletItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

  void expectInputReserved() {
    final input = utxos.getUtxoState(1, inputId)!;
    expect(input.status, UtxoStatus.outgoing);
    expect(input.spentByTransactionHash, signed.transactionHash);
    expect(manager.realm.find<RealmUtxo>('1:$inputId')!.isDeleted, isFalse);
    final (valid, excluded) = utxos.getValidatedSelectedUtxoList(1, [inputId]);
    expect(valid, isEmpty);
    expect(excluded, SelectedUtxoExcludedStatus.used);
  }

  void expectInputSpendable() {
    final input = utxos.getUtxoState(1, inputId)!;
    expect(input.status, UtxoStatus.unspent);
    expect(input.spentByTransactionHash, isNull);
    expect(manager.realm.find<RealmUtxo>('1:$inputId')!.isDeleted, isFalse);
    expect(utxos.getValidatedSelectedUtxoList(1, [inputId]).$1, hasLength(1));
    expect(buildPayment().isSuccess, isTrue);
  }

  Future<BroadcastingViewModel> broadcastUnknown() async {
    final model = await createViewModel();
    final result = await model.broadcast(inheritedTagIds: []);
    expect(result!.isFailure, isTrue);
    expect(model.isBroadcastResultUnknown, isTrue);
    expect(model.isTransactionAccepted, isFalse);
    expectInputReserved();
    return model;
  }

  setUp(() async {
    NetworkType.setNetworkType(NetworkType.testnet);
    LocaleSettings.setLocaleSync(AppLocale.ko);
    FlutterSecureStorage.setMockInitialValues({});
    temp = Directory.systemTemp.createTempSync('broadcast-unknown-');
    manager = _DiskRealm('${temp.path}/wallet.realm');
    vault = SingleSignatureVault.fromEntropy(Uint8List(16));
    recipient = SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, 1))).getAddress(0);
    wallet = SinglesigWalletItem(
      id: 1,
      name: 'Synthetic QA',
      colorIndex: 0,
      iconIndex: 0,
      descriptor: vault.descriptor,
    );
    funding = TransactionMock.createMockTransaction(toAddress: vault.getAddress(0), amount: 1000000);
    inputId = getUtxoId(funding.transactionHash, 0);
    final transaction = Transaction.withInputsAndOutputs(
      [TransactionInput.forPayment(funding.transactionHash, 0)],
      [
        TransactionOutput.forPayment(400000, recipient),
        TransactionOutput.forPayment(
          599000,
          vault.getAddress(0, isChange: true),
          derivationPath: '${vault.derivationPath}/1/0',
          isChangeOutput: true,
        ),
      ],
      AddressType.p2wpkh,
    );
    transaction.utxoList.add(Utxo(funding.transactionHash, 0, 1000000, '${vault.derivationPath}/0/0'));
    transaction.changeAddressDerivationPath = '${vault.derivationPath}/1/0';
    psbt = Psbt.fromTransaction(transaction, vault).serialize();
    signed = Psbt.parse(vault.addSignatureToPsbt(psbt)).getSignedTransaction(AddressType.p2wpkh);
    electrum = _Electrum(funding, signed, vault.getAddress(0), vault.getAddress(0, isChange: true));
    node = _Node();
    manager.realm.write(() {
      manager.realm.add(RealmWalletBase(1, 0, 0, vault.descriptor, 'Synthetic QA', 'singleSignature'));
      manager.realm.add(RealmWalletBalance(1, 1, 0, 0, 0));
    });
    openRepositories();
    await addresses.ensureAddressesInit(walletItemBase: wallet);
    await transactions.addAllTransactions(1, [
      TransactionMock.createConfirmedTransactionRecord(transactionHash: funding.transactionHash, blockHeight: 100),
    ]);
    await syncBothAddresses();
    expect(utxos.getUtxoState(1, inputId)!.status, UtxoStatus.unspent);
  });

  tearDown(() {
    for (final model in vms) {
      model.dispose();
    }
    vms.clear();
    tags.dispose();
    manager.dispose();
    temp.deleteSync(recursive: true);
  });

  test('C1 unknown excludes manual/automatic selection and survives disk Realm reopen', () async {
    await broadcastUnknown();
    expect(buildPayment().isFailure, isTrue);
    reopen();
    expectInputReserved();
    expect(buildPayment().isFailure, isTrue);
  });

  test('C6 same VM retry uses identical bytes and finalizes without revalidating outgoing', () async {
    final model = await broadcastUnknown();
    node.unknown = false;
    expect((await model.broadcast(inheritedTagIds: []))!.isSuccess, isTrue);
    expect(model.isTransactionAccepted, isTrue);
    expect(node.submitted.toSet(), {signed.serialize()});
  });

  test('C4 accepted next subscription records one send then confirms without ghost coins', () async {
    final sub = subscriptions();
    expect((await sub.subscribeWallet(wallet)).isSuccess, isTrue);
    await broadcastUnknown();
    electrum.accepted = true;
    await sub.unsubscribeWallet(wallet);
    expect((await sub.subscribeWallet(wallet)).isSuccess, isTrue);
    expect(transactions.getTransactionRecord(1, signed.transactionHash)!.blockHeight, 0);
    expect(
      transactions.getTransactionRecordList(1).where((t) => t.transactionHash == signed.transactionHash),
      hasLength(1),
    );
    expectInputReserved();
    expect(utxos.getUtxoState(1, getUtxoId(signed.transactionHash, 1))!.status, UtxoStatus.incoming);
    expect(utxos.getUtxoStateList(1), hasLength(2));
    electrum.sentHeight = 200;
    await sub.unsubscribeWallet(wallet);
    expect((await sub.subscribeWallet(wallet)).isSuccess, isTrue);
    expect(utxos.getUtxoState(1, inputId), isNull);
    expect(utxos.getUtxoStateList(1), hasLength(1));
    expect(utxos.getUtxoStateList(1).single.status, UtxoStatus.unspent);
    expect(utxos.getUtxoStateList(1).single.amount, 599000);
    expect(transactions.getTransactionRecord(1, signed.transactionHash)!.blockHeight, 200);
  });

  test('C6 not accepted refresh restores signed draft re-entry and identical resend', () async {
    final saved = await drafts.saveSignedDraft(
      walletId: 1,
      recipients: [RecipientDraft(address: recipient, amount: 400000)],
      feeRate: 1,
      isMaxMode: false,
      txWaitingForSign: psbt,
      signedPsbtBase64Encoded: signed.serialize(),
    );
    expect(saved.isSuccess, isTrue);
    await broadcastUnknown();
    final blocked = await createViewModel(draftId: saved.value.id, excluded: SelectedUtxoExcludedStatus.used);
    expect(blocked.isInitDone, isFalse);
    expect(transactions.getTransactionRecord(1, signed.transactionHash), isNull);
    await syncBothAddresses();
    expectInputSpendable();
    final restored = await createViewModel(draftId: saved.value.id);
    expect(restored.isInitDone, isTrue);
    expect(manager.realm.find<RealmTransactionDraft>(saved.value.id), isNotNull);
    node.unknown = false;
    expect((await restored.broadcast(inheritedTagIds: []))!.isSuccess, isTrue);
    expect(manager.realm.find<RealmTransactionDraft>(saved.value.id), isNull);
    expect(node.submitted.toSet(), {signed.serialize()});
  });

  for (final entry in ['reconnect', 'restart', 'pull-to-refresh']) {
    test('C1 unchanged history releases once through $entry', () async {
      var sub = subscriptions();
      expect((await sub.subscribeWallet(wallet)).isSuccess, isTrue);
      await broadcastUnknown();
      final counts = (electrum.historyCalls, electrum.balanceCalls, electrum.unspentCalls);
      if (entry != 'pull-to-refresh') await sub.unsubscribeWallet(wallet);
      if (entry == 'restart') {
        reopen();
        sub = subscriptions();
      }
      if (entry == 'pull-to-refresh') {
        final connectivity = _Connectivity();
        final refresh = _RefreshNode(connectivity, sub);
        connectivity.online = true;
        expect(await refresh.refreshWallet(wallet), isTrue);
        refresh.dispose();
      } else {
        expect((await sub.subscribeWallet(wallet)).isSuccess, isTrue);
      }
      expectInputSpendable();
      expect(
        (electrum.historyCalls - counts.$1, electrum.balanceCalls - counts.$2, electrum.unspentCalls - counts.$3),
        (1, 1, 1),
      );
      final queries = electrum.unspentCalls;
      expect((await sub.subscribeWallet(wallet)).isSuccess, isTrue);
      expect(electrum.unspentCalls, queries, reason: 'resolved input does not add queries to later refresh');
    });
  }

  test('C1 unrecorded outgoing address omitted from active subscription is still refreshed', () async {
    final sub = subscriptions();
    expect((await sub.subscribeWallet(wallet)).isSuccess, isTrue);
    await broadcastUnknown();
    addresses.updateAddressBalance(walletId: 1, index: 0, isChange: false, balance: Balance(0, 0));
    await sub.unsubscribeWallet(wallet);
    expect((await sub.subscribeWallet(wallet)).isSuccess, isTrue);
    expectInputSpendable();
  });

  test('C2 live notification failure preserves input and is recovered by subscription', () async {
    await broadcastUnknown();
    electrum.failUnspent = true;
    await sync.syncScriptStatus(
      SubscribeScriptStreamDto(
        walletItem: wallet,
        scriptStatus: ScriptStatusMock.createMockScriptStatus(wallet, 0),
        updateUsedIndex: false,
      ),
    );
    expect(sync.hasSyncFailure(1, vault.getAddress(0)), isTrue);
    expectInputReserved();
    electrum.failUnspent = false;
    expect((await subscriptions().subscribeWallet(wallet)).isSuccess, isTrue);
    expectInputSpendable();
    expect(sync.hasSyncFailure(1, vault.getAddress(0)), isFalse);
  });

  test('C2 other-address-only direct batch cannot delete an unqueried input', () async {
    await broadcastUnknown();
    electrum.unrelatedDeposit = TransactionMock.createMockTransaction(
      toAddress: vault.getAddress(0, isChange: true),
      amount: 500000,
    );
    await sync.syncBatchScriptStatusList(
      walletItem: wallet,
      scriptStatuses: [ScriptStatusMock.createMockScriptStatus(wallet, 0, isChange: true)],
    );
    expectInputReserved();
    expect((await subscriptions().subscribeWallet(wallet)).isSuccess, isTrue);
    expectInputSpendable();
  });

  for (final success in [false, true]) {
    test('C2 C5 success=$success failed list preserves input and one later refresh restores it', () async {
      final sub = subscriptions();
      expect((await sub.subscribeWallet(wallet)).isSuccess, isTrue);
      node.unknown = !success;
      final model = await createViewModel();
      await model.broadcast(inheritedTagIds: []);
      expectInputReserved();
      electrum.unrelatedDeposit = TransactionMock.createMockTransaction(
        toAddress: vault.getAddress(0, isChange: true),
        amount: 500000,
      );
      electrum.failUnspent = true;
      await sub.unsubscribeWallet(wallet);
      expect((await sub.subscribeWallet(wallet)).isFailure, isTrue);
      expectInputReserved();
      await sub.unsubscribeWallet(wallet);
      reopen();
      electrum.failUnspent = false;
      expect((await subscriptions().subscribeWallet(wallet)).isSuccess, isTrue);
      expectInputSpendable();
    });
  }

  test('C3 late acceptance after release repairs outgoing and blocks reuse', () async {
    final sub = subscriptions();
    expect((await sub.subscribeWallet(wallet)).isSuccess, isTrue);
    await broadcastUnknown();
    await syncBothAddresses();
    expectInputSpendable();
    electrum.accepted = true;
    await sub.unsubscribeWallet(wallet);
    expect((await sub.subscribeWallet(wallet)).isSuccess, isTrue);
    expect(transactions.getTransactionRecord(1, signed.transactionHash), isNotNull);
    expectInputReserved();
    expect(buildPayment().isFailure, isTrue);
  });

  test('R2 cleanup preserves an input reserved while another address response is pending', () async {
    electrum.unrelatedDeposit = TransactionMock.createMockTransaction(
      toAddress: vault.getAddress(0, isChange: true),
      amount: 500000,
    );
    utxos.observedAddress = vault.getAddress(0);
    utxos.receivedSaved = Completer<void>();
    electrum.holdChangeUnspent = Completer<void>();
    final sub = subscriptions();
    final syncing = sub.subscribeWallet(wallet);
    await utxos.receivedSaved!.future;
    expectInputSpendable();
    await broadcastUnknown();

    electrum.holdChangeUnspent!.complete();
    expect((await syncing).isSuccess, isTrue);
    expect(manager.realm.find<RealmUtxo>('1:$inputId')!.isDeleted, isFalse);
    expectInputReserved();
    await sub.unsubscribeWallet(wallet);
    reopen();
    expect((await subscriptions().subscribeWallet(wallet)).isSuccess, isTrue);
    expectInputSpendable();
  });

  test('R1 cleanup preserves an input reserved while another outgoing transaction is fetched', () async {
    final unrelated = TransactionMock.createMockTransaction(
      toAddress: recipient,
      amount: 12345,
      inputTransactionHash: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    );
    await transactions.addAllTransactions(1, [
      TransactionMock.createUnconfirmedTransactionRecord(transactionHash: unrelated.transactionHash),
    ]);
    electrum.extraPending = unrelated;
    electrum.extraReadStarted = Completer<void>();
    electrum.allowExtraRead = Completer<void>();
    final sub = subscriptions();
    final syncing = sub.subscribeWallet(wallet);
    await electrum.extraReadStarted!.future;
    expectInputSpendable();
    await broadcastUnknown();

    electrum.allowExtraRead!.complete();
    expect((await syncing).isSuccess, isTrue);
    expect(manager.realm.find<RealmUtxo>('1:$inputId')!.isDeleted, isFalse);
    expectInputReserved();
    await sub.unsubscribeWallet(wallet);
    reopen();
    expect((await subscriptions().subscribeWallet(wallet)).isSuccess, isTrue);
    expectInputSpendable();
  });

  for (final confirmed in [false, true]) {
    test(
      'R1 acceptance between history and listunspent resolves after ${confirmed ? 'confirmation' : 'eviction'}',
      () async {
        final sub = subscriptions();
        expect((await sub.subscribeWallet(wallet)).isSuccess, isTrue);
        await broadcastUnknown();
        // History still omits the send, but listunspent already omits its input.
        electrum.acceptBeforeUnspent = true;
        expect((await sub.subscribeWallet(wallet)).isSuccess, isTrue);
        expect(transactions.getTransactionRecord(1, signed.transactionHash), isNull);
        expect(manager.realm.find<RealmUtxo>('1:$inputId')!.isDeleted, isFalse);
        expectInputReserved();

        electrum.accepted = confirmed;
        electrum.sentHeight = confirmed ? 200 : 0;
        await sub.unsubscribeWallet(wallet);
        reopen();
        expect((await subscriptions().subscribeWallet(wallet)).isSuccess, isTrue);
        if (confirmed) {
          expect(transactions.getTransactionRecord(1, signed.transactionHash)!.blockHeight, 200);
          expect(utxos.getUtxoState(1, inputId), isNull);
          expect(utxos.getUtxoStateList(1), hasLength(1));
          expect(utxos.getUtxoStateList(1).single.amount, 599000);
          expect(utxos.getUtxoStateList(1).single.status, UtxoStatus.unspent);
        } else {
          expectInputSpendable();
        }
      },
    );
  }

  for (final order in ['before reservation', 'after reservation', 'same transaction reserved again']) {
    test('AI listunspent started $order cannot release a newer reservation', () async {
      if (order != 'before reservation') await broadcastUnknown();
      final hold = Completer<void>();
      electrum.holdNextReceiveUnspent = hold;
      electrum.receiveUnspentStarted = Completer<void>();
      final updating = utxoSync.fetchScriptUtxo(wallet, ScriptStatusMock.createMockScriptStatus(wallet, 0));
      await electrum.receiveUnspentStarted!.future;
      if (order == 'same transaction reserved again') {
        await utxoSync.fetchScriptUtxo(wallet, ScriptStatusMock.createMockScriptStatus(wallet, 0));
        expectInputSpendable();
      }
      if (order != 'after reservation') {
        await broadcastUnknown();
        electrum.accepted = true;
      }
      hold.complete();
      await updating;
      if (order == 'after reservation') {
        expectInputSpendable();
        expect(utxoSync.getUnrecordedOutgoingAddresses(1), isEmpty);
      } else {
        expectInputReserved();
        expect(buildPayment().isFailure, isTrue);
        expect(utxoSync.getUnrecordedOutgoingAddresses(1), {vault.getAddress(0)});
      }
    });
  }

  for (final success in [false, true]) {
    test('same screen retry success=$success renews the reservation against an earlier list query', () async {
      final model = await broadcastUnknown();
      final sub = subscriptions();
      electrum.receiveUnspentStarted = Completer<void>();
      final hold = electrum.holdNextReceiveUnspent = Completer<void>();
      final updating = sub.subscribeWallet(wallet);
      await electrum.receiveUnspentStarted!.future;
      node.unknown = !success;
      await model.broadcast(inheritedTagIds: []);
      electrum.accepted = true;
      hold.complete();
      await updating;
      expectInputReserved();
      expect(buildPayment().isFailure, isTrue);
      expect(model.isTransactionAccepted, success);
      // Each unknown result includes the existing automatic retry; success needs one request.
      expect(node.submitted, List.filled(success ? 3 : 4, signed.serialize()));
    });
  }

  test('wallet queue prevents two refreshes from releasing and renewing a reservation inside one query', () async {
    await broadcastUnknown();
    final sub = subscriptions();
    electrum.receiveUnspentStarted = Completer<void>();
    final hold = electrum.holdNextReceiveUnspent = Completer<void>();
    final first = sub.subscribeWallet(wallet);
    await electrum.receiveUnspentStarted!.future;
    await Future<void>.delayed(Duration.zero);
    final calls = electrum.unspentCalls;
    var secondCompleted = false;
    final second = sub.subscribeWallet(wallet).then((result) {
      secondCompleted = true;
      return result;
    });
    await Future<void>.delayed(Duration.zero);
    expect(secondCompleted, isFalse);
    expect(electrum.unspentCalls, calls);
    expectInputReserved();
    hold.complete();
    expect((await first).isSuccess, isTrue);
    expect((await second).isSuccess, isTrue);
    expectInputSpendable();
    expect(electrum.unspentCalls, calls);
  });

  for (final confirmed in [false, true]) {
    for (final startsAfterReservation in [false, true]) {
      test('transaction confirmed=$confirmed read after reservation=$startsAfterReservation', () async {
        final reserved = TransactionMock.createMockTransaction(
          toAddress: recipient,
          amount: 390000,
          inputTransactionHash: funding.transactionHash,
        );
        if (startsAfterReservation) await utxos.markUnspentInputsAsOutgoing(1, reserved);
        electrum.accepted = true;
        electrum.sentHeight = confirmed ? 200 : 0;
        electrum.sentReadStarted = Completer<void>();
        final hold = electrum.holdNextSentRead = Completer<void>();
        final updating = txSync.fetchScriptTransaction(wallet, ScriptStatusMock.createMockScriptStatus(wallet, 0));
        await electrum.sentReadStarted!.future;
        if (!startsAfterReservation) await utxos.markUnspentInputsAsOutgoing(1, reserved);
        hold.complete();
        await updating;
        if (confirmed) {
          expect(utxos.getUtxoState(1, inputId), isNull);
          expect(manager.realm.find<RealmUtxo>('1:$inputId')!.isDeleted, isTrue);
        } else {
          final input = utxos.getUtxoState(1, inputId)!;
          expect(input.status, UtxoStatus.outgoing);
          expect(
            input.spentByTransactionHash,
            startsAfterReservation ? signed.transactionHash : reserved.transactionHash,
          );
          // An unchanged confirmed history or an abandoned mempool transaction must still recover.
          electrum.accepted = false;
          await utxoSync.fetchScriptUtxo(wallet, ScriptStatusMock.createMockScriptStatus(wallet, 0));
          expectInputSpendable();
        }
      });
    }
  }

  test('older history cannot reverse a newer recorded spender into its RBF predecessor', () async {
    final newer = TransactionMock.createMockTransaction(
      toAddress: recipient,
      amount: 380000,
      inputTransactionHash: funding.transactionHash,
    );
    final initialHistoryCalls = electrum.historyCalls;
    electrum.accepted = true;
    electrum.sentReadStarted = Completer<void>();
    final hold = electrum.holdNextSentRead = Completer<void>();
    final updating = txSync.fetchScriptTransaction(wallet, ScriptStatusMock.createMockScriptStatus(wallet, 0));
    await electrum.sentReadStarted!.future;
    await utxos.markUnspentInputsAsOutgoing(1, newer);
    await transactions.addAllTransactions(1, [
      TransactionMock.createMockTransactionRecord(transactionHash: newer.transactionHash),
    ]);
    electrum.accepted = false;
    hold.complete();
    await updating;
    expect(utxos.getUtxoState(1, inputId)!.spentByTransactionHash, newer.transactionHash);
    expect(transactions.getRbfHistoryList(1, signed.transactionHash), isEmpty);
    expect(electrum.historyCalls - initialHistoryCalls, 2);
  });

  test('a recorded fee replacement updates the spender when its local broadcast finishes during sync', () async {
    final previous = TransactionMock.createMockTransaction(
      toAddress: recipient,
      amount: 390000,
      inputTransactionHash: funding.transactionHash,
    );
    await utxos.markUnspentInputsAsOutgoing(1, previous);
    await transactions.addAllTransactions(1, [
      TransactionMock.createMockTransactionRecord(transactionHash: previous.transactionHash),
    ]);
    final initialHistoryCalls = electrum.historyCalls;
    electrum.accepted = true;
    electrum.sentReadStarted = Completer<void>();
    final hold = electrum.holdNextSentRead = Completer<void>();
    final updating = txSync.fetchScriptTransaction(wallet, ScriptStatusMock.createMockScriptStatus(wallet, 0));
    await electrum.sentReadStarted!.future;
    await utxos.markUnspentInputsAsOutgoing(1, signed);
    hold.complete();
    await updating;
    expect(transactions.getRbfHistoryList(1, signed.transactionHash), isNotEmpty);
    expect(utxos.getUtxoState(1, inputId)!.spentByTransactionHash, signed.transactionHash);
    expect(electrum.historyCalls - initialHistoryCalls, 2);
  });

  for (final startsAfterReservation in [false, true]) {
    test('createOutgoingUtxos read after reservation=$startsAfterReservation', () async {
      final available = utxos.getUtxoState(1, inputId)!;
      // Restoring a wallet can start with no locally known input.
      manager.realm.write(() => manager.realm.delete(manager.realm.find<RealmUtxo>('1:$inputId')!));
      final reserved = TransactionMock.createMockTransaction(
        toAddress: recipient,
        amount: 390000,
        inputTransactionHash: funding.transactionHash,
      );
      Future<void> reserve() async {
        expect((await utxos.addAllUtxos(1, [available])).isSuccess, isTrue);
        await utxos.markUnspentInputsAsOutgoing(1, reserved);
      }

      if (startsAfterReservation) await reserve();
      await transactions.addAllTransactions(1, [
        TransactionMock.createMockTransactionRecord(transactionHash: signed.transactionHash),
      ]);
      electrum.accepted = true;
      electrum.sentReadStarted = Completer<void>();
      final hold = electrum.holdNextSentRead = Completer<void>();
      final updating = utxoSync.createOutgoingUtxos(wallet);
      await electrum.sentReadStarted!.future;
      if (!startsAfterReservation) await reserve();
      hold.complete();
      await updating;
      final input = utxos.getUtxoState(1, inputId)!;
      expect(input.status, UtxoStatus.outgoing);
      expect(input.spentByTransactionHash, reserved.transactionHash);
      expect(manager.realm.all<RealmUtxo>().where((u) => u.id == '1:$inputId'), hasLength(1));
      expect(buildPayment().isFailure, isTrue);
    });
  }

  test('R3 limitation other inputs still build a distinct payment while unknown input is outgoing', () async {
    await broadcastUnknown();
    final second = UtxoState(
      transactionHash: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      index: 0,
      amount: 1000000,
      derivationPath: '${vault.derivationPath}/0/0',
      blockHeight: 100,
      to: vault.getAddress(0),
      timestamp: DateTime(2026),
      status: UtxoStatus.unspent,
    );
    await utxos.addAllUtxos(1, [second]);
    final built = buildPayment();
    expect(built.isSuccess, isTrue);
    expect(built.transaction!.inputs.single.transactionHash, second.transactionHash);
    expect(built.transaction!.transactionHash, isNot(signed.transactionHash));
  });
}
