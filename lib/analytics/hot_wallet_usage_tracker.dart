import 'dart:async';

import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter/foundation.dart';

/// 핫월렛에 거래가 하나라도 생기면 `hot_wallet_in_use` 사용자 속성을 `true`로 한 번만 보낸다.
///
/// 수집을 최소화하기 위해 `false`는 보내지 않는다. 지갑을 비우거나 지워도 값이 바뀌지 않으므로
/// "쓰기 시작했는가"만 남고, 이후의 사용 변화나 지갑별 정보는 남지 않는다.
class HotWalletUsageTracker {
  HotWalletUsageTracker({
    required Stream<NodeSyncState> syncStateStream,
    required ValueListenable<List<WalletItemBase>> walletItemList,
    required bool Function(int walletId) hasTransactionHistory,
    required AnalyticsService analyticsService,
  }) : _walletItemList = walletItemList,
       _hasTransactionHistory = hasTransactionHistory,
       _analyticsService = analyticsService {
    _syncStateSubscription = syncStateStream.listen((state) {
      if (state == NodeSyncState.completed) _update();
    });
  }

  final ValueListenable<List<WalletItemBase>> _walletItemList;
  final bool Function(int walletId) _hasTransactionHistory;
  final AnalyticsService _analyticsService;
  late final StreamSubscription<NodeSyncState> _syncStateSubscription;
  bool _hasSent = false;

  void _update() {
    if (_hasSent) return;
    final isInUse = _walletItemList.value.any((wallet) => wallet.hasLocalKey && _hasTransactionHistory(wallet.id));
    if (!isInUse) return;
    _hasSent = true;
    _analyticsService.setUserProperty(name: AnalyticsUserPropertyNames.hotWalletInUse, value: 'true');
  }

  void dispose() {
    _syncStateSubscription.cancel();
  }
}
