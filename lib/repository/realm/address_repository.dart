import 'dart:math';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/converter/address.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/model/node/address_balance_update_dto.dart';
import 'package:coconut_wallet/services/model/response/subscribe_wallet_response.dart';
import 'package:coconut_wallet/utils/logger.dart';

class AddressRepository extends BaseRepository {
  AddressRepository(super._realmManager);

  /// 주소 목록 가져오기
  List<WalletAddress> getWalletAddressList(
    WalletListItemBase walletItemBase,
    int cursor,
    int count,
    bool isChange,
  ) {
    final generatedAddressIndex = getGeneratedAddressIndex(walletItemBase, isChange);

    if (generatedAddressIndex > cursor + count) {
      return _getAddressListFromDb(
        walletId: walletItemBase.id,
        cursor: cursor,
        count: count,
        isChange: isChange,
      );
    }

    // 기존 DB에 있는 주소 가져오기
    List<WalletAddress> existingAddresses = generatedAddressIndex > cursor
        ? _getAddressListFromDb(
            walletId: walletItemBase.id,
            cursor: cursor,
            count: count,
            isChange: isChange,
          )
        : [];

    // 필요한 경우 새 주소 생성하고 저장하지 않고 반환
    if (existingAddresses.length < count) {
      final newAddresses = _generateAddresses(
        wallet: walletItemBase.walletBase,
        startIndex: existingAddresses.isEmpty ? cursor : existingAddresses.last.index + 1,
        count: count - existingAddresses.length,
        isChange: isChange,
      );

      existingAddresses.addAll(newAddresses);
    }

    return existingAddresses;
  }

  int getGeneratedAddressIndex(WalletListItemBase walletItemBase, bool isChange) {
    final realmWalletBase = realm.find<RealmWalletBase>(walletItemBase.id);
    if (realmWalletBase == null) {
      throw StateError('[getGeneratedAddressIndex] Wallet not found');
    }
    return isChange ? realmWalletBase.generatedChangeIndex : realmWalletBase.generatedReceiveIndex;
  }

  Future<void> ensureAddressesInit({
    required WalletListItemBase walletItemBase,
  }) async {
    final realmWalletBase = realm.find<RealmWalletBase>(walletItemBase.id);
    if (realmWalletBase == null) {
      throw StateError('[getWalletAddressList] Wallet not found');
    }
    final List<WalletAddress> addressesToAdd = [];

    if (realmWalletBase.generatedReceiveIndex < 0) {
      addressesToAdd.add(
        _generateAddress(walletItemBase.walletBase, 0, false),
      );
    }

    if (realmWalletBase.generatedChangeIndex < 0) {
      addressesToAdd.add(
        _generateAddress(walletItemBase.walletBase, 0, true),
      );
    }

    if (addressesToAdd.isNotEmpty) {
      await _addAllAddressList(realmWalletBase, addressesToAdd);
    }
  }

  /// 필요한 경우 새로운 주소를 생성하고 저장
  Future<void> ensureAddressesExist({
    required WalletListItemBase walletItemBase,
    required int cursor,
    required int count,
    required bool isChange,
  }) async {
    final realmWalletBase = realm.find<RealmWalletBase>(walletItemBase.id);
    if (realmWalletBase == null) {
      throw StateError('[getWalletAddressList] Wallet not found');
    }

    final currentIndex =
        isChange ? realmWalletBase.generatedChangeIndex : realmWalletBase.generatedReceiveIndex;

    if (cursor + count > currentIndex) {
      final startIndex = currentIndex + 1;
      final endIndex = cursor + count;
      final addressCount = endIndex - startIndex;

      if (addressCount > 0) {
        final addresses = _generateAddresses(
          wallet: walletItemBase.walletBase,
          startIndex: startIndex,
          count: addressCount,
          isChange: isChange,
        );

        await _addAllAddressList(realmWalletBase, addresses);
      }
    }
  }

  /// DB에서 주소 목록 조회
  List<WalletAddress> _getAddressListFromDb({
    required int walletId,
    required int cursor,
    required int count,
    required bool isChange,
  }) {
    final query = realm.query<RealmWalletAddress>(
        'walletId == $walletId AND isChange == $isChange SORT(index ASC)');
    final paginatedResults = query.skip(cursor).take(count);

    return paginatedResults.map((e) => mapRealmToWalletAddress(e)).toList();
  }

