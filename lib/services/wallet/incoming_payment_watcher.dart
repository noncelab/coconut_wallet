import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_activity.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/foundation.dart';

typedef IncomingPayment = ({int walletId, ArkRail rail, int amount, bool isPending});

/// 감시를 시작한 뒤에 생긴 입금만 알림, 잠금 해제 뒤 늦게 불러온 예전 아크 내역은 제외
class IncomingPaymentWatcher {
  IncomingPaymentWatcher({required WalletProvider walletProvider, ArkProvider? arkProvider, required this.onReceived})
    : _walletProvider = walletProvider,
      _arkProvider = arkProvider;

  /// 지금 화면에 보이는 지갑 상세의 지갑, 이 지갑은 알리지 않음
  static final ValueNotifier<int?> visibleWalletId = ValueNotifier(null);

  final WalletProvider _walletProvider;
  final ArkProvider? _arkProvider;
  final ValueChanged<IncomingPayment> onReceived;
  final Map<int, Set<String>> _seen = {};
  final DateTime _startedAt = DateTime.now();

  void start() {
    _walletProvider.addListener(_check);
    _arkProvider?.cacheRevision.addListener(_check);
    _check();
  }

  void stop() {
    _walletProvider.removeListener(_check);
    _arkProvider?.cacheRevision.removeListener(_check);
  }

  void _check() {
    for (final wallet in _walletProvider.walletItemList) {
      final seen = _seen.putIfAbsent(wallet.id, () => {});
      for (final activity in _walletProvider.getWalletActivities(wallet.id)) {
        final isIncoming = switch (activity) {
          OnchainActivity(:final tx) => tx.transactionType == TransactionType.received,
          ArkActivity() => !activity.isPending && activity.label == null && activity.amount > 0,
        };
        if (!isIncoming || !seen.add(activity.key) || activity.time.isBefore(_startedAt)) continue;
        if (visibleWalletId.value == wallet.id) continue;
        onReceived((
          walletId: wallet.id,
          rail: activity.rail,
          amount: activity.displayAmount,
          isPending: activity.isPending,
        ));
      }
    }
  }
}
