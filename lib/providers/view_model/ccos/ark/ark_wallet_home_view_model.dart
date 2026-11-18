import 'dart:typed_data';

import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/services/security/hot_wallet_authenticator.dart';

class ArkWalletHomeViewModel {
  ArkWalletHomeViewModel(this._wallet, this._authenticator);

  final ArkWalletProvider _wallet;
  final HotWalletAuthenticator _authenticator;

  /// 인증을 취소하면 null. 받는 쪽이 지워야 함
  Future<Uint8List?> unlockForBackup() async {
    if (!await _authenticator.authenticate()) return null;
    return _wallet.readMnemonicForBackup();
  }

  Future<void> finishBackup({required bool confirmed}) async {
    if (confirmed) await _wallet.markBackupVerified();
  }
}