  /// 주소를 DB에 저장
  Future<void> _addAllAddressList(
      RealmWalletBase realmWalletBase, List<WalletAddress> addresses) async {
    if (addresses.isEmpty) {
      return;
    }

    int maxReceiveIndex = 0;
    int maxChangeIndex = 0;

    // 주소 인덱스 최대값 계산
    for (final address in addresses) {
      if (address.isChange) {
        maxChangeIndex = max(maxChangeIndex, address.index);
      } else {
        maxReceiveIndex = max(maxReceiveIndex, address.index);
      }
    }

    await _updateWalletIndices(realmWalletBase, maxReceiveIndex, maxChangeIndex);

    // 이미 존재하는 주소들의 ID를 미리 확인
    final existingIds = realm
        .query<RealmWalletAddress>('walletId == ${realmWalletBase.id}')
        .map((addr) => addr.id)
        .toSet();

    // 중복되지 않는 주소 필터링
    final addressesToAdd = <RealmWalletAddress>[];

    for (final address in addresses) {
      final addressId = Object.hash(realmWalletBase.id, address.index, address.address);

      // 이미 존재하는 주소는 건너뛰기
      if (existingIds.contains(addressId)) {
        continue;
      }

      addressesToAdd.add(mapWalletAddressToRealm(
        realmWalletBase.id,
        address,
      ));
    }

    // 추가할 주소가 없으면 종료
    if (addressesToAdd.isEmpty) {
      return;
    }

    await _safelyAddAddresses(addressesToAdd);
  }

  /// 안전하게 주소를 추가하는 헬퍼 메서드
  Future<void> _safelyAddAddresses(List<RealmWalletAddress> addresses) async {
    for (final address in addresses) {
      try {
        await realm.writeAsync(() {
          realm.add<RealmWalletAddress>(address);
        });
      } catch (e) {
        if (e.toString().contains('RLM_ERR_OBJECT_ALREADY_EXISTS')) {
          Logger.log('[_safelyAddAddresses] Address already exists, skipping: ${address.address}');
          continue;
        }

        Logger.error('[_safelyAddAddresses] Failed to add address: $e');
        rethrow;
      }
    }
  }

  /// 지갑 인덱스만 업데이트하는 헬퍼 메서드
  Future<void> _updateWalletIndices(
      RealmWalletBase realmWalletBase, int maxReceiveIndex, int maxChangeIndex) async {
    await realm.writeAsync(() {
      if (maxChangeIndex > realmWalletBase.generatedChangeIndex) {
        realmWalletBase.generatedChangeIndex = maxChangeIndex;
      }
      if (maxReceiveIndex > realmWalletBase.generatedReceiveIndex) {
        realmWalletBase.generatedReceiveIndex = maxReceiveIndex;
      }
    });
  }

  /// 단일 주소 생성
  WalletAddress _generateAddress(WalletBase wallet, int index, bool isChange) {
    String address = wallet.getAddress(index, isChange: isChange);
    String derivationPath = '${wallet.derivationPath}${isChange ? '/1' : '/0'}/$index';

    return WalletAddress(
      address,
      derivationPath,
      index,
      isChange,
      false,
      0,
      0,
      0,
    );
  }

  /// 여러 주소 생성
  List<WalletAddress> _generateAddresses(
      {required WalletBase wallet,
      required int startIndex,
      required int count,
      required bool isChange}) {
    return List.generate(count, (index) => _generateAddress(wallet, startIndex + index, isChange));
  }

  /// 주소가 이미 존재하는지 확인
  bool containsAddress(int walletId, String address, {bool isChange = false}) {
    final realmWalletAddress = realm.query<RealmWalletAddress>(
      isChange
          ? r'walletId == $0 AND address == $1 AND isChange == true'
          : r'walletId == $0 AND address == $1',
      [walletId, address],
    );
    return realmWalletAddress.isNotEmpty;
  }

  /// 변경 주소 목록에서 필터링
  List<WalletAddress> filterChangeAddressesFromList(int walletId, List<String> addresses) {
    final realmWalletAddresses = realm.query<RealmWalletAddress>(
      r'walletId == $0 AND address IN $1 AND isChange == true',
      [walletId, addresses],
    );
    return realmWalletAddresses.map((e) => mapRealmToWalletAddress(e)).toList();
  }

  /// 변경 주소 가져오기
  WalletAddress getChangeAddress(int walletId) {
    final realmWalletBase = getWalletBase(walletId);
    final changeIndex = realmWalletBase.usedChangeIndex + 1;
    final realmWalletAddress = realm.query<RealmWalletAddress>(
      r'walletId == $0 AND isChange == true AND index == $1',
      [walletId, changeIndex],
    );

    return mapRealmToWalletAddress(realmWalletAddress.first);
  }

