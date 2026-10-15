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
}
