import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/goal_reminder/goal_reminder.dart';
import 'package:coconut_wallet/services/goal_reminder/goal_reminder_sync.dart';
import 'package:coconut_wallet/services/historical_bitcoin_price_service.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart' show GoalPlanCycle;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mock/wallet_mock.dart';

/// 목표 화면을 한 번도 열지 않은 채로 모으기 알림이 맞춰지는지(리드 11/12: 잔액 가림·확인 대기·목표 지움·기준일).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 11, 12, 10);
  final lastSync = DateTime(2026, 11, 10, 8);
  late _Wallets wallets;
  late _Preferences preferences;
  late _Scheduler scheduler;
  late ValueNotifier<int> nodeUpdates;
  late GoalReminderSync sync;
  DateTime? syncedAt;
  final closed = <GoalReminderSync>{};

  /// 같은 기기 저장값으로 앱을 연다. 목표 화면은 열지 않는다.
  Future<void> reopen({
    required Balance balance,
    DateTime? lastSyncedAt,
    WalletLoadState loadState = WalletLoadState.loadCompleted,
    bool Function(int walletId)? isWalletSynced,
  }) async {
    syncedAt = lastSyncedAt;
    wallets = _Wallets([WalletMock.createSingleSigWalletItem(id: 1)], {1: balance}, loadState);
    preferences = _Preferences();
    scheduler = _Scheduler();
    nodeUpdates = ValueNotifier(0);
    sync = GoalReminderSync(
      HomeWidgetsViewModel(
        walletProvider: wallets,
        preferenceProvider: preferences,
        priceProvider: _Prices(),
        targetSatsOf: SharedPrefsRepository().getWalletTargetSats,
        historicalPriceService: _History(),
        now: () => now,
        walletUpdates: Listenable.merge([nodeUpdates, SharedPrefsRepository().walletTargetChanges]),
        lastSyncedAt: () => syncedAt,
        isWalletSynced: isWalletSynced,
        usesFakeBalance: false,
      ),
      reminder: GoalReminderController(scheduler: scheduler, clock: () => now),
      delay: Duration.zero,
    );
    final opened = sync;
    addTearDown(() {
      if (!closed.contains(opened)) opened.dispose();
    });
    await pumpEventQueue();
  }

  /// 앱을 닫는다
  void close() {
    closed.add(sync);
    sync.dispose();
  }

  /// 1번 지갑에 목표 1 BTC, 알림과 수량 넣기를 켜 둔 채 앱을 처음 연다.
  Future<void> start({
    required Balance balance,
    DateTime? lastSyncedAt,
    WalletLoadState loadState = WalletLoadState.loadCompleted,
    bool Function(int walletId)? isWalletSynced,
  }) async {
    SharedPreferences.setMockInitialValues({
      SharedPrefKeys.kWalletTargetSatsMap: jsonEncode({'1': 100000000}),
      SharedPrefKeys.kGoalReminder: jsonEncode(const GoalReminderSettings(enabled: true, showAmount: true).toJson()),
    });
    SharedPrefsRepository().setSharedPreferencesForTest(await SharedPreferences.getInstance());
    await reopen(balance: balance, lastSyncedAt: lastSyncedAt, loadState: loadState, isWalletSynced: isWalletSynced);
  }

  String lastBody() => scheduler.contents.last.body;

  test('hiding the balance takes the amount out of the scheduled reminder', () async {
    await start(balance: Balance(50000000, 0), lastSyncedAt: lastSync);
    expect(lastBody(), contains('BTC'));
    preferences.hideBalance();
    await pumpEventQueue();
    expect(lastBody(), t.hodl_insights.goal_reminder_body_weekly);
    expect(sync.reminder.settings.enabled, isTrue);
  });

  test('a pending deposit keeps the reminder on without the amount, and its confirmation turns it off', () async {
    // 목표 1 BTC: 확인 0.9 + 확인 전 0.2
    await start(balance: Balance(90000000, 20000000), lastSyncedAt: lastSync);
    expect(sync.reminder.settings.enabled, isTrue);
    expect(lastBody(), t.hodl_insights.goal_reminder_body_weekly);
    wallets.balances[1] = Balance(110000000, 0);
    nodeUpdates.value++;
    await pumpEventQueue();
    expect(sync.reminder.settings.enabled, isFalse);
    expect(sync.reminder.settings.offReason, GoalReminderOffReason.reached);
    expect(scheduler.cancels, 1);
  });

  test('turns the reminder off once the last goal is removed, never while the wallets are still loading', () async {
    await start(balance: Balance(50000000, 0), lastSyncedAt: lastSync, loadState: WalletLoadState.loadingFromDB);
    // 불러오는 동안은 지갑 목록이 비어 목표가 없어 보이지만 끄지 않는다(UX X6)
    expect(sync.reminder.settings.enabled, isTrue);
    expect(scheduler.calls, 0);
    wallets.finishLoading();
    await pumpEventQueue();
    expect(sync.reminder.settings.enabled, isTrue);
    expect(lastBody(), contains('BTC'));
    // 지갑 정보 화면 등에서 목표를 지움(목표 화면은 열지 않음)
    await SharedPrefsRepository().updateWalletTarget(1, null);
    await pumpEventQueue();
    expect(sync.reminder.settings.enabled, isFalse);
    expect(sync.reminder.settings.offReason, GoalReminderOffReason.noGoal);
    expect(scheduler.cancels, 1);
  });

  test('dates the amount by the last sync and leaves it out before the first sync', () async {
    await start(balance: Balance(50000000, 0));
    expect(lastBody(), t.hodl_insights.goal_reminder_body_weekly);
    syncedAt = lastSync;
    nodeUpdates.value++;
    await pumpEventQueue();
    expect(lastBody(), contains('2026.11.10'));
    expect(lastBody(), isNot(contains('2026.11.12')));
  });

  test('a goal wallet that has not synced yet gets no amount from another account\'s earlier sync', () async {
    // Astra B1-a.2: 11.10에 다른 계정으로 마지막 동기화, 11.12에 새 계정(잔액 0, 아직 동기화 전)에 목표 1 BTC
    var synced = false;
    await start(balance: Balance(0, 0), lastSyncedAt: lastSync, isWalletSynced: (_) => synced);
    expect(lastBody(), t.hodl_insights.goal_reminder_body_weekly);
    synced = true;
    nodeUpdates.value++;
    await pumpEventQueue();
    expect(lastBody(), contains('BTC'));
  });

  // 6-2 A(Max 11/13): 동기화가 끝나기 전에는 걸어 둔 수량을 기준일과 함께 그대로, 목표가 바뀌면 수량 없이
  test('a quick open and close before the sync keeps the amount and its date', () async {
    await start(balance: Balance(50000000, 0), lastSyncedAt: lastSync);
    final booked = lastBody();
    expect(booked, allOf(contains('BTC'), contains('2026.11.10')));
    // 다시 열었지만 동기화가 끝나기 전에 닫는다(오프라인 포함). 몇 번이어도 같은 수량과 기준일로 다시 건다
    for (var open = 0; open < 2; open++) {
      close();
      await reopen(balance: Balance(50000000, 0), lastSyncedAt: lastSync, isWalletSynced: (_) => false);
      expect(scheduler.contents.map((content) => content.body), [booked]);
    }
  });

  test('changing the goal while offline books the reminder without an amount until the next sync', () async {
    await start(balance: Balance(50000000, 0), lastSyncedAt: lastSync);
    close();
    var synced = false;
    await reopen(balance: Balance(50000000, 0), lastSyncedAt: lastSync, isWalletSynced: (_) => synced);
    expect(lastBody(), contains('2026.11.10'));
    await SharedPrefsRepository().updateWalletTarget(1, 200000000);
    await pumpEventQueue();
    expect(lastBody(), t.hodl_insights.goal_reminder_body_weekly);
    // 아직 오프라인이면 다시 열어도 수량 없이
    close();
    await reopen(balance: Balance(50000000, 0), lastSyncedAt: lastSync, isWalletSynced: (_) => synced);
    expect(lastBody(), t.hodl_insights.goal_reminder_body_weekly);
    // 동기화가 끝나면 새 목표로 다시 계산한 수량과 그 날짜
    synced = true;
    syncedAt = DateTime(2026, 11, 12, 9);
    nodeUpdates.value++;
    await pumpEventQueue();
    expect(lastBody(), allOf(contains('BTC'), contains('2026.11.12')));
  });
}

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  final List<WalletItemBase> _wallets;
  final Map<int, Balance> balances;

  _Wallets(this._wallets, Map<int, Balance> balances, WalletLoadState loadState)
    : balances = {...balances},
      walletLoadStateNotifier = ValueNotifier(loadState);

  @override
  final ValueNotifier<WalletLoadState> walletLoadStateNotifier;

  @override
  late final ValueNotifier<List<WalletItemBase>> walletItemListNotifier = ValueNotifier(_wallets);

  @override
  WalletLoadState get walletLoadState => walletLoadStateNotifier.value;

  /// 불러오는 동안은 지갑이 없다
  @override
  List<WalletItemBase> get walletItemList => walletLoadState == WalletLoadState.loadCompleted ? _wallets : const [];

  void finishLoading() => walletLoadStateNotifier.value = WalletLoadState.loadCompleted;

  @override
  Balance getWalletBalance(int walletId) => balances[walletId] ?? Balance(0, 0);

  @override
  List<UtxoState> getUtxoListByStatus(int walletId, UtxoStatus utxoStatus) => const [];

  @override
  bool hasUnconfirmedAddress(int walletId) => false;
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  bool _hidden = false;

  void hideBalance() {
    _hidden = true;
    notifyListeners();
  }

  @override
  bool get isBalanceHidden => _hidden;

  @override
  bool get isFakeBalanceActive => false;

  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;

  @override
  FiatCode get selectedFiat => FiatCode.KRW;

  @override
  List<int> get walletOrder => const [];
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  int? getBitcoinPriceForFiat(FiatCode fiatCode) => null;
}

class _History extends Fake implements HistoricalBitcoinPriceService {}

class _Scheduler implements GoalReminderScheduler {
  final List<GoalReminderContent> contents = [];
  int calls = 0;
  int cancels = 0;

  @override
  Future<void> schedule(
    GoalReminderSettings settings,
    GoalPlanCycle cycle,
    GoalReminderContent content,
    List<DateTime> times, {
    bool keepBooked = false,
  }) async {
    calls++;
    contents.add(content);
  }

  @override
  Future<void> cancel() async {
    calls++;
    cancels++;
  }

  @override
  Future<bool?> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> openSettings() async {}

  @override
  Stream<void> get taps => const Stream.empty();

  @override
  Future<bool> consumeLaunchTap() async => false;
}
