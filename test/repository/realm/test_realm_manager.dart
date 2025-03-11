import 'dart:convert';

import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/realm/wallet_data_manager_cryptography.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:realm/realm.dart';

// SecureStorageRepository 모킹을 위한 어노테이션
@GenerateMocks([SecureStorageRepository])
import 'test_realm_manager.mocks.dart';

/// 테스트용 RealmManager 클래스
///
/// 인메모리 Realm 데이터베이스를 사용하여 테스트 환경을 제공합니다.
class TestRealmManager implements RealmManager {
  final Realm _realm;

  bool _isInitialized = false;
  WalletDataManagerCryptography? _cryptography;

  TestRealmManager()
      : _realm = Realm(
          Configuration.inMemory([
            RealmWalletBase.schema,
            RealmMultisigWallet.schema,
            RealmTransaction.schema,
            RealmIntegerId.schema,
            TempBroadcastTimeRecord.schema,
            RealmUtxoTag.schema,
            RealmWalletAddress.schema,
            RealmWalletBalance.schema,
            RealmScriptStatus.schema,
            RealmBlockTimestamp.schema,
            RealmUtxo.schema,
            RealmRbfHistory.schema,
            RealmCpfpHistory.schema,
          ]),
        );

  @override
  bool get isInitialized => _isInitialized;

  @override
  WalletDataManagerCryptography? get cryptography => _cryptography;

  @override
  Realm get realm => _realm;

  // 테스트에 필요한 추가 메서드 구현
  void setInitialized(bool value) {
    _isInitialized = value;
  }

  void setCryptography(WalletDataManagerCryptography? cryptography) {
    _cryptography = cryptography;
  }

  @override
  Future<void> init(bool isSetPin) async {
    _isInitialized = true;
    return Future.value();
  }

  @override
  void checkInitialized() {
    if (!_isInitialized) {
      throw StateError(
          'RealmManager is not initialized. Call initialize first.');
    }
  }

  @override
  void reset() {
    realm.write(() {
      realm.deleteAll<RealmWalletBase>();
      realm.deleteAll<RealmMultisigWallet>();
      realm.deleteAll<RealmTransaction>();
      realm.deleteAll<RealmUtxoTag>();
      realm.deleteAll<RealmWalletBalance>();
      realm.deleteAll<RealmWalletAddress>();
      realm.deleteAll<RealmUtxo>();
      realm.deleteAll<RealmScriptStatus>();
      realm.deleteAll<RealmBlockTimestamp>();
      realm.deleteAll<RealmIntegerId>();
      realm.deleteAll<TempBroadcastTimeRecord>();
      realm.deleteAll<RealmRbfHistory>();
      realm.deleteAll<RealmCpfpHistory>();
    });

    _isInitialized = false;
    _cryptography = null;
  }

  @override
  Future<void> encrypt(String hashedPin) async {
    // 테스트에서는 실제 암호화를 수행하지 않음
    return Future.value();
  }

  @override
  Future<void> decrypt() async {
    // 테스트에서는 실제 복호화를 수행하지 않음
    return Future.value();
  }

  @override
  void dispose() {
    realm.close();
  }
}

/// 테스트용 RealmManager 생성 헬퍼 함수
Future<TestRealmManager> setupTestRealmManager() async {
  final realmManager = TestRealmManager();
  realmManager.setInitialized(true);
  return realmManager;
}

/// 테스트용 WalletDataManagerCryptography 생성 헬퍼 함수
Future<WalletDataManagerCryptography> setupCryptography() async {
  final cryptography = WalletDataManagerCryptography();
  await cryptography.initialize(iterations: 1000, hashedPin: 'test_pin');
  return cryptography;
}

void main() {
  late TestRealmManager realmManager;
  late MockSecureStorageRepository mockStorageService;

  setUp(() async {
    // 테스트 환경 설정
    await dotenv.load(fileName: '.env.test'); // 테스트용 환경 변수 로드

    // Mock 객체 생성
    mockStorageService = MockSecureStorageRepository();

    // 테스트용 RealmManager 생성
    realmManager = TestRealmManager();
  });

  tearDown(() {
    // 테스트 후 정리
    realmManager.reset();
    realmManager.realm.close();
  });

  group('RealmManager 테스트', () {
    test('init 메서드가 올바르게 동작하는지 테스트', () async {
      // Given
      const hashedPin = 'hashedPin123';
      final nonce = base64Encode(List<int>.filled(16, 1));

      // Mock 설정
      when(mockStorageService.read(key: RealmManager.pinField))
          .thenAnswer((_) async => hashedPin);
      when(mockStorageService.read(key: RealmManager.nonceField))
          .thenAnswer((_) async => nonce);

      // When
      await realmManager.init(true);

      // Then
      expect(realmManager.isInitialized, true);
      expect(realmManager.cryptography, isNotNull);

      // Verify
      verify(mockStorageService.read(key: RealmManager.pinField)).called(1);
      verify(mockStorageService.read(key: RealmManager.nonceField)).called(1);
    });

    test('reset 메서드가 올바르게 동작하는지 테스트', () async {
      // Given
      realmManager.setInitialized(true);
      final cryptography = WalletDataManagerCryptography();
      realmManager.setCryptography(cryptography);

      // When
      realmManager.reset();

      // Then
      expect(realmManager.isInitialized, false);
      expect(realmManager.cryptography, isNull);
    });

    // 추가 테스트 케이스 작성...
  });
}
