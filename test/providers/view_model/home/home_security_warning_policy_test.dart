import 'package:coconut_wallet/providers/view_model/home/home_security_warning_policy.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryDismissRepository implements HomeSecurityWarningDismissRepository {
  final Map<HomeSecurityWarningType, int> values = {};

  @override
  int getDismissedAt(HomeSecurityWarningType type) => values[type] ?? 0;

  @override
  Future<void> setDismissedAt(HomeSecurityWarningType type, int timestamp) async {
    values[type] = timestamp;
  }
}

void main() {
  final now = DateTime(2026, 9, 10);

  test('미백업 핫월렛 경고를 앱 잠금 경고보다 우선한다', () {
    final policy = HomeSecurityWarningPolicy(dismissRepository: _MemoryDismissRepository(), now: () => now);

    final state = policy.resolve(
      unbackedHotWalletId: 7,
      hasHotWalletWithBalance: true,
      isAppLockEnabled: false,
      shouldShowOpenStoreIntro: true,
    );

    expect(state.visibleWarning, HomeSecurityWarningType.unbackedHotWallet);
    expect(state.targetWalletId, 7);
    expect(state.showOpenStoreIntro, isFalse);
  });

  test('미백업 경고를 닫으면 앱 잠금 경고를 다음 경고로 표시한다', () async {
    final repository = _MemoryDismissRepository();
    final policy = HomeSecurityWarningPolicy(dismissRepository: repository, now: () => now);

    await policy.dismiss(
      HomeSecurityWarningType.unbackedHotWallet,
      hasHotWalletWithBalance: true,
      isAppLockEnabled: false,
    );
    final state = policy.resolve(
      unbackedHotWalletId: 7,
      hasHotWalletWithBalance: true,
      isAppLockEnabled: false,
      shouldShowOpenStoreIntro: true,
    );

    expect(state.visibleWarning, HomeSecurityWarningType.appLock);
    expect(state.showWarningAfterPrevious, isTrue);
    expect(repository.values[HomeSecurityWarningType.unbackedHotWallet], now.millisecondsSinceEpoch);
  });

  test('표시할 보안 경고가 없으면 오픈스토어 노출 정책을 반환한다', () {
    final policy = HomeSecurityWarningPolicy(dismissRepository: _MemoryDismissRepository(), now: () => now);

    final state = policy.resolve(
      unbackedHotWalletId: null,
      hasHotWalletWithBalance: false,
      isAppLockEnabled: true,
      shouldShowOpenStoreIntro: true,
    );

    expect(state.visibleWarning, isNull);
    expect(state.showOpenStoreIntro, isTrue);
  });
}
