import 'dart:math';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/converter/address.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

class AddressRepository extends BaseRepository {
  AddressRepository(super._realmManager);

  /// 주소 목록 가져오기
  List<WalletAddress> getWalletAddressList(
    WalletListItemBase walletItemBase,
    int cursor,
    int count,
    bool isChange,
  ) {
    ensureAddressesExist(
      walletItemBase: walletItemBase,
      cursor: cursor,
      count: count,
      isChange: isChange,
    );

    return _getAddressesFromDB(
      walletId: walletItemBase.id,
      cursor: cursor,
      count: count,
      isChange: isChange,
    );
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

    final currentIndex = isChange
        ? realmWalletBase.generatedChangeIndex
        : realmWalletBase.generatedReceiveIndex;

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

        await _saveAddressesToDB(realmWalletBase, addresses, isChange);
      }
    }
  }

  /// DB에서 주소 목록 조회
  List<WalletAddress> _getAddressesFromDB({
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
  Future<void> _saveAddressesToDB(RealmWalletBase realmWalletBase,
      List<WalletAddress> addresses, bool isChange) async {
    final realmAddresses = addresses
        .map(
          (address) => RealmWalletAddress(
            Object.hash(realmWalletBase.id, address.index, address.address),
            realmWalletBase.id,
            address.address,
            address.index,
            isChange,
            address.derivationPath,
            address.isUsed,
            address.confirmed,
            address.unconfirmed,
            address.total,
          ),
        )
        .toList();

    await realm.writeAsync(() {
      realm.addAll<RealmWalletAddress>(realmAddresses);

      // 생성된 주소 인덱스 업데이트
      if (isChange) {
        realmWalletBase.generatedChangeIndex = realmAddresses.last.index;
      } else {
        realmWalletBase.generatedReceiveIndex = realmAddresses.last.index;
      }
    });
  }

  /// 단일 주소 생성
  WalletAddress _generateAddress(WalletBase wallet, int index, bool isChange) {
    String address = wallet.getAddress(index, isChange: isChange);
    String derivationPath =
        '${wallet.derivationPath}${isChange ? '/1' : '/0'}/$index';

    return WalletAddress(
      address,
      derivationPath,
      index,
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
    return List.generate(count,
        (index) => _generateAddress(wallet, startIndex + index, isChange));
  }

  /// 주소가 이미 존재하는지 확인
  bool containsAddress(int walletId, String address) {
    final realmWalletAddress = realm.query<RealmWalletAddress>(
      r'walletId == $0 AND address == $1',
      [walletId, address],
    );
    return realmWalletAddress.isNotEmpty;
  }

  /// 변경 주소 목록에서 필터링
  List<WalletAddress> filterChangeAddressesFromList(
      int walletId, List<String> addresses) {
    final realmWalletAddresses = realm.query<RealmWalletAddress>(
      r'walletId == $0 AND address IN $1 AND isChange == true',
      [walletId, addresses],
    );
    return realmWalletAddresses.map((e) => mapRealmToWalletAddress(e)).toList();
  }

  /// 주소 목록 업데이트 (잔액과 사용여부만 갱신)
  void updateWalletAddressList(WalletListItemBase walletItem,
      List<WalletAddress> walletAddressList, bool isChange) {
    final realmWalletAddresses = realm.query<RealmWalletAddress>(
      r'walletId == $0 AND isChange == $1',
      [walletItem.id, isChange],
    );

    realm.write(() {
      for (final walletAddress in walletAddressList) {
        final realmAddress = realmWalletAddresses.firstWhere(
          (a) => a.index == walletAddress.index,
        );

        realmAddress.confirmed = walletAddress.confirmed;
        realmAddress.unconfirmed = walletAddress.unconfirmed;
        realmAddress.total = walletAddress.total;
        realmAddress.isUsed = walletAddress.isUsed;
      }
    });
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

  /// 지갑 사용 인덱스 업데이트
  void updateWalletUsedIndex(WalletListItemBase walletItem,
      int usedReceiveIndex, int usedChangeIndex) {
    final realmWalletBase = getWalletBase(walletItem.id);

    int receiveCursor =
        max(usedReceiveIndex, realmWalletBase.usedReceiveIndex) + 1;
    int changeCursor =
        max(usedChangeIndex, realmWalletBase.usedChangeIndex) + 1;

    walletItem.receiveUsedIndex = receiveCursor - 1;
    walletItem.changeUsedIndex = changeCursor - 1;

    // 필요한 경우에만 새 주소 생성
    ensureAddressesExist(
      walletItemBase: walletItem,
      cursor: receiveCursor,
      count: 1,
      isChange: false,
    );

    ensureAddressesExist(
      walletItemBase: walletItem,
      cursor: changeCursor,
      count: 1,
      isChange: true,
    );

    // 지갑 인덱스 업데이트
    realm.write(() {
      if (usedReceiveIndex > realmWalletBase.usedReceiveIndex) {
        realmWalletBase.usedReceiveIndex = usedReceiveIndex;
      }
      if (usedChangeIndex > realmWalletBase.usedChangeIndex) {
        realmWalletBase.usedChangeIndex = usedChangeIndex;
      }
    });
  }

  /// 주소 잔액 업데이트
  void updateAddressBalance(
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

    realm.write(() {
      // 지갑 주소 잔액 업데이트
      realmWalletAddress.confirmed = balance.confirmed;
      realmWalletAddress.unconfirmed = balance.unconfirmed;
      realmWalletAddress.total = balance.total;
    });
  }
}
