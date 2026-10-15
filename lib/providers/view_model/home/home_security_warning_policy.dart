import 'package:coconut_wallet/constants/security_warning_constants.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';

enum HomeSecurityWarningType { unbackedHotWallet, appLock }

class HomeSecurityWarningState {
  const HomeSecurityWarningState({
    required this.visibleWarning,
    required this.showOpenStoreIntro,
    this.targetWalletId,
    this.showWarningAfterPrevious = false,
    this.showOpenStoreAfterWarning = false,
  });

  final HomeSecurityWarningType? visibleWarning;
  final bool showOpenStoreIntro;
  final int? targetWalletId;
  final bool showWarningAfterPrevious;
  final bool showOpenStoreAfterWarning;
}

abstract interface class HomeSecurityWarningDismissRepository {
  int getDismissedAt(HomeSecurityWarningType type);
  Future<void> setDismissedAt(HomeSecurityWarningType type, int timestamp);
}

class SharedPrefsHomeSecurityWarningDismissRepository implements HomeSecurityWarningDismissRepository {
  SharedPrefsHomeSecurityWarningDismissRepository({SharedPrefsRepository? sharedPrefs})
    : _sharedPrefs = sharedPrefs ?? SharedPrefsRepository();

  final SharedPrefsRepository _sharedPrefs;

  @override
  int getDismissedAt(HomeSecurityWarningType type) => _sharedPrefs.getInt(_dismissedAtKey(type));

  @override
  Future<void> setDismissedAt(HomeSecurityWarningType type, int timestamp) =>
      _sharedPrefs.setInt(_dismissedAtKey(type), timestamp);

  String _dismissedAtKey(HomeSecurityWarningType type) => switch (type) {
    HomeSecurityWarningType.unbackedHotWallet => SharedPrefKeys.kUnbackedHotWalletWarningDismissedAt,
    HomeSecurityWarningType.appLock => SharedPrefKeys.kAppLockWarningDismissedAt,
  };
}

class HomeSecurityWarningPolicy {
  HomeSecurityWarningPolicy({HomeSecurityWarningDismissRepository? dismissRepository, DateTime Function()? now})
    : _dismissRepository = dismissRepository ?? SharedPrefsHomeSecurityWarningDismissRepository(),
      _now = now ?? DateTime.now;

  final HomeSecurityWarningDismissRepository _dismissRepository;
  final DateTime Function() _now;
  final Set<HomeSecurityWarningType> _dismissedThisSession = {};
  HomeSecurityWarningType? _nextWarningAfterDismissal;
  bool _showOpenStoreAfterWarning = false;

  HomeSecurityWarningState resolve({
    required int? unbackedHotWalletId,
    required bool hasHotWalletWithBalance,
    required bool isAppLockEnabled,
    required bool shouldShowOpenStoreIntro,
  }) {
    final warning =
        unbackedHotWalletId != null && canShow(HomeSecurityWarningType.unbackedHotWallet)
            ? HomeSecurityWarningType.unbackedHotWallet
            : hasHotWalletWithBalance && !isAppLockEnabled && canShow(HomeSecurityWarningType.appLock)
            ? HomeSecurityWarningType.appLock
            : null;
    return HomeSecurityWarningState(
      visibleWarning: warning,
      targetWalletId: warning == HomeSecurityWarningType.unbackedHotWallet ? unbackedHotWalletId : null,
      showOpenStoreIntro: warning == null && shouldShowOpenStoreIntro,
      showWarningAfterPrevious: warning != null && warning == _nextWarningAfterDismissal,
      showOpenStoreAfterWarning: _showOpenStoreAfterWarning,
    );
  }

  bool canShow(HomeSecurityWarningType type) {
    if (_dismissedThisSession.contains(type)) return false;
    final dismissedAt = _dismissRepository.getDismissedAt(type);
    return dismissedAt == 0 ||
        _now().millisecondsSinceEpoch - dismissedAt >= kSecurityWarningDismissDuration.inMilliseconds;
  }

  Future<void> dismiss(
    HomeSecurityWarningType type, {
    required bool hasHotWalletWithBalance,
    required bool isAppLockEnabled,
  }) async {
    _dismissedThisSession.add(type);
    await _dismissRepository.setDismissedAt(type, _now().millisecondsSinceEpoch);
    final showNext =
        type == HomeSecurityWarningType.unbackedHotWallet &&
        hasHotWalletWithBalance &&
        !isAppLockEnabled &&
        canShow(HomeSecurityWarningType.appLock);
    _nextWarningAfterDismissal = showNext ? HomeSecurityWarningType.appLock : null;
    _showOpenStoreAfterWarning = !showNext;
  }
}
