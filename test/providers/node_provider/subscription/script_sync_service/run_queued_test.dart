import 'package:flutter_test/flutter_test.dart';

import '../../../../mock/script_sync_service_mock.dart';

/// [ScriptSyncService.runQueued]가 실제로 지갑 ID별 직렬화를 보장하는지 검증한다.
/// SubscriptionService.subscribeWallet(외부 진입점, 배치 구독/동기화)과
/// ScriptSyncService.syncScriptStatus(라이브 이벤트)가
/// 서로 다른 진입점에서 호출되더라도 같은 지갑에 대해서는 동시에 실행되지 않아야 한다.
void main() {
  group('ScriptSyncService.runQueued 테스트', () {
    setUp(() {
      ScriptSyncServiceMock.init();
    });

    tearDown(() {
      ScriptSyncServiceMock.realmManager?.reset();
      ScriptSyncServiceMock.realmManager?.dispose();
    });

    test('같은 지갑 ID의 두 작업은 절대 동시에 실행되지 않고 도착 순서대로 처리된다', () async {
      final scriptSyncService = ScriptSyncServiceMock.createMockScriptSyncService();
      const walletId = 1;

      final executionLog = <String>[];
      var isRunning = false;

      Future<void> taskA() async {
        // 배치 구독(syncBatchScriptStatusList)처럼 시간이 걸리는 작업을 흉내낸다.
        expect(isRunning, false, reason: 'A 시작 시점에 이미 다른 작업이 돌고 있으면 안 된다.');
        isRunning = true;
        executionLog.add('A-start');
        await Future.delayed(const Duration(milliseconds: 100));
        executionLog.add('A-end');
        isRunning = false;
      }

      Future<void> taskB() async {
        // 라이브 이벤트(syncScriptStatus)처럼, A가 아직 끝나기 전에 도착한 작업을 흉내낸다.
        expect(isRunning, false, reason: 'A가 끝나기 전에 B가 시작되면 큐 직렬화가 깨진 것이다.');
        isRunning = true;
        executionLog.add('B-start');
        executionLog.add('B-end');
        isRunning = false;
      }

      // A를 먼저 큐에 태우고, A가 끝나기 전(await 없이) B를 곧바로 같은 지갑 ID로 큐에 태운다.
      final futureA = scriptSyncService.runQueued(walletId, taskA);
      final futureB = scriptSyncService.runQueued(walletId, taskB);

      await Future.wait([futureA, futureB]);

      expect(executionLog, ['A-start', 'A-end', 'B-start', 'B-end']);
    });

    test('다른 지갑 ID의 작업은 서로 막지 않고 동시에 실행된다', () async {
      final scriptSyncService = ScriptSyncServiceMock.createMockScriptSyncService();

      final executionLog = <String>[];

      Future<void> slowTaskForWallet1() async {
        executionLog.add('wallet1-start');
        await Future.delayed(const Duration(milliseconds: 100));
        executionLog.add('wallet1-end');
      }

      Future<void> fastTaskForWallet2() async {
        executionLog.add('wallet2-start');
        executionLog.add('wallet2-end');
      }

      final future1 = scriptSyncService.runQueued(1, slowTaskForWallet1);
      final future2 = scriptSyncService.runQueued(2, fastTaskForWallet2);

      await Future.wait([future1, future2]);

      // wallet1이 느려도 wallet2는 그걸 기다리지 않고 먼저 끝나야 한다(직렬화는 지갑별로만 적용됨).
      expect(executionLog.indexOf('wallet2-end'), lessThan(executionLog.indexOf('wallet1-end')));
    });

    test('한 작업이 예외를 던져도 큐가 끊기지 않고 다음 작업이 정상 실행된다', () async {
      final scriptSyncService = ScriptSyncServiceMock.createMockScriptSyncService();
      const walletId = 1;

      final executionLog = <String>[];

      Future<void> failingTask() async {
        executionLog.add('A-start');
        throw Exception('simulated failure');
      }

      Future<void> nextTask() async {
        executionLog.add('B-start');
      }

      final futureA = scriptSyncService.runQueued(walletId, failingTask);
      final futureB = scriptSyncService.runQueued(walletId, nextTask);

      // A의 실패는 A를 호출한 쪽에 전파되어야 한다.
      await expectLater(futureA, throwsA(isA<Exception>()));
      // B는 A의 실패와 무관하게 정상 실행되어야 한다.
      await futureB;

      expect(executionLog, ['A-start', 'B-start']);
    });
  });
}
