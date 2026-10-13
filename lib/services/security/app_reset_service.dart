import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/security/pin_auth_service.dart';

/// 초기화 승인 이후의 작업을 기록하고, 중단된 초기화는 잠금 해제 전에 끝냅니다.
/// 이 기록만으로 잠금을 해제하지 않고 보안 저장소·지갑·설정을 모두 초기화합니다.
class AppResetService {
  final SharedPrefsRepository _prefs = SharedPrefsRepository();

  bool get isPending => _prefs.getBool(SharedPrefKeys.kAppResetPending);

  Future<void> perform({
    required Future<void> Function() resetSecureStorage,
    required void Function() resetWallets,
  }) async {
    try {
      if (!await _prefs.sharedPrefs.setBool(SharedPrefKeys.kAppResetPending, true)) {
        throw const PinAuthException(PinAuthError.unavailable);
      }
      await resetSecureStorage();
      resetWallets();
      // 완료 표시보다 먼저 모두 지웁니다. 실패하면 다음 실행에서 다시 수행합니다.
      for (final key in SharedPrefKeys.keysToReset) {
        if (!await _prefs.sharedPrefs.remove(key)) {
          throw const PinAuthException(PinAuthError.unavailable);
        }
      }
      if (!await _prefs.sharedPrefs.remove(SharedPrefKeys.kAppResetPending)) {
        throw const PinAuthException(PinAuthError.unavailable);
      }
    } catch (_) {
      throw const PinAuthException(PinAuthError.unavailable);
    }
  }

  Future<void> recoverIfPending({
    required Future<void> Function() resetSecureStorage,
    required void Function() resetWallets,
  }) async {
    if (!isPending) return;
    await perform(resetSecureStorage: resetSecureStorage, resetWallets: resetWallets);
  }
}
