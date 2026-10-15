import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/wallet_mock.dart';
import 'test_realm_manager.dart';

/// updateWalletUsedIndex TOCTOU 수정 - 주소 재사용 잠재 버그
///
/// updateWalletUsedIndex가 두번 호출되면, 더 큰 usedIndex를 먼저 반영한 호출이 있어도,
/// 더 작은 usedIndex를 들고 진입 시점의 오래된 값과 비교하는 호출이 나중에 커밋되면서 이미 반영된 더 큰 값을 되돌려버릴 수 있다.
void main() {
  late TestRealmManager realmManager;
  late AddressRepository addressRepository;
  final testWalletItem = WalletMock.createSingleSigWalletItem();
  late RealmWalletBase realmWalletBase;
  const int testWalletId = 1;

  List<WalletAddress> createTestAddresses({required bool isChange, required int startIndex, required int count}) {
    return List.generate(count, (index) {
      final addressIndex = startIndex + index;
      final address = testWalletItem.walletBase.getAddress(addressIndex, isChange: isChange);
      final derivationPath = '${testWalletItem.walletBase.derivationPath}${isChange ? '/1' : '/0'}/$addressIndex';
      return WalletAddress(address, derivationPath, addressIndex, isChange, false, 0, 0, 0);
    });
  }

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
    realmManager.realm.write(() {
      realmManager.realm.add(realmWalletBase);
    });

    // ensureAddressesExist가 항상 즉시 no-op이 되도록 필요한 인덱스보다 훨씬 넉넉하게 주소를 미리 만들어둔다.
    // (레이스를 "생성 비용 차이"가 아니라 진짜 겹침으로만 재현하기 위함)
    final addresses = createTestAddresses(isChange: false, startIndex: 0, count: 200);
    realmManager.realm.write(() {
      realmManager.realm.addAll<RealmWalletAddress>([
        ...addresses.map(
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
      realmWalletBase.generatedReceiveIndex = 199;
      realmWalletBase.usedReceiveIndex = 40;
    });
    testWalletItem.receiveUsedIndex = 40;
  });

  tearDown(() {
    realmManager.reset();
    realmManager.dispose();
  });

  test('겹쳐서 들어온 두 번의 usedIndex 갱신 중, 이미 반영된 더 큰 값이 나중에 온 더 작은 값에 의해 되돌려지면 안 된다', () async {
    // Given: usedReceiveIndex = 40.
    // When: 75(island 발견으로 전진하는 _extendSubscription 역할)와
    // 55(원래 이벤트 처리인 _processScriptStatus 역할)가 겹쳐서(Future.wait) 들어온다.
    // 리스트 순서상 75가 먼저 시작되므로 정상적인 스케줄링에서는 75가 먼저 커밋되고,
    // 55는 진입 시점(둘 다 아직 아무도 안 썼을 때)에 읽은 오래된 usedReceiveIndex(40)를 기준으로 뒤늦게 커밋된다.
    await Future.wait([
      addressRepository.updateWalletUsedIndex(testWalletItem, 75, isChange: false),
      addressRepository.updateWalletUsedIndex(testWalletItem, 55, isChange: false),
    ]);

    // Then: DB에 영속화된 값도, 다음 수신 주소도 island(75) 기준을 유지해야 한다.
    final (persistedUsedIndex, _) = addressRepository.getUsedIndexes(testWalletId);
    expect(
      persistedUsedIndex,
      75,
      reason:
          '이미 반영된 더 큰 usedIndex(75)가 나중에 도착한 더 작은 값(55)에 의해 되돌려지면 안 된다. '
          '되돌려지면 usedReceiveIndex+1(56)이 이미 사용된 주소 구간(41~75) 안쪽을 다시 가리키게 된다.',
    );

    final nextReceive = addressRepository.getReceiveAddress(testWalletId, wallet: testWalletItem.walletBase);
    expect(nextReceive.index, 76, reason: '다음 수신 주소는 확인된 usedIndex(75) 바로 다음이어야 한다.');

    expect(testWalletItem.receiveUsedIndex, 75, reason: 'walletItem 인메모리 캐시도 되돌아가면 안 된다.');
  });
}