  /// 수신 주소 가져오기
  WalletAddress getReceiveAddress(int walletId) {
    final realmWalletBase = getWalletBase(walletId);
    final receiveIndex = realmWalletBase.usedReceiveIndex + 1;
    final realmWalletAddress = realm.query<RealmWalletAddress>(
      r'walletId == $0 AND isChange == false AND index == $1',
      [walletId, receiveIndex],
    ).first;

    return mapRealmToWalletAddress(realmWalletAddress);
  }

  /// 지갑 Base 정보 조회
  RealmWalletBase getWalletBase(int walletId) {
    final realmWalletBase = realm.find<RealmWalletBase>(walletId);
    if (realmWalletBase == null) {
      throw StateError('[getWalletBase] Wallet not found');
    }
    return realmWalletBase;
  }

  void setWalletAddressUsed(WalletListItemBase walletItem, int addressIndex, bool isChange) {
    final realmWalletAddress = realm.query<RealmWalletAddress>(
      r'walletId == $0 AND index == $1 AND isChange == $2',
      [walletItem.id, addressIndex, isChange],
    ).firstOrNull;

    if (realmWalletAddress == null) {
      Logger.error(
          '[setWalletAddressUsed] Wallet address not found, walletId: ${walletItem.id}, index: $addressIndex, isChange: $isChange');
      return;
    }

    realm.write(() {
      realmWalletAddress.isUsed = true;
    });
  }

  Future<void> setWalletAddressUsedBatch(
      WalletListItemBase walletItem, List<ScriptStatus> scriptStatuses) async {
    final changedScriptStatuses = scriptStatuses.where((status) => status.status != null).toList();

    final receiveIndices = changedScriptStatuses
        .where((status) => !status.isChange)
        .map((status) => status.index)
        .toSet();
    final changeIndices = changedScriptStatuses
        .where((status) => status.isChange)
        .map((status) => status.index)
        .toSet();

    final receiveAddresses = realm.query<RealmWalletAddress>(
      r'walletId == $0 AND isChange == false AND index IN $1',
      [walletItem.id, receiveIndices],
    ).toList();

    final changeAddresses = realm.query<RealmWalletAddress>(
      r'walletId == $0 AND isChange == true AND index IN $1',
      [walletItem.id, changeIndices],
    ).toList();

    // 미리 모든 주소를 조회하여 맵으로 구성
    final addressMap = <String, RealmWalletAddress>{};
    for (final address in [...changeAddresses, ...receiveAddresses]) {
      final key = '${address.index}_${address.isChange}';
      addressMap[key] = address;
    }

    // 단일 트랜잭션으로 모든 주소 업데이트
    await realm.writeAsync(() {
      for (final scriptStatus in changedScriptStatuses) {
        final key = '${scriptStatus.index}_${scriptStatus.isChange}';
        final realmWalletAddress = addressMap[key];

        if (realmWalletAddress == null) {
          Logger.error(
              '[setWalletAddressUsedBatch] Wallet address not found, walletId: ${walletItem.id}, index: ${scriptStatus.index}, isChange: ${scriptStatus.isChange}');
          continue;
        }

        realmWalletAddress.isUsed = true;
      }
    });
  }

  /// 지갑 사용 인덱스 업데이트
  Future<void> updateWalletUsedIndex(WalletListItemBase walletItem, int usedIndex,
      {required bool isChange}) async {
    final realmWalletBase = getWalletBase(walletItem.id);

    int dbUsedIndex = isChange ? realmWalletBase.usedChangeIndex : realmWalletBase.usedReceiveIndex;

    int cursor = max(usedIndex, dbUsedIndex) + 1;

    if (isChange) {
      walletItem.changeUsedIndex = cursor - 1;
    } else {
      walletItem.receiveUsedIndex = cursor - 1;
    }

    // 필요한 경우에만 새 주소 생성
    await ensureAddressesExist(
      walletItemBase: walletItem,
      cursor: cursor,
      count: 1,
      isChange: isChange,
    );

    // 지갑 인덱스 업데이트
    await realm.writeAsync(() {
      if (usedIndex > dbUsedIndex) {
        if (isChange) {
          realmWalletBase.usedChangeIndex = usedIndex;
        } else {
          realmWalletBase.usedReceiveIndex = usedIndex;
        }
      }
    });
  }

