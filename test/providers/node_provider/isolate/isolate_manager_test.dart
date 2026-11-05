import 'dart:async';
import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/model/node/spawn_isolate_dto.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_manager.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the node isolate (Electrum connection, Realm): the test decides when the spawn finishes and what
/// the isolate reports. The spawned isolate does nothing until it is killed, which [exited] reports.
class _Spawn {
  final requested = Completer<SpawnIsolateDto>();
  final ready = Completer<void>();
  final exited = ReceivePort();

  Future<Isolate> call(void Function(SpawnIsolateDto) entryPoint, SpawnIsolateDto data) async {
    requested.complete(data);
    await ready.future;
    return Isolate.spawn(_idle, null, onExit: exited.sendPort);
  }
}

// An open port keeps the isolate alive, so it exits only when the manager kills it.
void _idle(Object? _) {
  ReceivePort();
}

class _Wallet extends Fake implements WalletItemBase {}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  bool online = false;

  @override
  bool get isInternetOn => online;
  @override
  bool get isInternetOff => !online;
}

// An error completed before anyone listens is reported as uncaught, which fails these tests by itself.
void main() {
  // The spawn is fake: nothing connects to this address.
  Future<void> initialize(IsolateManager manager) => manager.initialize('127.0.0.1', 50001, false, NetworkType.regtest);
  final closedBeforeReady = isA<Exception>().having(
    (e) => '$e',
    'message',
    contains('closed before initialization completed'),
  );

  for (final crossErrorZone in [false, true]) {
    test('ten pending commands settle on close across error zones=$crossErrorZone', () async {
      final spawn = _Spawn();
      addTearDown(spawn.exited.close);
      final creationErrors = <Object>[];
      final consumerErrors = <Object>[];
      final initDone = Completer<void>();
      Object? initError;
      late Zone creationZone;
      late IsolateManager manager;
      runZonedGuarded(() {
        creationZone = Zone.current;
        manager = IsolateManager(spawnIsolate: spawn.call);
        unawaited(() async {
          try {
            await initialize(manager);
          } catch (error) {
            initError = error;
          } finally {
            initDone.complete();
          }
        }());
      }, (error, _) => creationErrors.add(error));
      await spawn.requested.future;

      final consumerZone =
          crossErrorZone
              ? creationZone.fork(
                specification: ZoneSpecification(
                  handleUncaughtError: (_, __, ___, error, ____) => consumerErrors.add(error),
                ),
              )
              : creationZone;
      expect(creationZone.inSameErrorZone(consumerZone), !crossErrorZone);
      final commands = List.generate(10, (_) => Completer<Result<bool>>());
      for (final command in commands) {
        consumerZone.run(() async {
          command.complete(await manager.syncDormantAddresses(_Wallet()));
        });
      }
      await creationZone.run(manager.closeIsolate);
      spawn.ready.complete();
      await initDone.future.timeout(const Duration(seconds: 3));
      await spawn.exited.first.timeout(const Duration(seconds: 3));
      final results = await Future.wait(commands.map((command) => command.future)).timeout(const Duration(seconds: 6));

      expect(initError, closedBeforeReady);
      expect(manager.isInitialized, false);
      expect(creationErrors, isEmpty, reason: 'shared readiness must not report errors in its creation zone');
      expect(consumerErrors, isEmpty);
      expect(results, hasLength(10));
      for (final result in results) {
        expect(result.isFailure, true);
        expect(result.error, ErrorCodes.nodeUnknown, reason: 'close Exception retains the existing error mapping');
      }
    });
  }

  test('a concurrent initialize in a foreign error zone receives the close error', () async {
    final spawn = _Spawn();
    addTearDown(spawn.exited.close);
    final uncaught = <Object>[];
    final firstDone = Completer<void>();
    final secondDone = Completer<bool>();
    final failures = <Object>[];
    late Zone creationZone;
    late IsolateManager manager;
    runZonedGuarded(() {
      creationZone = Zone.current;
      manager = IsolateManager(spawnIsolate: spawn.call);
      unawaited(() async {
        try {
          await initialize(manager);
        } catch (error) {
          failures.add(error);
        } finally {
          firstDone.complete();
        }
      }());
    }, (error, _) => uncaught.add(error));
    await spawn.requested.future;
    final consumerZone = creationZone.fork(
      specification: ZoneSpecification(handleUncaughtError: (_, __, ___, error, ____) => uncaught.add(error)),
    );
    expect(creationZone.inSameErrorZone(consumerZone), false);
    consumerZone.run(() async {
      try {
        await initialize(manager);
      } catch (error) {
        failures.add(error);
      } finally {
        secondDone.complete(true);
      }
    });
    await creationZone.run(manager.closeIsolate);
    spawn.ready.complete();
    await firstDone.future.timeout(const Duration(seconds: 3));
    await spawn.exited.first.timeout(const Duration(seconds: 3));
    final settled = await secondDone.future.timeout(const Duration(seconds: 2), onTimeout: () => false);

    expect(uncaught, isEmpty);
    expect(settled, true, reason: 'a concurrent initialize must not be stranded across error zones');
    expect(failures, hasLength(2));
    expect(failures, everyElement(closedBeforeReady));
    expect(manager.isInitialized, false);
  });

  test('closing while the isolate is still spawning rejects initialize with the close error', () async {
    final spawn = _Spawn();
    addTearDown(spawn.exited.close);
    final manager = IsolateManager(spawnIsolate: spawn.call);

    final initialization = initialize(manager);
    await spawn.requested.future;
    await manager.closeIsolate();
    spawn.ready.complete();

    await expectLater(initialization, throwsA(closedBeforeReady));
    await spawn.exited.first;
    expect(manager.isInitialized, false);
  });

  test('an initialization failure reported by the isolate still reaches the initialize caller', () async {
    final spawn = _Spawn()..ready.complete();
    addTearDown(spawn.exited.close);
    final manager = IsolateManager(spawnIsolate: spawn.call);

    final initialization = initialize(manager);
    (await spawn.requested.future).isolateToMainSendPort.send([IsolateManagerCommand.initializationFailed]);

    await expectLater(
      initialization,
      throwsA(isA<Exception>().having((e) => '$e', 'message', contains('Initialization failed'))),
    );
    await spawn.exited.first;
    expect(manager.isInitialized, false);
  });

  test('a later initialization after a cancelled one connects, and closeIsolate shuts it down', () async {
    final cancelled = _Spawn();
    final connected = _Spawn()..ready.complete();
    final spawns = [cancelled, connected];
    final isolateSide = ReceivePort();
    addTearDown(cancelled.exited.close);
    addTearDown(connected.exited.close);
    addTearDown(isolateSide.close);
    final manager = IsolateManager(spawnIsolate: (entryPoint, data) => spawns.removeAt(0).call(entryPoint, data));

    final first = initialize(manager);
    await cancelled.requested.future;
    await manager.closeIsolate();
    cancelled.ready.complete();
    await expectLater(first, throwsA(closedBeforeReady));
    await cancelled.exited.first;

    final second = initialize(manager);
    (await connected.requested.future).isolateToMainSendPort.send([
      IsolateManagerCommand.initializationCompleted,
      isolateSide.sendPort,
    ]);
    await second;
    expect(manager.isInitialized, true);

    // Acknowledges the graceful shutdown request the way IsolateController does.
    final shutdown = isolateSide.first.then((message) {
      final request = message as List;
      (request[1] as SendPort).send(true);
      return request[0];
    });
    await manager.closeIsolate();
    expect(await shutdown, IsolateControllerCommand.shutdown);
    await connected.exited.first;
    expect(manager.isInitialized, false);
  });

  test('disposing NodeProvider while its isolate is still spawning leaves no uncaught error', () async {
    final spawn = _Spawn();
    addTearDown(spawn.exited.close);
    final connectivity = _Connectivity();
    final provider = NodeProvider(
      const ElectrumServer('unused.example', 50002, true),
      NetworkType.regtest,
      connectivity,
      ValueNotifier(WalletLoadState.loadingFromDB),
      ValueNotifier<List<WalletItemBase>>([]),
      null,
      isolateManager: IsolateManager(spawnIsolate: spawn.call),
    );
    connectivity.online = true;

    final initialization = provider.initialize();
    await spawn.requested.future;
    provider.dispose();
    spawn.ready.complete();

    await initialization;
    await spawn.exited.first;
  });
}
