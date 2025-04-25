import 'package:coconut_wallet/constants/realm_constants.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/home/wallet_list_screen.dart';
import 'package:realm/realm.dart';
import 'integration_test_utils.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coconut_wallet/main.dart' as app;

/// Realm migration integration test
///
/// * 테스트는 어플이 삭제된 상태에서 실행되어야 합니다(기존 앱에서 사용하고 있는 스키마 버전보다 낮은 버전을 설정하여 오류 발생)
/// * 테스트는 각 테스트별 하나씩 실행되어야 합니다(한번에 테스트시 동일경로 Config를 여러번 open하여 오류 발생)
///
/// 실행 명령어:
/// ```bash
/// flutter test --plain-name "[Migration O] [Wallet O]" --flavor regtest integration_test/realm_migration_test.dart
/// flutter test --plain-name "[Migration O] [Wallet X]" --flavor regtest integration_test/realm_migration_test.dart
/// flutter test --plain-name "[Migration X] [Wallet O]" --flavor regtest integration_test/realm_migration_test.dart
/// flutter test --plain-name "[Migration X] [Wallet X]" --flavor regtest integration_test/realm_migration_test.dart
/// ```
///
/// 자세한 내용은 README.md 참고
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late RealmManager realmManager;
  late Configuration config;
  late Realm realm;

  void closeRealm() {
    if (!realm.isClosed) {
      realm.close();
    }
  }

  Future<void> realmDataSetup({required bool migration, required bool wallet}) async {
    const oldVersion = kRealmVersion - 1;
    const curVersion = kRealmVersion;
    config = Configuration.local(
      realmAllSchemas,
      schemaVersion: migration ? oldVersion : curVersion,
    );

    realm = Realm(config);
    realmManager = RealmManager(realm: realm);
    realmManager.reset();

    await setWalletData(wallet, realmManager: realmManager);
    closeRealm();
  }

  setUp(() async {
    final prefs = SharedPrefsRepository();
    await prefs.init();
    await prefs.clearSharedPref();
    await SecureStorageRepository().deleteAll();
  });

  tearDown(() async {
    closeRealm();
  });

  group("removeIsLatestTxBlockHeightZero test", () {
    setUp(() async {
      await skipTutorial(true);
    });

    testWidgets('[Migration O] [Wallet O]', (tester) async {
      // Set realm configuration and Wallet Data
      await realmDataSetup(migration: true, wallet: true);
      // The app will use new realm Configuration(kRealmVersion, removeIsLatestTxBlockHeightZero function) for migration
      await walletListFlow(tester);
    });

    testWidgets('[Migration O] [Wallet X]', (tester) async {
      await realmDataSetup(migration: true, wallet: false);
      await walletListFlow(tester);
    });

    testWidgets('[Migration X] [Wallet O]', (tester) async {
      await realmDataSetup(migration: false, wallet: true);
      await walletListFlow(tester);
    });

    testWidgets('[Migration X] [Wallet X]', (tester) async {
      await realmDataSetup(migration: false, wallet: false);
      await walletListFlow(tester);
    });
  });
}

Future<void> walletListFlow(WidgetTester tester) async {
  app.main();
  await tester.pumpAndSettle();

  final Finder walletListScreen = find.byType(WalletListScreen);
  await waitForWidget(tester, walletListScreen,
      timeoutMessage: 'walletListScreen not found after 60 seconds');
  await tester.pumpAndSettle();
}