  /// 주소 잔액 업데이트
  /// 해당 주소의 Balance 변화량을 반환합니다.
  Balance updateAddressBalance(
      {required int walletId,
      required int index,
      required bool isChange,
      required Balance balance}) {
    final realmWalletAddress = realm.query<RealmWalletAddress>(
      r'walletId == $0 AND index == $1 AND isChange == $2',
      [walletId, index, isChange],
    ).firstOrNull;

    if (realmWalletAddress == null) {
      throw StateError(
          '[updateAddressBalance] Wallet address not found, walletId: $walletId, index: $index, isChange: $isChange');
    }

    final confirmedDiff = balance.confirmed - realmWalletAddress.confirmed;
    final unconfirmedDiff = balance.unconfirmed - realmWalletAddress.unconfirmed;

    realm.write(() {
      // 지갑 주소 잔액 업데이트
      realmWalletAddress.confirmed = balance.confirmed;
      realmWalletAddress.unconfirmed = balance.unconfirmed;
      realmWalletAddress.total = balance.total;
    });

    return Balance(confirmedDiff, unconfirmedDiff);
  }

  /// DTO 객체를 사용하여 다수의 주소 잔액을 일괄 업데이트하고 총 변화량을 반환합니다.
  /// @param walletId 지갑 ID
  /// @param updateDataList 업데이트할 DTO 객체 목록
  /// @return 전체 잔액 변화량
  Future<Balance> updateAddressBalanceBatch(
      int walletId, List<AddressBalanceUpdateDto> updateDataList) async {
    if (updateDataList.isEmpty) {
      return Balance(0, 0);
    }

    // 모든 주소 정보를 한 번에 쿼리
    final realmAddresses = realm.query<RealmWalletAddress>(
      'walletId == $walletId',
    );

    // 트랜잭션 외부에서 모든 계산 수행
    List<AddressBalanceCalculationResult> calculationResults = [];
    int totalConfirmedDiff = 0;
    int totalUnconfirmedDiff = 0;

    for (var dto in updateDataList) {
      // 해당 주소 찾기
      final realmAddress = realmAddresses.firstWhere(
        (a) => a.index == dto.scriptStatus.index && a.isChange == dto.scriptStatus.isChange,
        orElse: () => throw StateError(
            '[updateAddressBalanceBatchWithDTO] Wallet address not found, walletId: $walletId, index: ${dto.scriptStatus.index}, isChange: ${dto.scriptStatus.isChange}'),
      );

      // 차이 계산
      final confirmedDiff = dto.confirmed - realmAddress.confirmed;
      final unconfirmedDiff = dto.unconfirmed - realmAddress.unconfirmed;

      // 결과 저장
      calculationResults.add(
        AddressBalanceCalculationResult(
          realmAddress: realmAddress,
          confirmedDiff: confirmedDiff,
          unconfirmedDiff: unconfirmedDiff,
          newConfirmed: dto.confirmed,
          newUnconfirmed: dto.unconfirmed,
        ),
      );

      // 총 차이 누적
      totalConfirmedDiff += confirmedDiff;
      totalUnconfirmedDiff += unconfirmedDiff;
    }

    // 계산이 완료된 후 Realm 트랜잭션에서 실제 DB 업데이트만 수행
    await realm.writeAsync(() {
      for (var result in calculationResults) {
        final realmAddress = result.realmAddress;
        realmAddress.confirmed = result.newConfirmed;
        realmAddress.unconfirmed = result.newUnconfirmed;
        realmAddress.total = result.newTotal;
      }
    });

    return Balance(totalConfirmedDiff, totalUnconfirmedDiff);
  }

  String getDerivationPath(
    int walletId,
    String address,
  ) {
    final existingAddress = realm.query<RealmWalletAddress>(
      r'walletId == $0 AND address == $1',
      [walletId, address],
    ).firstOrNull;

    if (existingAddress != null) {
      return existingAddress.derivationPath;
    }
    return '';
  }

  Future<void> syncWalletWithSubscriptionData(
    WalletListItemBase walletItem,
    List<ScriptStatus> scriptStatuses,
    int receiveUsedIndex,
    int changeUsedIndex,
  ) async {
    // 지갑 인덱스 업데이트
    await updateWalletUsedIndex(
      walletItem,
      receiveUsedIndex,
      isChange: false,
    );
    await updateWalletUsedIndex(
      walletItem,
      changeUsedIndex,
      isChange: true,
    );

    // 주소 사용 여부 업데이트
    await setWalletAddressUsedBatch(
      walletItem,
      scriptStatuses,
    );
  }
}
