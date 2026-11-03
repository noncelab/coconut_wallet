import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(AppGuard.enablePrivacyScreen);

  test('작업 중에만 화면 보호를 끄고 완료 후 이전 활성 상태로 복원한다', () async {
    AppGuard.enablePrivacyScreen();

    final result = await AppGuard.runWithoutPrivacyScreen(() async {
      expect(AppGuard.isPrivacyEnabled, isFalse);
      return 'completed';
    });

    expect(result, 'completed');
    expect(AppGuard.isPrivacyEnabled, isTrue);
  });

  test('작업이 실패해도 화면 보호 상태를 복원한다', () async {
    AppGuard.enablePrivacyScreen();

    await expectLater(
      AppGuard.runWithoutPrivacyScreen<void>(() async {
        expect(AppGuard.isPrivacyEnabled, isFalse);
        throw StateError('failed');
      }),
      throwsStateError,
    );

    expect(AppGuard.isPrivacyEnabled, isTrue);
  });

  test('기존에 화면 보호가 꺼져 있었다면 작업 후에도 꺼진 상태를 유지한다', () async {
    AppGuard.disablePrivacyScreen();

    await AppGuard.runWithoutPrivacyScreen(() async {
      expect(AppGuard.isPrivacyEnabled, isFalse);
    });

    expect(AppGuard.isPrivacyEnabled, isFalse);
  });

  group('BackgroundResumePolicy', () {
    late DateTime now;
    late BackgroundResumePolicy policy;

    setUp(() {
      now = DateTime(2026, 11, 2, 12);
      policy = BackgroundResumePolicy(now: () => now);
    });

    ResumeConnectionCheck resumeAfter(Duration background) {
      policy.onPaused();
      now = now.add(background);
      return policy.onResumed();
    }

    test('30초 안에 돌아오면 연결을 확인하지 않는다', () {
      expect(resumeAfter(const Duration(seconds: 29)), ResumeConnectionCheck.none);
    });

    test('30초부터 5분 전까지는 소켓만 확인한다', () {
      expect(resumeAfter(const Duration(seconds: 30)), ResumeConnectionCheck.probeSocket);
      expect(resumeAfter(const Duration(minutes: 4, seconds: 59)), ResumeConnectionCheck.probeSocket);
    });

    test('5분 이상이면 모든 지갑을 다시 동기화한다', () {
      expect(resumeAfter(const Duration(minutes: 5)), ResumeConnectionCheck.resyncWallets);
      expect(resumeAfter(const Duration(hours: 3)), ResumeConnectionCheck.resyncWallets);
    });

    test('paused 없이 inactive → resumed만 거친 복귀에는 이전 백그라운드 시간을 다시 쓰지 않는다', () {
      expect(resumeAfter(const Duration(minutes: 6)), ResumeConnectionCheck.resyncWallets);

      now = now.add(const Duration(minutes: 10));
      expect(policy.onResumed(), ResumeConnectionCheck.none);
    });

    test('paused 기록 없이 resumed가 오면 연결을 확인하지 않는다', () {
      expect(policy.onResumed(), ResumeConnectionCheck.none);
    });
  });

  test('실패 상태로 백그라운드에 가며 닫힌 연결은 복귀 때 지갑 구독까지 다시 하도록 재연결한다', () async {
    final node = _ClosedNode();

    await AppGuard.reconnectNodeOnResume(node, ResumeConnectionCheck.none);

    expect(node.calls, ['resumeBlockUpdates', 'reconnect'], reason: 'initialize()만으로는 첫 초기화가 아니면 지갑을 구독하지 않는다');
  });

  // 리뷰 2차: 모든 복귀가 먼저 블록 확인 타이머를 되살린다(백그라운드에서 울린 재연결 대기 확인은 사라진다).
  // 재연결이 필요하면 그 뒤에 재연결한다.
  for (final (state, check, expected) in [
    (NodeSyncState.completed, ResumeConnectionCheck.none, ['resumeBlockUpdates']),
    (NodeSyncState.syncing, ResumeConnectionCheck.none, ['resumeBlockUpdates']),
    (NodeSyncState.completed, ResumeConnectionCheck.probeSocket, ['resumeBlockUpdates', 'getLatestBlock']),
    (NodeSyncState.failed, ResumeConnectionCheck.none, ['resumeBlockUpdates', 'reconnect']),
  ]) {
    test('복귀(${state.name}, ${check.name})는 $expected', () async {
      final node = _OpenNode(state);

      await AppGuard.reconnectNodeOnResume(node, check);

      expect(node.calls, expected);
    });
  }
}

/// 실패 상태에서 paused가 되어 AppGuard가 closeConnection()한 NodeProvider
class _ClosedNode extends Fake implements NodeProvider {
  final calls = <String>[];

  @override
  bool get isInitializing => false;

  @override
  bool get isInitialized => false;

  @override
  Future<void> initialize() async => calls.add('initialize');

  @override
  void resumeBlockUpdates() => calls.add('resumeBlockUpdates');

  @override
  Future<Result<bool>> reconnect() async {
    calls.add('reconnect');
    return Result.success(true);
  }
}

/// 연결이 열려 있는 NodeProvider
class _OpenNode extends Fake implements NodeProvider {
  _OpenNode(this._nodeSyncState);

  final NodeSyncState _nodeSyncState;
  final calls = <String>[];

  @override
  bool get isInitializing => false;

  @override
  bool get isInitialized => true;

  @override
  bool get hasConnectionError => false;

  @override
  NodeProviderState get state => NodeProviderState(nodeSyncState: _nodeSyncState, registeredWallets: const {});

  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async {
    calls.add('getLatestBlock');
    return Result.success(BlockTimestamp(1, DateTime(2026)));
  }

  @override
  void resumeBlockUpdates() => calls.add('resumeBlockUpdates');

  @override
  Future<Result<bool>> reconnect() async {
    calls.add('reconnect');
    return Result.success(true);
  }
}
