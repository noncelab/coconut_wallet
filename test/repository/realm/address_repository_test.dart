import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/wallet_mock.dart';
import 'test_realm_manager.dart';

void main() {
  late TestRealmManager realmManager;
  late AddressRepository addressRepository;
  SinglesigWalletItem testWalletItem = WalletMock.createSingleSigWalletItem();
  late RealmWalletBase realmWalletBase;
  const int testWalletId = 1;

  List<WalletAddress> createTestAddresses({required bool isChange, required int startIndex}) {
    return List.generate(20, (index) {
      final addressIndex = startIndex + index;
      final address = testWalletItem.walletBase.getAddress(addressIndex, isChange: isChange);
      final derivationPath = '${testWalletItem.walletBase.derivationPath}${isChange ? '/1' : '/0'}/$addressIndex';

      return WalletAddress(address, derivationPath, addressIndex, isChange, false, 0, 0, 0);
    });
  }

  /// 실제 지갑 생성 시 초기에 receive/change 각각 20개 주소를 가지고 시작함.
  /// 이 환경을 그대로 재현했기 때문에 주소가 추가로 저장이 안되면 20개만 저장되어야 함.
  setUp(() async {
    realmManager = await setupTestRealmManager();
    realmWalletBase = RealmWalletBase(
      testWalletItem.id,
      testWalletItem.colorIndex,
      testWalletItem.iconIndex,
      testWalletItem.descriptor,
      testWalletItem.name,
      WalletType.singleSignature.name,
    );
    addressRepository = AddressRepository(realmManager);
    // 테스트용 지갑 생성
    realmManager.realm.write(() {
      realmManager.realm.add(realmWalletBase);
    });

    final initialAddresses = createTestAddresses(isChange: false, startIndex: 0);
    initialAddresses.addAll(createTestAddresses(isChange: true, startIndex: 0));
    realmManager.realm.write(() {
      realmManager.realm.addAll<RealmWalletAddress>([
        ...initialAddresses.map(
          (address) => RealmWalletAddress(
            getWalletAddressId(testWalletId, address.index, address.address),
            testWalletId,
            address.address,
            address.index,
            address.isChange,
            address.derivationPath,
            false,
            0,
            0,
            0,
          ),
        ),
      ]);
    });
  });

  tearDown(() {
    realmManager.reset();
    realmManager.dispose();
  });

  group('AddressRepository addAddressesWithGapLimit 테스트', () {
    // 테스트용 주소 생성 헬퍼 함수

    test('빈 주소 리스트가 전달되면 저장하지 않고 종료한다', () async {
      // Given
      realmManager.realm.write(() {
        realmWalletBase.usedReceiveIndex = -1;
        realmWalletBase.usedChangeIndex = -1;
        realmWalletBase.generatedReceiveIndex = 19;
        realmWalletBase.generatedChangeIndex = 19;
      });

      final emptyAddresses = <WalletAddress>[];

      // When
      await addressRepository.addAddressesWithGapLimit(
        walletItemBase: testWalletItem,
        newAddresses: emptyAddresses,
        isChange: false,
      );

      // Then
      final savedAddresses = realmManager.realm.query<RealmWalletAddress>('walletId == $testWalletId');
      expect(savedAddresses.length, equals(40));
    });

    test('generatedIndex - usedIndex >= 200이면 저장하지 않는다', () async {
      // Given
      realmManager.realm.write(() {
        realmWalletBase.usedReceiveIndex = -1;
        realmWalletBase.usedChangeIndex = -1;
        realmWalletBase.generatedReceiveIndex = 199;
        realmWalletBase.generatedChangeIndex = 19;
      });

      final testAddresses = createTestAddresses(isChange: false, startIndex: 200);

      // When
      await addressRepository.addAddressesWithGapLimit(
        walletItemBase: testWalletItem,
        newAddresses: testAddresses,
        isChange: false,
      );

      // Then
      final savedAddresses = realmManager.realm.query<RealmWalletAddress>('walletId == $testWalletId');
      expect(savedAddresses.length, equals(40));
    });

    test('연속되지 않은 인덱스의 주소는 저장하지 않는다 (추가하려는 인덱스가 큰 경우)', () async {
      // Given
      realmManager.realm.write(() {
        realmWalletBase.usedReceiveIndex = -1;
        realmWalletBase.usedChangeIndex = -1;
        realmWalletBase.generatedReceiveIndex = 19;
        realmWalletBase.generatedChangeIndex = 19;
      });

      final testAddresses = createTestAddresses(isChange: false, startIndex: 21);

      // When
      await addressRepository.addAddressesWithGapLimit(
        walletItemBase: testWalletItem,
        newAddresses: testAddresses,
        isChange: false,
      );

      // Then
      final savedAddresses = realmManager.realm.query<RealmWalletAddress>('walletId == $testWalletId');
      expect(savedAddresses.length, equals(40));
    });

    test('연속되지 않은 인덱스지만 저장된 인덱스보다 작은 인덱스의 주소를 포함할 때는 저장되지 않은 주소를 저장한다', () async {
      // Given
      realmManager.realm.write(() {
        realmWalletBase.usedReceiveIndex = -1;
        realmWalletBase.usedChangeIndex = -1;
        realmWalletBase.generatedReceiveIndex = 19;
        realmWalletBase.generatedChangeIndex = 19;
      });

      final testAddresses = createTestAddresses(isChange: false, startIndex: 18);

      // When
      await addressRepository.addAddressesWithGapLimit(
        walletItemBase: testWalletItem,
        newAddresses: testAddresses,
        isChange: false,
      );

      // Then
      final savedAddresses = realmManager.realm.query<RealmWalletAddress>(
        'walletId == $testWalletId AND isChange == false',
      );
      expect(savedAddresses.length, equals(38));
    });

    test('연속된 인덱스의 주소는 정상적으로 저장된다', () async {
      // Given
      realmManager.realm.write(() {
        realmWalletBase.usedReceiveIndex = -1;
        realmWalletBase.usedChangeIndex = -1;
        realmWalletBase.generatedReceiveIndex = 19;
        realmWalletBase.generatedChangeIndex = 19;
      });
      final testAddresses = createTestAddresses(isChange: false, startIndex: 20);

      // When
      await addressRepository.addAddressesWithGapLimit(
        walletItemBase: testWalletItem,
        newAddresses: testAddresses,
        isChange: false,
      );

      // Then
      final savedAddresses = realmManager.realm.query<RealmWalletAddress>(r'walletId == $0 AND isChange == $1', [
        testWalletId,
        false,
      ]);

      expect(savedAddresses.length, equals(40));

      final savedIndices = savedAddresses.map((addr) => addr.index).toList()..sort();
      final expectedIndices = List.generate(40, (index) => index);
      expect(savedIndices, equals(expectedIndices));

      // generatedReceiveIndex가 업데이트되었는지 확인
      final updatedWalletBase = realmManager.realm.find<RealmWalletBase>(testWalletItem.id);
      expect(updatedWalletBase!.generatedReceiveIndex, equals(39));
    });

    test('주소 타입 필터링이 올바르게 동작한다 - receive 주소만 필터링', () async {
      // Given
      realmManager.realm.write(() {
        realmWalletBase.usedReceiveIndex = -1;
        realmWalletBase.usedChangeIndex = -1;
        realmWalletBase.generatedReceiveIndex = 19;
        realmWalletBase.generatedChangeIndex = 19;
      });

      // receive와 change 주소를 섞어서 전달
      final receiveAddresses = createTestAddresses(isChange: false, startIndex: 20);
      final changeAddresses = createTestAddresses(isChange: true, startIndex: 20);
      final mixedAddresses = [...receiveAddresses, ...changeAddresses];

      // When - receive 주소만 저장하도록 요청
      await addressRepository.addAddressesWithGapLimit(
        walletItemBase: testWalletItem,
        newAddresses: mixedAddresses,
        isChange: false,
      );

      // Then
      final savedReceiveAddresses = realmManager.realm.query<RealmWalletAddress>(
        'walletId == $testWalletId AND isChange == false',
      );
      final savedChangeAddresses = realmManager.realm.query<RealmWalletAddress>(
        'walletId == $testWalletId AND isChange == true',
      );

      // receive 주소만 저장되었는지 확인
      expect(savedReceiveAddresses.length, equals(40));
      expect(savedChangeAddresses.length, equals(20));
    });

    test('주소 타입 필터링이 올바르게 동작한다 - change 주소만 필터링', () async {
      // Given
      realmManager.realm.write(() {
        realmWalletBase.usedReceiveIndex = -1;
        realmWalletBase.usedChangeIndex = -1;
        realmWalletBase.generatedReceiveIndex = 19;
        realmWalletBase.generatedChangeIndex = 19;
      });

      // receive와 change 주소를 섞어서 전달
      final receiveAddresses = createTestAddresses(isChange: false, startIndex: 20);
      final changeAddresses = createTestAddresses(isChange: true, startIndex: 20);
      final mixedAddresses = [...receiveAddresses, ...changeAddresses];

      // When - change 주소만 저장하도록 요청
      await addressRepository.addAddressesWithGapLimit(
        walletItemBase: testWalletItem,
        newAddresses: mixedAddresses,
        isChange: true,
      );

      // Then
      final savedReceiveAddresses = realmManager.realm.query<RealmWalletAddress>(
        'walletId == $testWalletId AND isChange == false',
      );
      final savedChangeAddresses = realmManager.realm.query<RealmWalletAddress>(
        'walletId == $testWalletId AND isChange == true',
      );

      // receive 주소만 저장되었는지 확인
      expect(savedReceiveAddresses.length, equals(20));
      expect(savedChangeAddresses.length, equals(40));
    });

    test('필터링 후 저장할 주소가 없으면 저장하지 않는다', () async {
      // Given
      realmManager.realm.write(() {
        realmWalletBase.usedReceiveIndex = -1;
        realmWalletBase.usedChangeIndex = -1;
        realmWalletBase.generatedReceiveIndex = 19;
        realmWalletBase.generatedChangeIndex = 19;
      });

      // change 주소만 생성
      final changeAddresses = createTestAddresses(isChange: true, startIndex: 20);

      // When - receive 주소만 저장하도록 요청 (change 주소는 필터링됨)
      await addressRepository.addAddressesWithGapLimit(
        walletItemBase: testWalletItem,
        newAddresses: changeAddresses,
        isChange: false,
      );

      // Then
      final savedAddresses = realmManager.realm.query<RealmWalletAddress>(
        'walletId == $testWalletId AND isChange == true',
      );
      expect(savedAddresses.length, equals(20));
    });

    test('정상적인 경우 주소가 백그라운드에서 저장된다', () async {
      // Given
      realmManager.realm.write(() {
        realmWalletBase.usedReceiveIndex = -1;
        realmWalletBase.usedChangeIndex = -1;
        realmWalletBase.generatedReceiveIndex = 19;
        realmWalletBase.generatedChangeIndex = 19;
      });

      final testAddresses = createTestAddresses(isChange: false, startIndex: 20);

      // When
      await addressRepository.addAddressesWithGapLimit(
        walletItemBase: testWalletItem,
        newAddresses: testAddresses,
        isChange: false,
      );

      // Then
      final savedAddresses = realmManager.realm.query<RealmWalletAddress>(
        'walletId == $testWalletId AND isChange == false',
      );

      expect(savedAddresses.length, equals(40));

      final savedIndices = savedAddresses.map((addr) => addr.index).toList()..sort();
      final expectedIndices = List.generate(40, (index) => index);
      expect(savedIndices, equals(expectedIndices));

      // generatedReceiveIndex가 업데이트되었는지 확인
      final updatedWalletBase = realmManager.realm.find<RealmWalletBase>(testWalletItem.id);
      expect(updatedWalletBase!.generatedReceiveIndex, equals(39));
    });

    test('indexDifference가 199일 때는 limit 값을 초과하지 않는 주소가 저장된다', () async {
      // Given
      realmManager.realm.write(() {
        realmWalletBase.usedReceiveIndex = -1;
        realmWalletBase.usedChangeIndex = -1;
        realmWalletBase.generatedReceiveIndex = 198;
        realmWalletBase.generatedChangeIndex = 19;
      });

      final testAddresses = createTestAddresses(isChange: false, startIndex: 199);

      // When
      await addressRepository.addAddressesWithGapLimit(
        walletItemBase: testWalletItem,
        newAddresses: testAddresses,
        isChange: false,
      );

      // Then
      final savedAddresses = realmManager.realm.query<RealmWalletAddress>(
        'walletId == $testWalletId AND isChange == false',
      );

      expect(savedAddresses.length, equals(21), reason: '198 보다 크면서 인덱스가 200 미만인 주소 1개만 추가로 저장되어야 함');
    });

    test('change 주소에 대해서도 indexDifference 체크가 올바르게 동작한다', () async {
      // Given
      realmManager.realm.write(() {
        realmWalletBase.usedReceiveIndex = -1;
        realmWalletBase.usedChangeIndex = -1;
        realmWalletBase.generatedReceiveIndex = 19;
        realmWalletBase.generatedChangeIndex = 199; // usedChangeIndex(-1)과의 차이가 200
      });

      final testAddresses = createTestAddresses(isChange: true, startIndex: 200);

      // When
      await addressRepository.addAddressesWithGapLimit(
        walletItemBase: testWalletItem,
        newAddresses: testAddresses,
        isChange: true,
      );

      // Then
      final savedAddresses = realmManager.realm.query<RealmWalletAddress>(
        'walletId == $testWalletId AND isChange == true',
      );

      expect(savedAddresses.length, equals(20));
    });

    test('초기 상태(-1)에서 0번부터 시작하는 주소가 정상적으로 저장된다', () async {
      // Given
      realmManager.realm.write(() {
        realmWalletBase.usedReceiveIndex = -1;
        realmWalletBase.usedChangeIndex = -1;
        realmWalletBase.generatedReceiveIndex = -1; // 초기 상태
        realmWalletBase.generatedChangeIndex = -1; // 초기 상태
      });

      final testAddresses = createTestAddresses(isChange: false, startIndex: 0);

      // When
      await addressRepository.addAddressesWithGapLimit(
        walletItemBase: testWalletItem,
        newAddresses: testAddresses,
        isChange: false,
      );

      // Then
      final savedAddresses = realmManager.realm.query<RealmWalletAddress>(
        'walletId == $testWalletId AND isChange == false',
      );

      expect(savedAddresses.length, equals(20));

      final savedIndices = savedAddresses.map((addr) => addr.index).toList()..sort();
      final expectedIndices = List.generate(20, (index) => index);
      expect(savedIndices, equals(expectedIndices));

      // generatedReceiveIndex가 업데이트되었는지 확인
      final updatedWalletBase = realmManager.realm.find<RealmWalletBase>(testWalletItem.id);
      expect(updatedWalletBase!.generatedReceiveIndex, equals(19));
    });

    test('change 주소도 연속된 인덱스로 정상 저장된다', () async {
      // Given
      realmManager.realm.write(() {
        realmWalletBase.usedReceiveIndex = -1;
        realmWalletBase.usedChangeIndex = -1;
        realmWalletBase.generatedReceiveIndex = 19;
        realmWalletBase.generatedChangeIndex = 19;
      });

      final testAddresses = createTestAddresses(isChange: true, startIndex: 20);

      // When
      await addressRepository.addAddressesWithGapLimit(
        walletItemBase: testWalletItem,
        newAddresses: testAddresses,
        isChange: true,
      );

      // Then
      final savedAddresses = realmManager.realm.query<RealmWalletAddress>(
        'walletId == $testWalletId AND isChange == true',
      );

      expect(savedAddresses.length, equals(40));

      final savedIndices = savedAddresses.map((addr) => addr.index).toList()..sort();
      final expectedIndices = List.generate(40, (index) => index);
      expect(savedIndices, equals(expectedIndices));

      // generatedChangeIndex가 업데이트되었는지 확인
      final updatedWalletBase = realmManager.realm.find<RealmWalletBase>(testWalletItem.id);
      expect(updatedWalletBase!.generatedChangeIndex, equals(39));
    });
  });

  group('AddressRepository dormant/active 주소 조회 테스트', () {
    void setAddressState(
      int index,
      bool isChange, {
      required bool isUsed,
      required int confirmed,
      required int unconfirmed,
    }) {
      final realmAddress =
          realmManager.realm.query<RealmWalletAddress>(r'walletId == $0 AND index == $1 AND isChange == $2', [
            testWalletId,
            index,
            isChange,
          ]).first;
      realmManager.realm.write(() {
        realmAddress.isUsed = isUsed;
        realmAddress.confirmed = confirmed;
        realmAddress.unconfirmed = unconfirmed;
        realmAddress.total = confirmed + unconfirmed;
      });
    }

    test('isAddressDormant: 사용됐지만 잔액/미확정이 모두 0이면 dormant로 판단한다', () {
      setAddressState(0, false, isUsed: true, confirmed: 0, unconfirmed: 0);
      final address = testWalletItem.walletBase.getAddress(0, isChange: false);

      expect(addressRepository.isAddressDormant(testWalletId, address), isTrue);
    });

    test('isAddressDormant: 잔액이 남아있으면 dormant가 아니다', () {
      setAddressState(1, false, isUsed: true, confirmed: 1000, unconfirmed: 0);
      final address = testWalletItem.walletBase.getAddress(1, isChange: false);

      expect(addressRepository.isAddressDormant(testWalletId, address), isFalse);
    });

    test('isAddressDormant: 미확정 잔액만 있어도 dormant가 아니다', () {
      setAddressState(2, false, isUsed: true, confirmed: 0, unconfirmed: 500);
      final address = testWalletItem.walletBase.getAddress(2, isChange: false);

      expect(addressRepository.isAddressDormant(testWalletId, address), isFalse);
    });

    test('isAddressDormant: 사용된 적 없는 주소는 dormant가 아니다', () {
      final address = testWalletItem.walletBase.getAddress(3, isChange: false);

      expect(addressRepository.isAddressDormant(testWalletId, address), isFalse);
    });

    test('getDormantUsedAddresses: dormant 주소만 반환한다', () {
      setAddressState(4, false, isUsed: true, confirmed: 0, unconfirmed: 0);
      setAddressState(5, false, isUsed: true, confirmed: 1000, unconfirmed: 0);
      setAddressState(6, true, isUsed: true, confirmed: 0, unconfirmed: 0);

      final dormantAddresses = addressRepository.getDormantUsedAddresses(testWalletId);
      final dormantIndices = dormantAddresses.map((a) => (a.index, a.isChange)).toSet();

      expect(dormantIndices, containsAll([(4, false), (6, true)]));
      expect(dormantIndices.contains((5, false)), isFalse);
    });

    test('getActiveUsedAddresses: 잔액/미확정이 남아있는 사용된 주소만, 지정한 체인만 반환한다', () {
      setAddressState(7, false, isUsed: true, confirmed: 1000, unconfirmed: 0);
      setAddressState(8, false, isUsed: true, confirmed: 0, unconfirmed: 0);
      setAddressState(9, true, isUsed: true, confirmed: 0, unconfirmed: 500);

      final activeReceiveAddresses = addressRepository.getActiveUsedAddresses(testWalletId, false);
      final activeReceiveIndices = activeReceiveAddresses.map((a) => a.index).toSet();

      expect(activeReceiveIndices.contains(7), isTrue);
      expect(activeReceiveIndices.contains(8), isFalse);
      expect(activeReceiveIndices.contains(9), isFalse);

      final activeChangeAddresses = addressRepository.getActiveUsedAddresses(testWalletId, true);
      expect(activeChangeAddresses.map((a) => a.index), contains(9));
    });
  });

  group('ensureAddressesExist - 재동기화(둘 다 -1에서 시작) 회귀 테스트', () {
    // 재동기화로 generatedReceiveIndex/generatedChangeIndex가 둘 다 -1인 상태에서, receive만
    // 먼저 생성한 뒤 change를 생성해도 change index 0이 스킵되지 않고 정상 생성돼야 한다.
    // (예전 버그: receive만 담긴 배치를 처리할 때 maxChangeIndex 초기값이 0이라 change 주소가
    // 하나도 없는데도 generatedChangeIndex가 0으로 잘못 갱신되어, 이후 change 생성 시
    // index 0이 이미 생성된 걸로 착각해 index 1부터 생성해버림)
    test('receive를 먼저 생성해도 generatedChangeIndex가 잘못 갱신되지 않는다', () async {
      expect(realmWalletBase.generatedReceiveIndex, -1);
      expect(realmWalletBase.generatedChangeIndex, -1);

      await addressRepository.ensureAddressesExist(
        walletItemBase: testWalletItem,
        cursor: 0,
        count: 20,
        isChange: false,
      );

      final afterReceiveOnly = realmManager.realm.find<RealmWalletBase>(testWalletId)!;
      expect(afterReceiveOnly.generatedChangeIndex, -1);
    });

    test('receive 생성 후 change를 생성하면 change index 0도 정상적으로 생성된다', () async {
      await addressRepository.ensureAddressesExist(
        walletItemBase: testWalletItem,
        cursor: 0,
        count: 20,
        isChange: false,
      );
      await addressRepository.ensureAddressesExist(
        walletItemBase: testWalletItem,
        cursor: 0,
        count: 20,
        isChange: true,
      );

      final changeAddressZeroId = getWalletAddressId(
        testWalletId,
        0,
        testWalletItem.walletBase.getAddress(0, isChange: true),
      );
      final changeAddressZero = realmManager.realm.find<RealmWalletAddress>(changeAddressZeroId);

      expect(changeAddressZero, isNotNull);
      expect(changeAddressZero!.index, 0);
      expect(changeAddressZero.isChange, isTrue);
    });
  });
}
