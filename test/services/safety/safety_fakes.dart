import 'dart:async';
import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/wallet/wallet_lifecycle_event.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/shared_preference/safety_store.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

WalletItemBase safetyWallet({int id = 1, bool hot = false, bool backedUp = false, bool passphrase = false}) {
  final vault = SingleSignatureVault.fromEntropy(Uint8List(16));
  return SinglesigWalletItem(
    id: id,
    name: 'Test',
    colorIndex: 0,
    iconIndex: 0,
    descriptor: vault.descriptor,
    hotWalletMetadata:
        hot
            ? HotWalletMetadata(
              walletId: id,
              secureStorageKey: 'unused',
              masterFingerprint: vault.keyStore.masterFingerprint,
              derivationPath: vault.derivationPath,
              accountIndex: 0,
              backupVerified: backedUp,
              enterPassphraseWhenSigning: passphrase,
              createdAt: DateTime(2026),
            )
            : null,
  );
}

TransactionRecord safetyTx(
  String txid, {
  TransactionType type = TransactionType.sent,
  int height = 0,
  List<TransactionAddress> outputs = const [],
  DateTime? createdAt,
}) => TransactionRecord(
  txid,
  DateTime(2026, 2),
  height,
  type,
  null,
  1000,
  100,
  [],
  outputs,
  100,
  createdAt ?? DateTime(2026),
);

class SafetyWalletsFake extends ChangeNotifier implements WalletProvider {
  SafetyWalletsFake(List<WalletItemBase> wallets) : walletItemListNotifier = ValueNotifier(wallets);
  @override
  final walletLoadStateNotifier = ValueNotifier(WalletLoadState.loadCompleted);
  @override
  final ValueNotifier<List<WalletItemBase>> walletItemListNotifier;
  final events = StreamController<WalletLifecycleEvent>.broadcast();
  final records = <int, List<TransactionRecord>>{};
  final replaced = <String, TransactionRecord>{};
  final utxos = <int, List<UtxoState>>{};
  final ownedReceive = <String>{};
  final suspicious = <String>{};
  final balances = <int, Balance>{};
  final tags = <int, List<RealmUtxoTag>>{};
  final memos = <int, List<RealmTransactionMemo>>{};
  int collections = 0, addressLookups = 0;
  @override
  WalletLoadState get walletLoadState => walletLoadStateNotifier.value;
  @override
  List<WalletItemBase> get walletItemList => walletItemListNotifier.value;
  @override
  Stream<WalletLifecycleEvent> get lifecycleEvents => events.stream;
  @override
  WalletItemBase getWalletById(int id) => walletItemList.firstWhere((w) => w.id == id);
  @override
  List<TransactionRecord> getTransactionRecordList(int walletId) {
    collections++;
    return records[walletId] ?? [];
  }

  @override
  TransactionRecord? getTransactionRecord(int walletId, String txid) => replaced[txid];
  @override
  List<UtxoState> getUtxoList(int walletId) => utxos[walletId] ?? [];
  @override
  Balance getWalletBalance(int walletId) => balances[walletId] ?? Balance(0, 0);
  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) {
    addressLookups++;
    return ownedReceive.contains(address);
  }

  @override
  bool isUtxoSuspicious(UtxoState utxo, TransactionRecord? txRecord) => suspicious.contains(utxo.utxoId);
  @override
  List<RealmUtxoTag> getUtxoTags(int walletId) => tags[walletId] ?? [];
  @override
  List<RealmTransactionMemo> getAllTransactionMemos(int walletId) => memos[walletId] ?? [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  void dispose() {
    walletLoadStateNotifier.dispose();
    walletItemListNotifier.dispose();
    unawaited(events.close());
    super.dispose();
  }
}

class SafetyNodeFake extends ChangeNotifier implements NodeProvider {
  bool connected = true;
  int height = 100;
  int reconnects = 0;
  bool reconnectThrows = false;
  @override
  String host = 'custom.invalid';
  @override
  int port = 50002;
  @override
  bool ssl = true;
  @override
  String? pinnedCertFingerprint = 'pin';
  @override
  final currentBlockNotifier = ValueNotifier<BlockTimestamp?>(null);
  final sync = StreamController<NodeSyncState>.broadcast();
  final resync = <int, DateTime>{};
  @override
  NodeProviderState state = NodeProviderState(
    nodeSyncState: NodeSyncState.completed,
    registeredWallets: {
      1: WalletUpdateInfo(
        1,
        subscription: WalletSyncState.completed,
        balance: WalletSyncState.completed,
        transaction: WalletSyncState.completed,
        utxo: WalletSyncState.completed,
      ),
    },
  );
  @override
  bool get isConnected => connected;
  @override
  int get currentBlockHeight => height;
  @override
  Stream<NodeSyncState> get syncStateStream => sync.stream;
  @override
  DateTime? getLastResyncTimestamp(int walletId) => resync[walletId];
  @override
  Future<Result<bool>> reconnectIfNeeded() async {
    reconnects++;
    if (reconnectThrows) throw StateError('offline');
    return Result.success(true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  void dispose() {
    currentBlockNotifier.dispose();
    unawaited(sync.close());
    super.dispose();
  }
}

class SafetyAuthFake extends ChangeNotifier implements AuthProvider {
  bool enabled = true;
  @override
  bool get isAuthEnabled => enabled;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SafetyConnectivityFake extends ChangeNotifier implements ConnectivityProvider {
  bool connected = true;
  @override
  bool get isInternetOn => connected;
  @override
  bool get isInternetOff => !connected;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SafetyAnalyticsFake extends Fake implements AnalyticsService {
  final events = <({String name, Map<String, Object>? parameters})>[];
  @override
  Future<void> logEvent({required String eventName, Map<String, Object>? parameters}) async {
    events.add((name: eventName, parameters: parameters));
  }
}

class SafetyStoreFake extends Fake implements SafetyStore {
  SafetyState state = SafetyState.initial();
  int writes = 0;
  bool failWrites = false;
  final removed = <int>[];
  @override
  SafetyState load() => state;
  @override
  Future<SafetyState> update(SafetyState Function(SafetyState) change) async {
    if (failWrites) throw StateError('storage unavailable');
    writes++;
    return state = change(state);
  }

  @override
  Future<void> removeWallet(int walletId) async {
    removed.add(walletId);
    await update((s) => s.withoutWallet(walletId));
  }
}

class SafetySilentTlsPeer {
  SafetySilentTlsPeer._(this._server) {
    _connections = _server.listen((socket) {
      _sockets.add(socket);
      if (!accepted.isCompleted) accepted.complete();
      socket.listen(
        (_) {},
        onError: (Object error) {
          if (!disconnected.isCompleted) disconnected.complete();
        },
        onDone: () {
          if (!disconnected.isCompleted) disconnected.complete();
        },
      );
    });
  }

  final ServerSocket _server;
  final _sockets = <Socket>[];
  late final StreamSubscription<Socket> _connections;
  final accepted = Completer<void>();
  final disconnected = Completer<void>();
  int get port => _server.port;

  static Future<SafetySilentTlsPeer> start() async =>
      SafetySilentTlsPeer._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));

  Future<void> close() async {
    for (final socket in _sockets) {
      socket.destroy();
    }
    await _connections.cancel();
    await _server.close();
  }
}
