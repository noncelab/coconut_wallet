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
/// flutter test --plain-name "[Migration X] [Wallet O]" --flavor regtest integration_test/realm_migration_test.dart &&
/// flutter test --plain-name "[Migration X] [Wallet X]" --flavor regtest integration_test/realm_migration_test.dart &&
/// flutter test --plain-name "[0 -> kRealmVersion] [Wallet O]" --flavor regtest integration_test/realm_migration_test.dart &&
/// flutter test --plain-name "[0 -> kRealmVersion] [Wallet X]" --flavor regtest integration_test/realm_migration_test.dart &&
/// flutter test --plain-name "[1 -> kRealmVersion] [Wallet O]" --flavor regtest integration_test/realm_migration_test.dart &&
/// flutter test --plain-name "[1 -> kRealmVersion] [Wallet X]" --flavor regtest integration_test/realm_migration_test.dart &&
/// flutter test --plain-name "[2 -> kRealmVersion] [Wallet O]" --flavor regtest integration_test/realm_migration_test.dart &&
/// flutter test --plain-name "[2 -> kRealmVersion] [Wallet X]" --flavor regtest integration_test/realm_migration_test.dart
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

  Future<void> realmDataSetup({required int initialVersion, required bool wallet}) async {
    config = Configuration.local(realmAllSchemas, schemaVersion: initialVersion);

    realm = Realm(config);
    realmManager = RealmManager(realm: realm);
    realmManager.reset();

    await setTwoSinglesAndOneMultiCoconutWallets(wallet, realmManager: realmManager);
    closeRealm();
  }

  setUp(() async {
    final prefs = SharedPrefsRepository();
    await prefs.init();
    await prefs.clearSharedPref();
    await SecureStorageRepository().deleteAll();
    await skipTutorial(true);
  });

  tearDown(() async {
    closeRealm();
  });

  group('Realm migration test', () {
    group("[Migration X]", () {
      testWidgets("[Migration X] [Wallet O]", (tester) async {
        await realmDataSetup(initialVersion: kRealmVersion, wallet: true);
        await walletListFlow(tester);
      });

      testWidgets("[Migration X] [Wallet X]", (tester) async {
        await realmDataSetup(initialVersion: kRealmVersion, wallet: false);
        await walletListFlow(tester);
      });
    });

    group("[Migration O]", () {
      testWidgets("[0 -> kRealmVersion] [Wallet O]", (tester) async {
        await realmDataSetup(initialVersion: 0, wallet: true);
        await walletListFlow(tester);
      });

      testWidgets("[0 -> kRealmVersion] [Wallet X]", (tester) async {
        await realmDataSetup(initialVersion: 0, wallet: false);
        await walletListFlow(tester);
      });

      testWidgets("[1 -> kRealmVersion] [Wallet O]", (tester) async {
        await realmDataSetup(initialVersion: 1, wallet: true);
        await walletListFlow(tester);
      });

      testWidgets("[1 -> kRealmVersion] [Wallet X]", (tester) async {
        await realmDataSetup(initialVersion: 1, wallet: false);
        await walletListFlow(tester);
      });

      testWidgets("[2 -> kRealmVersion] [Wallet O]", (tester) async {
        await realmDataSetup(initialVersion: 2, wallet: true);
        await walletListFlow(tester);
      });

      testWidgets("[2 -> kRealmVersion] [Wallet X]", (tester) async {
        await realmDataSetup(initialVersion: 2, wallet: false);
        await walletListFlow(tester);
      });
    });
  });
}

Future<void> walletListFlow(WidgetTester tester) async {
  app.main();
  await tester.pumpAndSettle();

  final Finder walletListScreen = find.byType(WalletListScreen);
  await waitForWidget(tester, walletListScreen, timeoutMessage: 'walletListScreen not found after 60 seconds');
  await tester.pumpAndSettle();
}
