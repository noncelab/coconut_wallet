import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_realm_manager.dart';

void main() {
  late TestRealmManager realmManager;

  setUp(() async {
    // 테스트 환경 설정
    await dotenv.load(fileName: 'regtest.env'); // 테스트용 환경 변수 로드

    // 테스트용 RealmManager 생성
    realmManager = TestRealmManager();
  });

  tearDown(() {
    // 테스트 후 정리
    realmManager.reset();
    realmManager.realm.close();
  });
}
