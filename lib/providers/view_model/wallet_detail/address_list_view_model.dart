import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/address.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/address_util.dart' as address_util;
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

class AddressListViewModel extends ChangeNotifier {
  /// Common variables ---------------------------------------------------------
  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;
  final int _walletId;

  /// Wallet variables ---------------------------------------------------------
  List<WalletAddress> _receivingAddressList = [];
  List<WalletAddress> _changeAddressList = [];
  late final WalletBase _walletBase;
  bool _showOnlyUnusedAddresses = false;
  late final StreamSubscription<WalletUpdateInfo> _walletStateSubscription;

  /// gap window 밖에서 스크롤 중 새로 발견된(잔액이 생긴) 주소를 화면에 알리기 위한 스트림
  final _discoveredAddressesController = StreamController<List<WalletAddress>>.broadcast();
  Stream<List<WalletAddress>> get discoveredAddressesStream => _discoveredAddressesController.stream;

  AddressListViewModel(this._walletProvider, this._nodeProvider, int id) : _walletId = id {
    _walletBase = _walletProvider.getWalletById(id).walletBase;
    _walletStateSubscription = _nodeProvider.getWalletStateStream(id).listen((_) => _refreshLoadedAddresses());
  }

  @override
  void dispose() {
    _walletStateSubscription.cancel();
    _discoveredAddressesController.close();
    super.dispose();
  }

  List<WalletAddress> get changeAddressList => _changeAddressList;
  List<WalletAddress> get receivingAddressList => _receivingAddressList;
  WalletBase get walletBase => _walletBase;

  /// receiveUsedIndex/changeUsedIndex는 동기화로 계속 갱신되므로 캐시하지 않고 매번 새로 조회한다.
  WalletItemBase get walletBaseItem => _walletProvider.getWalletById(_walletId);
  WalletProvider get walletProvider => _walletProvider;

  int _receivingCursor = kInitialAddressCount;
  int _changeCursor = kInitialAddressCount;

  int get receivingInitialCursor => _receivingCursor;
  int get changeInitialCursor => _changeCursor;

  bool isAddressWatched(WalletAddress address) {
    final (receiveUsedIndex, changeUsedIndex) = _walletProvider.getUsedIndexes(_walletId);
    final usedIndex = address.isChange ? changeUsedIndex : receiveUsedIndex;
    return address_util.isAddressWatched(address, usedIndex);
  }

  /// 실시간 감시(watch) 대상 주소만 모아서 반환한다(활성 사용 주소 + gap limit 트레일링 윈도우).
  /// 항상 범위가 제한되어 있어 페이지네이션 없이 한 번에 전부 가져온다.
  Future<List<WalletAddress>> getWatchedAddresses(bool isChange) async {
    final walletBaseItem = this.walletBaseItem;
    final (receiveUsedIndex, changeUsedIndex) = _walletProvider.getUsedIndexes(_walletId);
    final usedIndex = isChange ? changeUsedIndex : receiveUsedIndex;

    final activeAddresses = _walletProvider.getActiveUsedAddresses(walletBaseItem.id, isChange);
    final gapWindowAddresses = await _walletProvider.getWalletAddressList(
      walletBaseItem,
      usedIndex,
      kSubscriptionGapLimit,
      isChange,
      false,
    );

    final combined = <int, WalletAddress>{};
    for (final addr in [...activeAddresses, ...gapWindowAddresses]) {
      combined[addr.index] = addr;
    }
    final result = combined.values.toList()..sort((a, b) => a.index.compareTo(b.index));

    unawaited(_notifyDiscoveredAddresses(walletBaseItem, result, isChange));

    return result;
  }

  /// AddressList 초기화 함수(showOnlyUnusedAddresses 변경시 호출)
  Future<void> initializeAddressList(int firstCount, bool showOnlyUnusedAddresses) async {
    Logger.log(
      "[address_list_view_model.initializeAddressList] firstCount = $firstCount, showOnlyUnusedAddresses = $showOnlyUnusedAddresses",
    );
    _showOnlyUnusedAddresses = showOnlyUnusedAddresses;
    _receivingAddressList = await getWalletAddressList(walletBaseItem, -1, firstCount, false, showOnlyUnusedAddresses);
    _changeAddressList = await getWalletAddressList(walletBaseItem, -1, firstCount, true, showOnlyUnusedAddresses);
    notifyListeners();
  }

  /// 라이브 구독 이벤트 등으로 지갑 상태가 바뀌었을 때, 이미 화면에 로드된 주소 범위를
  /// DB에서 다시 읽어와 잔액/사용 여부를 최신화한다. 새 주소를 추가로 불러오진 않는다.
  Future<void> _refreshLoadedAddresses() async {
    final walletBaseItem = this.walletBaseItem;

    if (_receivingAddressList.isNotEmpty) {
      _receivingAddressList = await _walletProvider.getWalletAddressList(
        walletBaseItem,
        -1,
        _receivingAddressList.length,
        false,
        _showOnlyUnusedAddresses,
      );
    }

    if (_changeAddressList.isNotEmpty) {
      _changeAddressList = await _walletProvider.getWalletAddressList(
        walletBaseItem,
        -1,
        _changeAddressList.length,
        true,
        _showOnlyUnusedAddresses,
      );
    }

    notifyListeners();
  }

  Future<List<WalletAddress>> getWalletAddressList(
    WalletItemBase walletItem,
    int cursor,
    int count,
    bool isChange,
    bool showOnlyUnusedAddresses,
  ) async {
    final list = await _walletProvider.getWalletAddressList(
      walletItem,
      cursor,
      count,
      isChange,
      showOnlyUnusedAddresses,
    );

    if (isChange) {
      _changeCursor = list.last.index;
    } else {
      _receivingCursor = list.last.index;
    }

    unawaited(_notifyDiscoveredAddresses(walletItem, list, isChange));

    return list;
  }

  Future<void> _notifyDiscoveredAddresses(
    WalletItemBase walletItem,
    List<WalletAddress> addresses,
    bool isChange,
  ) async {
    // syncViewedAddresses는 백그라운드 isolate에서 DB를 직접 조회
    // 화면 스크롤로 방금 새로 생성된(아직 DB에 저장 안 된) 주소가 섞여 있을 수 있으므로, 주소 저장 후 확인 요청
    await _walletProvider.addAddressesWithGapLimit(
      walletItemBase: walletItem,
      newAddresses: addresses,
      isChange: isChange,
    );

    final result = await _nodeProvider.syncViewedAddresses(walletItem, addresses);
    if (result.isSuccess && result.value.isNotEmpty && !_discoveredAddressesController.isClosed) {
      _discoveredAddressesController.add(result.value);
    }
  }
}
