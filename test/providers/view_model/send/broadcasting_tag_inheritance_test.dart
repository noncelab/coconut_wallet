import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/model/node/isolate_state_message.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_manager.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, ValueNotifier;
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/broadcasting_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/result.dart';
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
  @override
  Object connectionEndpointIdentity = Object();
  @override
  bool isServerChanging = false;
  int broadcasts = 0;
  bool connected = true;
  @override
  String host = 'node.example';
  Future<Result<bool>> Function()? onReconnect;

  @override
  Future<Result<bool>> ensureConnectedForBroadcast() {
    reconnects++;
    return onReconnect!();
  }

  int reconnects = 0;
  Future<Result<BlockTimestamp>> Function()? onLatestBlock;

  bool fails = false;
  void Function()? duringBroadcast;

  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async =>
      onLatestBlock != null
          ? await onLatestBlock!()
          : connected
          ? Result.success(BlockTimestamp(100, DateTime(2026)))
          : Result.failure(ErrorCodes.nodeConnectionError);

  @override
  Future<Result<String>> broadcast(Transaction signedTx) async {
    broadcasts++;
    duringBroadcast?.call();
    return fails ? Result.failure(ErrorCodes.broadcastError) : Result.success(signedTx.transactionHash);
  }
}

/// Only transport and connectivity are controlled; NodeProvider itself is real.
class _ConnectionEvents extends ChangeNotifier implements ConnectivityProvider {
  bool online = true;
  @override
  bool get isInternetOn => online;
  @override
  bool get isInternetOff => !online;
  @override
  bool get isVpnActive => false;
  @override
  bool get isVpnInactive => true;
  @override
  Future<void> refreshConnectivity() async {}
  void setOnline(bool value) {
    online = value;
    notifyListeners();
  }
}

class _ControlledIsolate extends Fake implements IsolateManager {
  final events = StreamController<IsolateStateMessage>.broadcast();
  bool connected = false;
  int initializations = 0;
  int broadcasts = 0;
  int subscriptions = 0;
  Future<void> Function()? onInitialize;
  Completer<Result<bool>>? subscription;
  @override
  Stream<IsolateStateMessage> get stateStream => events.stream;
  @override
  Future<void> initialize(String host, int port, bool ssl, NetworkType networkType, [String? fingerprint]) async {
    initializations++;
    await onInitialize?.call();
    connected = true;
  }

  @override
  Future<void> closeIsolate() async {
    connected = false;
  }

  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async =>
      connected ? Result.success(BlockTimestamp(100, DateTime(2026))) : Result.failure(ErrorCodes.nodeConnectionError);
  @override
  Future<Result<SocketConnectionStatus>> getSocketConnectionStatus() async =>
      Result.success(connected ? SocketConnectionStatus.connected : SocketConnectionStatus.terminated);
  @override
  Future<Result<bool>> subscribeWallets(List<WalletItemBase> wallets) async {
    subscriptions++;
    return subscription?.future ?? Result.success(true);
  }

  @override
  Future<Result<String>> broadcast(Transaction transaction) async {
    broadcasts++;
    return connected ? Result.success(transaction.transactionHash) : Result.failure(ErrorCodes.nodeConnectionError);
  }
}

class _PendingDraftRepository extends Fake implements TransactionDraftRepository {
  final completion = Completer<Result<void>>();
  final deleted = <int>[];

  @override
  Future<Result<void>> deleteOne(int draftId) {
    deleted.add(draftId);
    return completion.future;
  }
}

class _DelayedUtxoRepository extends UtxoRepository {
  _DelayedUtxoRepository(super.manager);
  Future<Result<void>> Function()? onApply;

  @override
  Future<Result<void>> applyInheritedTags(
    int walletId, {
    required List<String> sourceUtxoIds,
    required List<String> targetUtxoIds,
    required List<String> tagIds,
  }) =>
      onApply?.call() ??
      super.applyInheritedTags(walletId, sourceUtxoIds: sourceUtxoIds, targetUtxoIds: targetUtxoIds, tagIds: tagIds);
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
  late _DelayedUtxoRepository repository;
  late _NodeProvider node;
  late _TransactionProvider transactions;
  late _WalletProvider wallets;
  late SingleSignatureVault vault;
  late BroadcastingViewModel viewModel;
  late UtxoTagProvider tags;
  BroadcastingViewModel? disposedViewModel;

