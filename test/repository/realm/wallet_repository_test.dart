import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_realm_manager.dart';

void main() {
  late TestRealmManager realmManager;
  late WalletRepository walletRepository;

  setUp(() async {
    // 테스트용 RealmManager 생성
    realmManager = await setupTestRealmManager();

    // WalletRepository 생성
    walletRepository = WalletRepository(realmManager);
  });

  tearDown(() {
    // 테스트 후 정리
    realmManager.reset();
    realmManager.realm.close();
  });

  group('WalletRepository 테스트', () {
    test('지갑 삭제 테스트', () async {
      // Given
      final walletBase = RealmWalletBase(1, 0, 0, 'encrypted_descriptor',
          'Test Wallet', WalletType.singleSignature.name);

      realmManager.realm.write(() {
        realmManager.realm.add(walletBase);
      });

      // When
      await walletRepository.deleteWallet(1);

      // Then
      final walletResults = realmManager.realm.all<RealmWalletBase>();
      expect(walletResults.length, 0);
    });
  });
}
