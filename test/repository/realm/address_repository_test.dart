import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/converter/address.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/wallet_mock.dart';
import 'test_realm_manager.dart';

void main() {
  late TestRealmManager realmManager;
  late AddressRepository addressRepository;
  SinglesigWalletListItem testWalletItem = WalletMock.createSingleSigWalletItem();
  late RealmWalletBase realmWalletBase;
  const int testWalletId = 1;

  List<WalletAddress> createTestAddresses({
    required bool isChange,
    required int startIndex,
  }) {
    return List.generate(20, (index) {
      final addressIndex = startIndex + index;
      final address = testWalletItem.walletBase.getAddress(addressIndex, isChange: isChange);
      final derivationPath =
          '${testWalletItem.walletBase.derivationPath}${isChange ? '/1' : '/0'}/$addressIndex';

      return WalletAddress(
        address,
        derivationPath,
        addressIndex,
        isChange,
        false,
        0,
        0,
        0,
      );
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
        WalletType.singleSignature.name);
    addressRepository = AddressRepository(realmManager);
    // 테스트용 지갑 생성
    realmManager.realm.write(() {
      realmManager.realm.add(realmWalletBase);
    });

    final initialAddresses = createTestAddresses(
      isChange: false,
      startIndex: 0,
    );
    initialAddresses.addAll(
      createTestAddresses(
        isChange: true,
        startIndex: 0,
      ),
    );
    realmManager.realm.write(() {
      realmManager.realm.addAll<RealmWalletAddress>([
        ...initialAddresses.map((address) => RealmWalletAddress(
              getWalletAddressId(
                  walletId: testWalletId, index: address.index, address: address.address),
              testWalletId,
              address.address,
              address.index,
              address.isChange,
              address.derivationPath,
              false,
              0,
              0,
              0,
            )),
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
      final savedAddresses = realmManager.realm.query<RealmWalletAddress>(
        'walletId == $testWalletId',
      );
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

      final testAddresses = createTestAddresses(
        isChange: false,
        startIndex: 200,
      );

      // When
      await addressRepository.addAddressesWithGapLimit(
        walletItemBase: testWalletItem,
        newAddresses: testAddresses,
        isChange: false,
      );

      // Then
      final savedAddresses = realmManager.realm.query<RealmWalletAddress>(
        'walletId == $testWalletId',
      );
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

      final testAddresses = createTestAddresses(
        isChange: false,
        startIndex: 21,
      );

      // When
      await addressRepository.addAddressesWithGapLimit(
        walletItemBase: testWalletItem,
        newAddresses: testAddresses,
        isChange: false,
      );

      // Then
      final savedAddresses = realmManager.realm.query<RealmWalletAddress>(
        'walletId == $testWalletId',
      );
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

      final testAddresses = createTestAddresses(
        isChange: false,
        startIndex: 18,
      );

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
      final testAddresses = createTestAddresses(
        isChange: false,
        startIndex: 20,
      );

      // When
      await addressRepository.addAddressesWithGapLimit(
        walletItemBase: testWalletItem,
        newAddresses: testAddresses,
        isChange: false,
      );

      // Then
      final savedAddresses = realmManager.realm.query<RealmWalletAddress>(
        r'walletId == $0 AND isChange == $1',
        [testWalletId, false],
      );

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
      final receiveAddresses = createTestAddresses(
        isChange: false,
        startIndex: 20,
      );
      final changeAddresses = createTestAddresses(
        isChange: true,
        startIndex: 20,
      );
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
      final receiveAddresses = createTestAddresses(
        isChange: false,
        startIndex: 20,
      );
      final changeAddresses = createTestAddresses(
        isChange: true,
        startIndex: 20,
      );
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
      final changeAddresses = createTestAddresses(
        isChange: true,
        startIndex: 20,
      );

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

      final testAddresses = createTestAddresses(
        isChange: false,
        startIndex: 20,
      );

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

      final testAddresses = createTestAddresses(
        isChange: false,
        startIndex: 199,
      );

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

      expect(savedAddresses.length, equals(21),
          reason: '198 보다 크면서 인덱스가 200 미만인 주소 1개만 추가로 저장되어야 함');
    });

    test('change 주소에 대해서도 indexDifference 체크가 올바르게 동작한다', () async {
      // Given
      realmManager.realm.write(() {
        realmWalletBase.usedReceiveIndex = -1;
        realmWalletBase.usedChangeIndex = -1;
        realmWalletBase.generatedReceiveIndex = 19;
        realmWalletBase.generatedChangeIndex = 199; // usedChangeIndex(-1)과의 차이가 200
      });

      final testAddresses = createTestAddresses(
        isChange: true,
        startIndex: 200,
      );

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

      final testAddresses = createTestAddresses(
        isChange: false,
        startIndex: 0,
      );

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

      final testAddresses = createTestAddresses(
        isChange: true,
        startIndex: 20,
      );

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
}
