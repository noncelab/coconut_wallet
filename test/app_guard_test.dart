import 'package:coconut_wallet/app_guard.dart';
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
}
