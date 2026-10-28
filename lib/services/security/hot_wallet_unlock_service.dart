import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/services/security/hot_wallet_authenticator.dart';

/// 핫월렛 평문에 접근하는 단일 인증 진입점이다.
///
/// 앱 잠금이 설정되어 있으면 생체인증을 우선 시도하고, 실패하거나 사용할 수
/// 없으면 앱 PIN으로 폴백한다. 인증을 취소하면 평문을 반환하지 않는다.
class HotWalletUnlockService {
  HotWalletUnlockService({required HotWalletAuthenticator authenticator, HotWalletSecretRepository? secretRepository})
    : _authenticator = authenticator,
      _secretRepository = secretRepository ?? HotWalletSecretRepository();

  final HotWalletAuthenticator _authenticator;
  final HotWalletSecretRepository _secretRepository;

  Future<HotWalletPlaintext?> unlock(String storageKey) async {
    if (!await _authenticator.authenticate()) return null;
    return _secretRepository.unlockAfterAuthentication(storageKey);
  }
}