  setUpAll(() {
    NetworkType.setNetworkType(NetworkType.testnet);
    vault = SingleSignatureVault.fromEntropy(Uint8List(16));
  });

  setUp(() {
    disposedViewModel = null;
    manager = TestRealmManager();
    repository = _DelayedUtxoRepository(manager);
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
    TransactionDraftRepository? drafts,
    int? unsignedDraftId,
    NodeProvider? connectedNode,
  }) async {
    transaction.changeAddressDerivationPath = "${vault.derivationPath}/1/1";
    final original = Psbt.fromTransaction(transaction, vault);
    final signed = Psbt.parse(vault.addSignatureToPsbt(original.serialize()));
    if (returnPsbt) {
      // Some signers retain input derivation but omit optional output metadata.
      signed.psbtMap['outputs'][0].clear();
    }
    final sendInfo =
        SendInfoProvider()
          ..setWalletId(1)
          ..setTxWaitingForSign(original.serialize())
          ..setSignedResult(
            returnPsbt ? signed.serialize() : signed.getSignedTransaction(AddressType.p2wpkh).serialize(),
          );
    if (unsignedDraftId != null) sendInfo.setUnsignedDraftId(unsignedDraftId);
    viewModel = BroadcastingViewModel(
      sendInfo,
      wallets,
      tags,
      true,
      connectedNode ?? node,
      transactions,
      drafts ?? TransactionDraftRepository(manager),
      repository,
      null,
    );
    final created = viewModel;
    addTearDown(() {
      if (!identical(created, disposedViewModel)) created.dispose();
    });
    expect(await viewModel.setTxInfo(), isNull);
    expect(viewModel.isInitDone, isTrue);
  }

  Future<void> initialize({
    bool ownOutput = true,
    bool outputDerivation = true,
    bool returnPsbt = false,
    int outputAmount = 999000,
    TransactionDraftRepository? drafts,
    int? unsignedDraftId,
    NodeProvider? connectedNode,
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
      drafts: drafts,
      unsignedDraftId: unsignedDraftId,
      connectedNode: connectedNode,
    );
  }

  String targetId() => getUtxoId(viewModel.signedTx!.transactionHash, 0);
  final inputId = getUtxoId(_inputHash, 0);
  final realmInputId = getRealmUtxoId(1, _inputHash, 0);

  NodeProvider createRealNode(_ConnectionEvents connectivity, _ControlledIsolate isolate) {
    final load = ValueNotifier(WalletLoadState.loadCompleted);
    final items = ValueNotifier<List<WalletItemBase>>([wallets.wallet]);
    final real = NodeProvider(
      const ElectrumServer('unused.example', 50002, true),
      NetworkType.testnet,
      connectivity,
      load,
      items,
      null,
      isolateManager: isolate,
    );
    addTearDown(() async {
      await real.closeConnection();
      real.dispose();
      await isolate.events.close();
      load.dispose();
      items.dispose();
      connectivity.dispose();
    });
    return real;
  }

