import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realm/realm.dart';

import 'test_realm_manager.dart';

/// Repository 테스트를 위한 헬퍼 클래스
///
/// 이 클래스는 Realm 의존성이 있는 Repository 클래스를 테스트하기 위한 기본 설정을 제공합니다.
/// 각 테스트 클래스에서 상속받아 사용할 수 있습니다.
abstract class RepositoryTestHelper<T extends BaseRepository> {
  late TestRealmManager realmManager;
  late T repository;

  /// 테스트 대상 Repository 인스턴스를 생성합니다.
  ///
  /// 상속받은 클래스에서 구현해야 합니다.
  T createRepository(RealmManager realmManager);

  /// 테스트 전 초기화 작업을 수행합니다.
  Future<void> setUp() async {
    // 테스트용 RealmManager 생성
    realmManager = await setupTestRealmManager();

    // Repository 생성
    repository = createRepository(realmManager);
  }

  /// 테스트 후 정리 작업을 수행합니다.
  void tearDown() {
    realmManager.reset();
    realmManager.realm.close();
  }

  /// 테스트 데이터를 Realm에 추가합니다.
  void addTestData<E extends RealmObject>(List<E> objects) {
    realmManager.realm.write(() {
      for (var object in objects) {
        realmManager.realm.add<E>(object);
      }
    });
  }
}

/// 사용 예시:
///
/// ```dart
/// class WalletRepositoryTest extends RepositoryTestHelper<WalletRepository> {
///   @override
///   WalletRepository createRepository(RealmManager realmManager) {
///     return WalletRepository(realmManager);
///   }
///
///   void main() {
///     setUp(() async {
///       await super.setUp();
///       // 추가 설정...
///     });
///
///     tearDown(() {
///       super.tearDown();
///     });
///
///     test('getWallets 메서드 테스트', () {
///       // 테스트 코드...
///     });
///   }
/// }
/// ```
