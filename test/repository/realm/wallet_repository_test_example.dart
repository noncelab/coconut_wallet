import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test_helper.dart';

class WalletRepositoryTest extends RepositoryTestHelper<WalletRepository> {
  @override
  WalletRepository createRepository(RealmManager realmManager) {
    return WalletRepository(realmManager);
  }

  void runTests() {
    group('WalletRepository 테스트', () {
      setUp(() async {
        await super.setUp();
      });

      tearDown(() {
        super.tearDown();
      });

      test('지갑 삭제 테스트', () async {
        // Given
        final walletBase = RealmWalletBase(1, 0, 0, 'encrypted_descriptor',
            'Test Wallet', WalletType.singleSignature.name);
        addTestData<RealmWalletBase>([walletBase]);

        // When
        await repository.deleteWallet(1);

        // Then
        final walletResults = realmManager.realm.all<RealmWalletBase>();
        expect(walletResults.length, 0);
      });
    });
  }
}

void main() {
  WalletRepositoryTest().runTests();
}