  testWidgets('network loss during preparation blocks transmission even after later restoration', (tester) async {
    final connectivity = _ConnectionEvents();
    final isolate = _ControlledIsolate();
    final real = createRealNode(connectivity, isolate);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => initialize(connectedNode: real));
    final initialization = Completer<void>();
    isolate.onInitialize = () => initialization.future;
    isolate.connected = false;
    Result<String>? outcome;
    viewModel
        .broadcast(inheritedTagIds: [], onConnectionWaitExtension: (_, __) async => true)
        .then((value) => outcome = value);
    await tester.pump();
    expect(viewModel.isConnectionRecovering, isFalse, reason: 'a failure within the probe time is not a delay yet');
    final count = isolate.initializations;
    connectivity.setOnline(false);
    await tester.pump();
    initialization.complete();
    await tester.pump();
    for (var second = 0; second < 5; second++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(isolate.broadcasts, 0);
    expect(isolate.initializations, count, reason: 'offline retries must not reopen the socket');
    expect(viewModel.isConnectionRecovering, isTrue);
    expect(viewModel.cancelPendingSend(), isTrue);
    await tester.pump();
    expect(outcome?.isFailure, isTrue);
    isolate.onInitialize = null;
    connectivity.setOnline(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(isolate.connected, isTrue);
    expect(isolate.broadcasts, 0, reason: 'restoring the network must not revive a cancelled send');
    await real.closeConnection();
  });

  testWidgets('view model waits for actual NodeProvider final recovery and sends once before bulk sync ends', (
    tester,
  ) async {
    final connectivity = _ConnectionEvents()..online = false;
    final isolate = _ControlledIsolate();
    final real = createRealNode(connectivity, isolate);
    await tester.runAsync(() => initialize(connectedNode: real));
    repository.onApply = () async => Result<void>.success(null);
    final firstInitialization = Completer<void>();
    final finalInitialization = Completer<void>();
    final bulk = Completer<Result<bool>>();
    isolate.subscription = bulk;
    isolate.onInitialize = () => isolate.initializations == 1 ? firstInitialization.future : finalInitialization.future;
    connectivity.setOnline(true);
    await tester.pump();
    expect(isolate.initializations, 1);
    Result<String>? outcome;
    viewModel
        .broadcast(inheritedTagIds: [], onConnectionWaitExtension: (_, __) async => true)
        .then((value) => outcome = value);
    await tester.pump();
    expect(viewModel.isConnectionRecovering, isFalse, reason: 'a failure within the probe time is not a delay yet');
    firstInitialization.complete();
    await tester.pump();
    expect(isolate.initializations, 2);
    expect(isolate.broadcasts, 0, reason: 'the intermediate socket must not be used');
    expect(outcome, isNull);
    await tester.pump(const Duration(seconds: 2));
    expect(isolate.initializations, 2, reason: 'pending final initialization must be shared');
    finalInitialization.complete();
    await tester.pump();
    expect(outcome?.isSuccess, isTrue);
    expect(isolate.broadcasts, 1);
    expect(bulk.isCompleted, isFalse, reason: 'bulk sync must not block transmission');
    expect(isolate.subscriptions, greaterThan(0));
    bulk.complete(Result.success(true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(isolate.broadcasts, 1, reason: 'late sync results must not repeat the transaction');
    await real.closeConnection();
  });

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

  test('certificate failure prevents broadcasting without retry', () async {
    await initialize();
    node.connected = false;
    node.onReconnect = () async => Result.failure(ErrorCodes.untrustedCertificateError);
    final result = await viewModel.broadcast(inheritedTagIds: []);
    expect(result.isFailure, isTrue);
    expect(result.error, ErrorCodes.untrustedCertificateError);
    expect(node.broadcasts, 0);
  });

  for (final onion in [false, true]) {
    testWidgets('recovery timeout bounds send and late recovery cannot broadcast (onion=$onion)', (tester) async {
      await tester.runAsync(() => initialize());
      node.connected = false;
      node.host = onion ? 'test.onion' : 'node.example';
      final recovery = Completer<Result<bool>>();
      node.onReconnect = () => recovery.future;
      Result<String>? outcome;
      viewModel.broadcast(inheritedTagIds: []).then((value) => outcome = value);
      await tester.pump();
      final limit = onion ? 90 : 15;
      await tester.pump(Duration(seconds: limit - 1));
      expect(outcome, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(outcome?.isFailure, isTrue);
      expect(node.broadcasts, 0);
      recovery.complete(Result.success(true));
      await tester.pump();
      expect(node.broadcasts, 0);
    });
  }

  for (final onion in [false, true]) {
    testWidgets('connection check gives up at its limit then asks for recovery (onion=$onion)', (tester) async {
      await tester.runAsync(() => initialize());
      node.host = onion ? 'abc.ONION ' : 'node.example';
      final hung = Completer<Result<BlockTimestamp>>();
      node.onLatestBlock = () => hung.future;
      node.onReconnect = () async => Result.success(true);
      repository.onApply = () async => Result<void>.success(null); // keep Realm off the fake clock
      Result<String>? outcome;
      viewModel.broadcast(inheritedTagIds: []).then((value) => outcome = value);
      await tester.pump();
      final limit = onion ? 10 : 3;
      await tester.pump(Duration(seconds: limit - 1));
      expect(node.reconnects, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(node.reconnects, 1);
      expect(outcome?.isSuccess, isTrue);
      expect(node.broadcasts, 1);
      // A late answer from the abandoned check must not trigger anything else.
      hung.complete(Result.success(BlockTimestamp(100, DateTime(2026))));
      await tester.pump();
      expect(node.reconnects, 1);
      expect(node.broadcasts, 1);
    });
  }

  for (final onion in [false, true]) {
    testWidgets('connection extensions use cumulative deadlines and share one recovery (onion=$onion)', (tester) async {
      await tester.runAsync(() => initialize());
      node.connected = false;
      node.host = onion ? 'node.onion' : 'node.example';
      final recovery = Completer<Result<bool>>();
      node.onReconnect = () => recovery.future;
      final offers = <int>[];
      Result<String>? outcome;
      viewModel
          .broadcast(
            inheritedTagIds: [],
            onConnectionWaitExtension: (limit, finished) async {
              offers.add(limit.inSeconds);
              return true;
            },
          )
          .then((value) => outcome = value);
      await tester.pump();
      final limits = onion ? [90, 120, 180] : [15, 30, 60];
      var elapsed = 0;
      for (var stage = 0; stage < limits.length - 1; stage++) {
        await tester.pump(Duration(seconds: limits[stage] - elapsed));
        elapsed = limits[stage];
        expect(offers, limits.sublist(1, stage + 2));
        expect(outcome, isNull);
      }
      await tester.pump(Duration(seconds: limits.last - elapsed - 1));
      expect(outcome, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(outcome?.isFailure, isTrue);
      expect(node.reconnects, 1);
      recovery.complete(Result.success(true));
      await tester.pump();
      expect(node.broadcasts, 0);
    });
  }

  for (final onion in [false, true]) {
    testWidgets('probe timeout immediately marks recovery as delayed (onion=$onion)', (tester) async {
      await tester.runAsync(() => initialize());
      node.host = onion ? 'node.onion' : 'node.example';
      final probe = Completer<Result<BlockTimestamp>>();
      final recovery = Completer<Result<bool>>();
      node.onLatestBlock = () => probe.future;
      node.onReconnect = () => recovery.future;
      repository.onApply = () async => Result<void>.success(null);
      Result<String>? outcome;
      viewModel.broadcast(inheritedTagIds: []).then((value) => outcome = value);
      await tester.pump();
      final probeSeconds = onion ? 10 : 3;
      await tester.pump(Duration(seconds: probeSeconds - 1));
      expect(viewModel.isConnectionRecovering, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(viewModel.isConnectionRecovering, isTrue);
      expect(node.reconnects, 1);
      expect(node.broadcasts, 0);
      recovery.complete(Result.success(true));
      await tester.pump();
      expect(viewModel.isConnectionRecovering, isFalse);
      expect(outcome?.isSuccess, isTrue);
      expect(node.broadcasts, 1);
      probe.complete(Result.failure(ErrorCodes.nodeConnectionError));
      await tester.pump();
    });
  }

  for (final onion in [false, true]) {
    testWidgets('an instantly failed probe is shown as delayed only after the probe time (onion=$onion)', (
      tester,
    ) async {
      await tester.runAsync(() => initialize());
      node.connected = false;
      node.host = onion ? 'node.onion' : 'node.example';
      final recovery = Completer<Result<bool>>();
      node.onReconnect = () => recovery.future;
      repository.onApply = () async => Result<void>.success(null);
      Result<String>? outcome;
      viewModel.broadcast(inheritedTagIds: []).then((value) => outcome = value);
      await tester.pump();
      expect(node.reconnects, 1, reason: 'recovery starts right away');
      expect(viewModel.isConnectionRecovering, isFalse, reason: 'the notice must not appear with the request text');
      final probeSeconds = onion ? 10 : 3;
      await tester.pump(Duration(seconds: probeSeconds - 1));
      expect(viewModel.isConnectionRecovering, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(viewModel.isConnectionRecovering, isTrue);
      recovery.complete(Result.success(true));
      await tester.pump();
      expect(viewModel.isConnectionRecovering, isFalse);
      expect(outcome?.isSuccess, isTrue);
      expect(node.broadcasts, 1);
    });
  }

  for (final onion in [false, true]) {
    testWidgets('failed recovery retries with backoff and sends once (onion=$onion)', (tester) async {
      await tester.runAsync(() => initialize());
      node.connected = false;
      node.host = onion ? 'node.onion' : 'node.example';
      node.onReconnect =
          () async => node.reconnects < 3 ? Result.failure(ErrorCodes.nodeConnectionError) : Result.success(true);
      repository.onApply = () async => Result<void>.success(null);
      Result<String>? outcome;
      viewModel
          .broadcast(inheritedTagIds: [], onConnectionWaitExtension: (_, __) async => true)
          .then((value) => outcome = value);
      await tester.pump();
      expect(node.reconnects, 1);
      expect(viewModel.isConnectionRecovering, isFalse, reason: 'a failure within the probe time is not a delay yet');
      await tester.pump(Duration(seconds: onion ? 3 : 1));
      expect(node.reconnects, 2);
      await tester.pump(Duration(seconds: onion ? 6 : 2));
      expect(node.reconnects, 3);
      expect(outcome?.isSuccess, isTrue);
      expect(node.broadcasts, 1);
      expect(viewModel.isConnectionRecovering, isFalse);
    });
  }

  for (final stopBy in ['cancel', 'server', 'deadline']) {
    testWidgets('failed recovery retries stop on $stopBy without late attempts', (tester) async {
      await tester.runAsync(() => initialize());
      node.connected = false;
      node.onReconnect = () async => Result.failure(ErrorCodes.nodeConnectionError);
      Result<String>? outcome;
      viewModel
          .broadcast(inheritedTagIds: [], onConnectionWaitExtension: (_, __) async => true)
          .then((value) => outcome = value);
      await tester.pump();
      expect(node.reconnects, 1);
      if (stopBy == 'cancel') {
        expect(viewModel.cancelPendingSend(), isTrue);
      } else if (stopBy == 'server') {
        node.connectionEndpointIdentity = Object();
      }
      // Advance individual retry timers without skipping the fake clock's microtasks.
      for (var second = 0; second < 60; second++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(outcome?.isFailure, isTrue);
      final attempts = node.reconnects;
      if (stopBy != 'deadline') expect(attempts, 1);
      await tester.pump(const Duration(seconds: 120));
      expect(node.reconnects, attempts);
      expect(node.broadcasts, 0);
    });
  }

  testWidgets('pending recovery is not restarted when a wait stage advances', (tester) async {
    await tester.runAsync(() => initialize());
    node.connected = false;
    final recovery = Completer<Result<bool>>();
    node.onReconnect = () => recovery.future;
    repository.onApply = () async => Result<void>.success(null);
    Result<String>? outcome;
    viewModel
        .broadcast(inheritedTagIds: [], onConnectionWaitExtension: (_, __) async => true)
        .then((value) => outcome = value);
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 15));
    expect(node.reconnects, 1);
    recovery.complete(Result.success(true));
    await tester.pump();
    expect(outcome?.isSuccess, isTrue);
    expect(node.broadcasts, 1);
  });

  testWidgets('time spent deciding on an extension consumes the cumulative budget', (tester) async {
    await tester.runAsync(() => initialize());
    node.connected = false;
    final recovery = Completer<Result<bool>>();
    final decision = Completer<bool>();
    node.onReconnect = () => recovery.future;
    final offers = <int>[];
    Result<String>? outcome;
    viewModel
        .broadcast(
          inheritedTagIds: [],
          onConnectionWaitExtension: (limit, finished) {
            offers.add(limit.inSeconds);
            return offers.length == 1 ? decision.future : Future.value(false);
          },
        )
        .then((value) => outcome = value);
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 10));
    decision.complete(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(offers, [30, 60]);
    expect(outcome?.isFailure, isTrue);
    recovery.complete(Result.success(true));
    await tester.pump();
    expect(node.broadcasts, 0);
  });

  testWidgets('final connection deadline also closes an unanswered prompt', (tester) async {
    await tester.runAsync(() => initialize());
    node.connected = false;
    final recovery = Completer<Result<bool>>();
    node.onReconnect = () => recovery.future;
    bool promptClosed = false;
    Result<String>? outcome;
    viewModel
        .broadcast(
          inheritedTagIds: [],
          onConnectionWaitExtension: (limit, finished) async {
            await finished;
            promptClosed = true;
            return true;
          },
        )
        .then((value) => outcome = value);
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 45));
    expect(outcome?.isFailure, isTrue);
    expect(promptClosed, isTrue);
    recovery.completeError(StateError('late recovery error'));
    await tester.pump();
    expect(node.broadcasts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connection finishing while extension prompt is open proceeds once', (tester) async {
    await tester.runAsync(() => initialize());
    node.connected = false;
    final recovery = Completer<Result<bool>>();
    node.onReconnect = () => recovery.future;
    repository.onApply = () async => Result<void>.success(null);
    Result<String>? outcome;
    viewModel
        .broadcast(
          inheritedTagIds: [],
          onConnectionWaitExtension: (limit, finished) async {
            await finished; // screen dismisses the prompt when the operation finishes
            return true;
          },
        )
        .then((value) => outcome = value);
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    recovery.complete(Result.success(true));
    await tester.pump();
    expect(outcome?.isSuccess, isTrue);
    expect(node.broadcasts, 1);
  });

  testWidgets('declining extension prevents late transmission', (tester) async {
    await tester.runAsync(() => initialize());
    node.connected = false;
    final recovery = Completer<Result<bool>>();
    node.onReconnect = () => recovery.future;
    Result<String>? outcome;
    viewModel
        .broadcast(inheritedTagIds: [], onConnectionWaitExtension: (_, __) async => false)
        .then((value) => outcome = value);
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    expect(outcome?.isFailure, isTrue);
    expect(viewModel.connectionWaitDeclined, isTrue);
    recovery.complete(Result.success(true));
    await tester.pump();
    expect(node.broadcasts, 0);
  });

  testWidgets('cancelling while waiting for the connection prevents a later broadcast', (tester) async {
    await tester.runAsync(() => initialize());
    node.connected = false;
    final recovery = Completer<Result<bool>>();
    node.onReconnect = () => recovery.future;
    Result<String>? outcome;
    viewModel.broadcast(inheritedTagIds: []).then((value) => outcome = value);
    await tester.pump();
    expect(node.reconnects, 1);
    expect(viewModel.cancelPendingSend(), isTrue);
    recovery.complete(Result.success(true));
    await tester.pump();
    expect(outcome?.isFailure, isTrue);
    expect(node.broadcasts, 0);
  });

  testWidgets('a send whose request reached the node cannot be cancelled', (tester) async {
    await tester.runAsync(() => initialize());
    repository.onApply = () async => Result<void>.success(null); // keep Realm off the fake clock
    late bool cancelledDuringRequest;
    node.duringBroadcast = () => cancelledDuringRequest = viewModel.cancelPendingSend();
    final outcome = await viewModel.broadcast(inheritedTagIds: []);
    expect(cancelledDuringRequest, isFalse);
    expect(outcome.isSuccess, isTrue);
    expect(node.broadcasts, 1);
  });

  test('a failed request can be cancelled before the next attempt', () async {
    await initialize();
    node.fails = true;
    expect((await viewModel.broadcast(inheritedTagIds: [])).isFailure, isTrue);
    expect(viewModel.cancelPendingSend(), isTrue);
    node.fails = false;
    expect((await viewModel.broadcast(inheritedTagIds: [])).isFailure, isTrue);
    expect(node.broadcasts, 1);
  });

  testWidgets('disposing the view model while waiting prevents a later broadcast', (tester) async {
    await tester.runAsync(() => initialize());
    node.connected = false;
    final recovery = Completer<Result<bool>>();
    node.onReconnect = () => recovery.future;
    Result<String>? outcome;
    viewModel.broadcast(inheritedTagIds: []).then((value) => outcome = value);
    await tester.pump();
    viewModel.dispose();
    disposedViewModel = viewModel;
    recovery.complete(Result.success(true));
    await tester.pump();
    expect(outcome?.isFailure, isTrue);
    expect(node.broadcasts, 0);
  });

  testWidgets('retry after recovery timeout joins it and broadcasts exactly once', (tester) async {
    await tester.runAsync(() => initialize());
    node.connected = false;
    final recovery = Completer<Result<bool>>();
    node.onReconnect = () => recovery.future; // shared future, as NodeProvider does with reuseInFlight
    repository.onApply = () async => Result<void>.success(null); // keep Realm off the fake clock
    Result<String>? first;
    viewModel.broadcast(inheritedTagIds: []).then((value) => first = value);
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    expect(first?.isFailure, isTrue);
    expect(first?.error, ErrorCodes.nodeConnectionError);

    Result<String>? second;
    viewModel.broadcast(inheritedTagIds: []).then((value) => second = value);
    await tester.pump(const Duration(seconds: 3));
    expect(second, isNull);
    recovery.complete(Result.success(true));
    await tester.pump();
    expect(second?.isSuccess, isTrue);
    expect(node.broadcasts, 1, reason: 'the timed-out attempt must not resume');
    await tester.pump(const Duration(seconds: 30));
    expect(node.broadcasts, 1);
  });

  test('recovery reporting false prevents broadcasting', () async {
    await initialize();
    node.connected = false;
    node.onReconnect = () async => Result.success(false);
    final result = await viewModel.broadcast(inheritedTagIds: []);
    expect(result.error, ErrorCodes.nodeConnectionError);
    expect(node.broadcasts, 0);
  });

  testWidgets('late tag success after the tag provider is disposed is ignored', (tester) async {
    final original = tags;
    final disposable = UtxoTagProvider(repository);
    tags = disposable;
    await tester.runAsync(() => initialize());
    tags = original;
    final completion = Completer<Result<void>>();
    repository.onApply = () => completion.future;
    Result<String>? outcome;
    viewModel.broadcast(inheritedTagIds: []).then((value) => outcome = value);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(outcome?.isSuccess, isTrue);
    expect(viewModel.tagInheritanceFailed, isTrue);
    disposable.dispose();
    completion.complete(Result<void>.success(null));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(node.broadcasts, 1);
  });

  testWidgets('tag failure returned before the limit is reported without delay', (tester) async {
    await tester.runAsync(() => initialize());
    repository.onApply = () async => Result<void>.failure(ErrorCodes.realmException);
    Result<String>? outcome;
    viewModel.broadcast(inheritedTagIds: []).then((value) => outcome = value);
    await tester.pump();
    expect(outcome?.isSuccess, isTrue);
    expect(viewModel.tagInheritanceFailed, isTrue);
    expect(tags.isUpdatedTagList, isFalse);
  });

  for (final lateFailure in [false, true]) {
    testWidgets('draft cleanup waits a bounded time and absorbs late results (failure=$lateFailure)', (tester) async {
      final drafts = _PendingDraftRepository();
      await tester.runAsync(() => initialize(drafts: drafts, unsignedDraftId: 123));
      var finished = false;
      viewModel.deleteDraftsIfNeeded().then((_) => finished = true);
      await tester.pump();
      expect(drafts.deleted, [123]);
      await tester.pump(const Duration(seconds: 4));
      expect(finished, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(finished, isTrue);
      if (lateFailure) {
        drafts.completion.completeError(StateError('late cleanup failure'));
      } else {
        drafts.completion.complete(Result<void>.success(null));
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  for (final lateFailure in [false, true]) {
    testWidgets('tag timeout preserves send success and observes late result (failure=$lateFailure)', (tester) async {
      await tester.runAsync(() => initialize());
      final completion = Completer<Result<void>>();
      repository.onApply = () => completion.future;
      Result<String>? outcome;
      viewModel.broadcast(inheritedTagIds: []).then((value) => outcome = value);
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(outcome, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(outcome?.isSuccess, isTrue);
      expect(viewModel.tagInheritanceFailed, isTrue);
      expect(node.broadcasts, 1);
      expect(tags.isUpdatedTagList, isFalse);
      if (lateFailure) {
        completion.completeError(StateError('late database failure'));
      } else {
        completion.complete(Result<void>.success(null));
      }
      await tester.pump();
      expect(tags.isUpdatedTagList, !lateFailure);
      expect(node.broadcasts, 1);
      expect(tester.takeException(), isNull);
    });
  }

  test('normal broadcast persists input tags on a PSBT-owned output and clears only consumed links', () async {
    addTag('savings', inputId);
    addTag('unrelated', 'another-utxo');
    addTag('other-wallet', inputId, walletId: 2);
    await initialize(returnPsbt: true);
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), ['savings']);

    final result = await viewModel.broadcast(inheritedTagIds: ['savings']);

    expect(result.isSuccess, isTrue);
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
    expect((await viewModel.broadcast(inheritedTagIds: ['savings'])).isFailure, isTrue);
    expect(tagIds(inputId), ['savings']);
    expect(tagIds(targetId()), isEmpty);

    manager.realm.write(() => manager.realm.find<RealmUtxoTag>('savings')!.utxoIdList.clear());
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), ['savings']);
    node.fails = false;
    expect((await viewModel.broadcast(inheritedTagIds: ['savings'])).isSuccess, isTrue);
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
    await initialize();
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
    await initialize();
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

    await initialize(outputAmount: 998000);
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
    await initializeTransaction(secondBump);
    const expectedTags = ['savings', 'reviewed', 'salary'];
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), unorderedEquals(expectedTags));
    expect((await viewModel.broadcast(inheritedTagIds: expectedTags)).isSuccess, isTrue);
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
    expect((await viewModel.broadcast(inheritedTagIds: ['savings'])).isSuccess, isTrue);
    expect(viewModel.tagInheritanceFailed, isTrue);
    expect(node.broadcasts, 1);
  });
}
