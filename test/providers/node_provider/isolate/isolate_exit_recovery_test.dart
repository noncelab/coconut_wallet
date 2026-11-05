import 'dart:async';
import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/model/node/spawn_isolate_dto.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_manager.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Wallet extends Fake implements WalletItemBase {
  @override
  int get id => 1;
}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isInternetOn => true;
  @override
  bool get isInternetOff => false;
}

enum _Mode { normal, exitAfterInit, exitOnBlock }

/// 실제 명령 형식을 쓰는 작업 isolate. 블록·소켓 확인과 종료 요청에만 답하고, 다른 명령은 답하지 않는다(시간 초과까지
/// 기다리는 명령을 흉내).
void _worker((SpawnIsolateDto, _Mode) args) {
  final (dto, mode) = args;
  final commands = ReceivePort();
  dto.isolateToMainSendPort.send([IsolateManagerCommand.initializationCompleted, commands.sendPort]);
  if (mode == _Mode.exitAfterInit) Isolate.exit();
  commands.listen((dynamic request) {
    if (request is! List || request.length != 3) return;
    final reply = request[1] as SendPort;
    switch (request[0] as IsolateControllerCommand) {
      case IsolateControllerCommand.getSocketConnectionStatus:
        reply.send(Result<SocketConnectionStatus>.success(SocketConnectionStatus.connected));
      case IsolateControllerCommand.getLatestBlock:
        if (mode == _Mode.exitOnBlock) Isolate.exit(); // 다시 연결하자마자 하는 블록 확인에서 죽는 isolate
        reply.send(Result<BlockTimestamp>.success(BlockTimestamp(1, DateTime(2026))));
      case IsolateControllerCommand.subscribeWallets:
      case IsolateControllerCommand.subscribeWallet:
        reply.send(Result<bool>.success(true));
      case IsolateControllerCommand.shutdown:
        Isolate.exit(reply, Result<bool>.success(true));
      default:
        break; // 답하지 않음
    }
  });
}

class _Spawns {
  _Spawns([this.mode = _Mode.normal]);

  final _Mode mode;
  final List<Isolate> isolates = [];
  final List<SpawnIsolateDto> data = [];
  int failNext = 0; // 다음 띄우기를 이만큼 실패시킨다(서버·기기 문제로 초기화가 실패하는 경우)

  Future<Isolate> call(void Function(SpawnIsolateDto) _, SpawnIsolateDto dto, SendPort onExit) async {
    if (failNext > 0) {
      failNext--;
      throw Exception('spawn failed');
    }
    data.add(dto);
    final isolate = await Isolate.spawn(_worker, (dto, mode), onExit: onExit);
    isolates.add(isolate);
    return isolate;
  }
}

