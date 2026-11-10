import 'dart:async';
import 'dart:convert';
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
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

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

  /// 주소 → 그 주소를 가진 앱 지갑 id(없으면 외부 주소)
  final addressOwners = <String, int>{};
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
  int? findWalletIdContainingAddress(String address) => addressOwners[address];
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

  /// 기기가 저장을 거절한다: 진짜 저장소처럼 기다리지 않는 기록은 메모리에 남고, 사용자 동작 기록은 던진다(M08)
  bool failWrites = false;
  final removed = <int>[];
  @override
  SafetyState load() => state;
  @override
  Future<SafetyState> update(SafetyState Function(SafetyState) change) async {
    if (!failWrites) writes++;
    return state = change(state);
  }

  @override
  Future<SafetyState> updateConfirmed(SafetyState Function(SafetyState) change, {void Function()? onLateSave}) async {
    if (failWrites) throw const SafetyStoreWriteException();
    writes++;
    return state = change(state);
  }

  @override
  Future<void> removeWallet(int walletId) async {
    removed.add(walletId);
    await update((s) => s.withoutWallet(walletId));
  }
}

/// 기기 저장소 대역. [accept]가 false면 안드로이드 commit()이 false를 돌려줄 때(저장 공간 가득 등)처럼 쓰기를 거절한다(M08).
/// 안드로이드처럼 거절된 값도 플랫폼 메모리 맵에는 남는다. [nativeCache]면 다시 읽을 때 그 맵을 돌려준다(디스크가 아니라).
/// 저장·불러오기는 진짜 길(SafetyStore → SharedPrefsRepository → shared_preferences)을 탄다
class SafetyDiskFake extends SharedPreferencesStorePlatform {
  final durableValues = <String, Object>{};
  final memoryValues = <String, Object>{};
  bool accept = true;
  bool nativeCache = false;

  /// 차례로 쓸 쓰기 결과(비면 [accept])
  final outcomes = <bool>[];

  /// 있으면 쓰기를 반영한 뒤 이 Future가 끝날 때까지 답을 미룬다(느린 기기). 끝나지 않는 Future면 멈춘 쓰기
  Future<void>? hold;

  @override
  Future<Map<String, Object>> getAll() async => Map.of(nativeCache ? memoryValues : durableValues);

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    memoryValues[key] = value;
    final saved = outcomes.isEmpty ? accept : outcomes.removeAt(0);
    if (saved) durableValues[key] = value;
    if (hold != null) await hold;
    return saved;
  }

  @override
  Future<bool> remove(String key) async {
    memoryValues.remove(key);
    durableValues.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    memoryValues.clear();
    durableValues.clear();
    return true;
  }

  /// 디스크에 실제로 남은 상태(앱을 다시 켜면 읽는 값)
  SafetyState get durable {
    final raw = durableValues['flutter.${SafetyStore.key}'];
    return raw == null
        ? SafetyState.initial()
        : SafetyState.fromJson(jsonDecode(raw as String) as Map<String, Object?>);
  }

  /// 앱 시작(다시 켜기)과 같은 순서로 이 저장소를 새로 읽어 연 SafetyStore
  Future<SafetyStore> open() async {
    SafetyStore.resetForTest();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = this;
    await SharedPrefsRepository().init();
    return SafetyStore(SharedPrefsRepository());
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
