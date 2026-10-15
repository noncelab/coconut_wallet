import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/services/security/hot_wallet_authenticator.dart';
import 'package:coconut_wallet/services/security/hot_wallet_unlock_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthenticator implements HotWalletAuthenticator {
  _FakeAuthenticator(this.result);

  final bool result;

  @override
  Future<bool> authenticate() async => result;
}

class _FakeSecretRepository extends Fake implements HotWalletSecretRepository {
  int unlockCallCount = 0;

  @override
  Future<HotWalletPlaintext> unlockAfterAuthentication(String storageKey) async {
    unlockCallCount++;
    return HotWalletPlaintext(
      mnemonic: Uint8List.fromList(utf8.encode('mnemonic')),
      passphrase: Uint8List.fromList(utf8.encode('passphrase')),
    );
  }
}

void main() {
  test('인증에 성공한 경우에만 secret을 복호화한다', () async {
    final repository = _FakeSecretRepository();
    final service = HotWalletUnlockService(authenticator: _FakeAuthenticator(true), secretRepository: repository);

    final result = await service.unlock('storage-key');

    expect(result, isNotNull);
    expect(repository.unlockCallCount, 1);
  });

  test('인증 취소 시 secret에 접근하지 않는다', () async {
    final repository = _FakeSecretRepository();
    final service = HotWalletUnlockService(authenticator: _FakeAuthenticator(false), secretRepository: repository);

    final result = await service.unlock('storage-key');

    expect(result, isNull);
    expect(repository.unlockCallCount, 0);
  });
}