Future<void> _initialize(IsolateManager manager) => manager.initialize('127.0.0.1', 50001, false, NetworkType.regtest);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('작업 isolate가 스스로 끝나면 기다리던 명령이 바로 실패하고 한 번 알린다', () async {
    final spawns = _Spawns();
    final manager = IsolateManager(spawnIsolate: spawns.call);
    var exits = 0;
    manager.onUnexpectedExit = () => exits++;
    await _initialize(manager);
    addTearDown(manager.closeIsolate);

    final waiting = manager.syncDormantAddresses(_Wallet()); // 답이 없으면 180초를 기다리는 명령
    await pumpEventQueue();
    spawns.isolates.single.kill(priority: Isolate.immediate);

    final result = await waiting.timeout(const Duration(seconds: 3));
    expect(result.isFailure, isTrue);
    expect(result.error.code, ErrorCodes.nodeIsolateError.code, reason: '송금이면 결과 모름으로 다뤄 다시 보낸다');
    expect(exits, 1);
    expect(manager.isInitialized, isFalse);
    final later = await manager.syncDormantAddresses(_Wallet()).timeout(const Duration(seconds: 3));
    expect(later.isFailure, isTrue, reason: '죽은 isolate에 보내지 않고 바로 실패');
  });

  test('닫거나 다시 띄우며 끝낸 isolate는 예기치 않은 종료로 알리지 않는다', () async {
    final spawns = _Spawns();
    final manager = IsolateManager(spawnIsolate: spawns.call);
    var exits = 0;
    manager.onUnexpectedExit = () => exits++;
    await _initialize(manager);
    await _initialize(manager); // 재시작: 이전 isolate를 강제로 끝냄
    await manager.closeIsolate(); // 정상 종료 요청으로 스스로 끝남
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(spawns.isolates, hasLength(2));
    expect(exits, 0);
  });

  test('띄우자마자 끝나는 isolate도 놓치지 않는다(죽은 isolate를 연결된 것으로 두지 않음)', () async {
    for (var round = 0; round < 10; round++) {
      final manager = IsolateManager(spawnIsolate: _Spawns(_Mode.exitAfterInit).call);
      var exits = 0;
      manager.onUnexpectedExit = () => exits++;
      var initialized = true;
      try {
        await _initialize(manager);
      } catch (_) {
        initialized = false; // 초기화 중에 끝났으면 초기화 실패로 끝난다
      }
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (manager.isInitialized && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(manager.isInitialized, isFalse, reason: 'round $round');
      final result = await manager.syncDormantAddresses(_Wallet()).timeout(const Duration(seconds: 3));
      expect(result.isFailure, isTrue, reason: 'round $round');
      if (initialized) expect(exits, 1, reason: '초기화를 마친 뒤 끝났으면 알린다 (round $round)');
      await manager.closeIsolate();
    }
  });

  group('NodeProvider', () {
    late _Spawns spawns;
    late ValueNotifier<WalletLoadState> load;
    late ValueNotifier<List<WalletItemBase>> wallets;
    late NodeProvider node;

    Future<void> emit(IsolateStateMethod method, List<dynamic> params) async {
      spawns.data.last.isolateToMainSendPort.send([
        IsolateManagerCommand.updateState,
        [method, ...params],
      ]);
      await pumpEventQueue();
    }

    setUp(() async {
      spawns = _Spawns();
      load = ValueNotifier(WalletLoadState.loadingFromDB);
      wallets = ValueNotifier<List<WalletItemBase>>([_Wallet()]);
      node = NodeProvider(
        const ElectrumServer('unused.example', 50002, true),
        NetworkType.mainnet,
        _Connectivity(),
        load,
        wallets,
        null,
        isolateManager: IsolateManager(spawnIsolate: spawns.call),
      );
      await node.initialize();
      await emit(IsolateStateMethod.initWalletUpdateStatus, [1]);
      await emit(IsolateStateMethod.setWalletSyncQueueState, [1, false, 80000000]);
    });
    tearDown(() async {
      await node.closeConnection();
      node.dispose();
      load.dispose();
      wallets.dispose();
    });

    test('자동 재시도 중 작업 isolate가 죽어도 예약된 다시 띄우기(10초 안팎)로 다시 연결한다', () async {
      // 평소 동기화 실패 뒤 자동 재시도가 도는 중: 블록 확인이 실패해도 재연결을 미루는 상태
      await emit(IsolateStateMethod.setWalletSyncQueueState, [1, true, 80000000]);
      await emit(IsolateStateMethod.setWalletSyncQueueState, [1, false, null]);
      await emit(IsolateStateMethod.setWalletRetrying, [1, true]);
      await emit(IsolateStateMethod.setWalletSyncQueueState, [1, true, 80000000]);
      expect(node.state.nodeSyncState, NodeSyncState.failed);
      load.value = WalletLoadState.loadCompleted;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final spawnsBefore = spawns.isolates.length;

      spawns.isolates.last.kill(priority: Isolate.immediate);
      final deadline = DateTime.now().add(const Duration(seconds: 25));
      while (spawns.isolates.length == spawnsBefore && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      expect(spawns.isolates.length, spawnsBefore + 1, reason: '재시도 표시가 남아 있어도 죽은 isolate는 다시 띄운다');
    }, timeout: const Timeout(Duration(seconds: 40)));

    test('죽은 뒤 다시 띄우기가 한 번 실패해도 평소 재연결 대기로 결국 다시 연결한다', () async {
      load.value = WalletLoadState.loadCompleted;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final spawnsBefore = spawns.isolates.length;
      spawns.failNext = 1;

      spawns.isolates.last.kill(priority: Isolate.immediate);
      final deadline = DateTime.now().add(const Duration(seconds: 50));
      while (spawns.isolates.length == spawnsBefore && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(spawns.failNext, 0, reason: '예약된 다시 띄우기가 한 번 실패했다');
      expect(spawns.isolates.length, spawnsBefore + 1, reason: '죽은 표시가 남아 블록 확인의 재연결을 막으면 안 된다');
    }, timeout: const Timeout(Duration(seconds: 70)));

    test('동기화 중 작업 isolate가 죽으면 당겨서 새로고침이 바로 다시 연결한다', () async {
      await emit(IsolateStateMethod.setWalletSyncQueueState, [1, true, 80000000]);
      expect(node.state.nodeSyncState, NodeSyncState.syncing);
      final spawnsBefore = spawns.isolates.length;

      spawns.isolates.last.kill(priority: Isolate.immediate);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(node.hasConnectionError, isTrue);
      unawaited(node.refreshWallets());
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (spawns.isolates.length == spawnsBefore && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(spawns.isolates.length, spawnsBefore + 1, reason: '동기화 중이라고 기다리기만 하지 않는다');
    });
  });

  test('다시 띄우자마자 죽는 isolate도 연달아 다시 띄우지 않는다(대기 간격을 늘림)', () async {
    final spawns = _Spawns(_Mode.exitOnBlock);
    final load = ValueNotifier(WalletLoadState.loadCompleted);
    final wallets = ValueNotifier<List<WalletItemBase>>([_Wallet()]);
    final node = NodeProvider(
      const ElectrumServer('unused.example', 50002, true),
      NetworkType.mainnet,
      _Connectivity(),
      load,
      wallets,
      null,
      isolateManager: IsolateManager(spawnIsolate: spawns.call),
    );
    addTearDown(() async {
      await node.closeConnection();
      node.dispose();
      load.dispose();
      wallets.dispose();
    });
    await node.initialize();
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(spawns.isolates, hasLength(1), reason: '첫 다시 띄우기는 약 10초(±20%) 뒤');
    expect(node.hasConnectionError, isTrue);
  });
}
