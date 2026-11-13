import 'dart:async';

import 'package:coconut_wallet/model/home/home_widget_data.dart' show HomeGoalSum;
import 'package:coconut_wallet/providers/view_model/home/hodl_insights_view_model.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/goal_reminder/goal_reminder.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart' show GoalPlanController;
import 'package:flutter/widgets.dart';

/// 목표 화면을 열지 않아도 모으기 알림을 지금 목표·잔액·설정에 맞춘다(목표 없음·확인 대기·잔액 가림·기준일).
/// 앱에 하나만 두고, 목표 화면도 같은 [reminder]를 써서 설정이 둘로 갈리지 않게 한다.
/// 지갑·잔액·설정·목표·동기화 시각이 바뀌거나 앱으로 돌아오면 [delay] 안의 변화를 모아 한 번 맞춘다.
class GoalReminderSync with WidgetsBindingObserver {
  final HomeWidgetsViewModel _data;
  final GoalReminderController reminder;
  final Duration _delay;
  Timer? _timer;
  bool _disposed = false;

  GoalReminderSync(this._data, {GoalReminderController? reminder, Duration delay = const Duration(milliseconds: 500)})
    : reminder = reminder ?? GoalReminderController(clock: () => _data.now),
      _delay = delay {
    _data.addListener(_schedule);
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  /// 시세처럼 자주 바뀌어도 [delay]마다 한 번은 맞춘다(기다리는 동안 다시 미루지 않는다).
  void _schedule() {
    if (_disposed || _timer != null) return;
    _timer = Timer(_delay, () {
      _timer = null;
      unawaited(run());
    });
  }

  /// 앱 밖에서 날짜가 바뀌었을 수 있다(이번 수량·마감일).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  /// 지금 상태로 한 번 맞춘다. 지갑을 다 불러오기 전에는 목표가 없어 보일 수 있어 하지 않는다(UX X6).
  Future<void> run() async {
    if (_disposed || _data.isWalletDataLoading) return;
    // 목표 화면이 바꾼 계획(주기·모으는 날·마감일)도 저장값으로 읽는다. 읽기만 하고 저장하지 않는다.
    final plan = GoalPlanController();
    try {
      final now = _data.now;
      // 목표 화면과 같은 범위(카드 9): 인사이트에서 저장한 지갑 선택, 저장한 적 없으면 목표 화면이 마지막으로 알림을
      // 맞춘 범위(위젯에서 들어온 범위일 수 있음), 그것도 없으면 전체. 사라진 지갑은 빼고, 남은 지갑이 없으면 전체
      final prefs = SharedPrefsRepository();
      final walletIds = HodlInsightsViewModel.prunedSelection(
        prefs.getHodlInsightsWalletIds(fallback: prefs.getGoalReminderWalletIds()),
        _data.wallets.map((wallet) => wallet.id),
      );
      final shares = _data.savingsGoalShares(walletIds: walletIds);
      final status = GoalReminderStatus.of(
        sum: HomeGoalSum.of(shares),
        scope: shares,
        plan: plan,
        now: now,
        walletsLoaded: true,
        hidesBalance: _data.hidesBalance,
        lastSyncedAt: _data.lastSyncedAt,
      );
      await reminder.apply(
        status,
        plan,
        now,
        amountText: (sats) => _data.unit.displayBitcoinAmount(sats, withUnit: true),
      );
    } finally {
      plan.dispose();
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _data.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    _data.dispose();
    reminder.dispose();
  }
}
