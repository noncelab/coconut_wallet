import 'dart:async';
import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/widget_configure_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../../mock/wallet_mock.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  FiatCode selectedFiat = FiatCode.KRW;
  bool fakeActive = false;
  int? fakeTotal;
  final List<String> calls = [];

  @override
  bool get isFakeBalanceActive => fakeActive;

  @override
  int? get fakeBalanceTotalAmount => fakeTotal;

  @override
  Future<void> toggleFakeBalanceActivation(bool isActive) async {
    calls.add('toggle:$isActive');
    fakeActive = isActive;
    if (!isActive) fakeTotal = null;
  }

  @override
  Future<void> distributeFakeBalance(
    List<WalletItemBase> wallets, {
    required bool isFakeBalanceActive,
    double? fakeBalanceTotalSats,
  }) async {
    calls.add('distribute:${fakeBalanceTotalSats!.toInt()}:${wallets.length}');
    fakeTotal = fakeBalanceTotalSats.toInt();
  }

  @override
  Future<void> setFakeBalanceTotalAmount(int balance) async {
    calls.add('total:$balance');
    fakeTotal = balance;
  }
}

/// 저장소 테스트에 있는 서로 다른 공개 테스트 계정(사용자 정보 아님, 체크섬은 BIP-380)
const _accounts = [
  "wpkh([D45AA182/84'/1'/0']vpub5YtEovN9MqeUZxWqdpUKngsiaLCPFY34KpWGQVk9Tjq8G5SYcRFj9s5aCKeAQYGunG7LrFkA5obtH8kPJiv92JtWHfRvnir6PDvhd4p93Pp/<0;1>/*)#rcn2hj6y",
  "wpkh([98C7D774/84'/1'/0']vpub5ZZ1q76vi2LR9PeQDoV13u8TZwsyqKa7yBfD3GnPPvBjVU9ZnBTMkwzCHCVBZaPHDKJNEdMKo8MTyrQ9234idzSG9nHFD6hsUB8HJ14NBg7/<0;1>/*)#7ra9g9d8",
  "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)#k8xga4tv",
];

/// 한 키의 저장만 거절하거나 꺼짐 표시 쓰기를 붙잡아 두는 기기 저장소(실제 SharedPreferences와 저장소 코드를 그대로 쓴다)
class _RejectingStore extends InMemorySharedPreferencesStore {
  _RejectingStore(super.data) : super.withData();
  String? rejectedKey;
  Completer<void>? gate;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == rejectedKey) return false;
    if (gate != null && key.contains('WALLET_TARGET_DISABLED')) await gate!.future;
    return super.setValue(valueType, key, value);
  }
}

/// 목표들을 한 번에 바꾸는 가짜 저장 함수: [store]를 바꾸고 한 번 쓴 묶음을 [writes]에 남긴다. 바꿀 것이 없으면 쓰지 않는다.
/// [fails]가 참이면 쓰기 전에 던진다(아무것도 바뀌지 않음).
WalletTargetsUpdate _batch(Map<int, int?> store, List<Map<int, int?>> writes, {bool Function()? fails}) => (
  change,
) async {
  final changes = change({
    for (final entry in store.entries)
      if (entry.value != null) entry.key: entry.value!,
  });
  if (changes.isEmpty) return const {};
  writes.add(changes);
  if (fails?.call() ?? false) throw StateError('map write failed');
  store.addAll(changes);
  return changes;
};

void main() {
  late _Preferences preferences;
  // 서로 다른 계정. 모의 지갑은 기본으로 같은 지갑 정보라 같은 계정이 된다(아래 '같은 계정' 테스트).
  final wallets = [
    // 서로 다른 공개 테스트 계정(무작위가 아니라 늘 같은 지갑, Astra)
    for (final (id, descriptor) in _accounts.indexed)
      SinglesigWalletItem(
        id: id + 1,
        name: 'test_wallet${id + 1}',
        colorIndex: 0,
        iconIndex: 0,
        descriptor: descriptor,
      ),
  ];

  setUp(() => preferences = _Preferences());

  WidgetConfigureViewModel create(
    HomeWidgetSettingsSpec spec, {
    HomeWidgetSettings? initial,
    List<WalletItemBase>? list,
  }) =>
      WidgetConfigureViewModel(spec: spec, wallets: list ?? wallets, preferenceProvider: preferences, initial: initial);

  group('지갑', () {
    const spec = HomeWidgetSettingsSpec(wallets: true);

    test('새 위젯은 모든 지갑으로 시작하고 null로 저장한다', () {
      final viewModel = create(spec);
      expect(viewModel.isNew, isTrue);
      expect(viewModel.allWallets, isTrue);
      expect(viewModel.settings.walletIds, isNull);
    });

    test('개별 지갑을 고르면 모든 지갑이 풀리고, 모든 지갑을 고르면 개별 선택이 풀린다', () {
      final viewModel = create(spec);
      viewModel.toggleWallet(2);
      viewModel.toggleWallet(1);
      expect(viewModel.allWallets, isFalse);
      expect(viewModel.settings.walletIds, [1, 2]);
      viewModel.selectAllWallets();
      expect(viewModel.isWalletSelected(1), isFalse);
      expect(viewModel.settings.walletIds, isNull);
    });

    test('마지막 개별 지갑은 해제할 수 없다', () {
      final viewModel = create(spec);
      viewModel.toggleWallet(3);
      viewModel.toggleWallet(3);
      expect(viewModel.settings.walletIds, [3]);
    });

    test('저장된 지갑 중 없어진 지갑은 빼고, 모두 없으면 남은 지갑으로 넓히지 않는다', () {
      expect(create(spec, initial: const HomeWidgetSettings(walletIds: [2, 9])).settings.walletIds, [2]);
      final stale = create(spec, initial: const HomeWidgetSettings(walletIds: [9]));
      expect(stale.allWallets, isFalse);
      expect(stale.settings.walletIds, isEmpty);
    });
  });

  group('통화', () {
    test('여러 통화 위젯은 앱 기본 통화를 먼저 두고 최대 개수만큼 고른 상태로 시작한다', () {
      preferences.selectedFiat = FiatCode.USD;
      final viewModel = create(
        const HomeWidgetSettingsSpec(currencies: HomeWidgetCurrencyMode.multiple, maxCurrencies: 3),
      );
      expect(viewModel.fiatOptions.first, FiatCode.USD);
      expect(viewModel.settings.fiats, [FiatCode.USD, FiatCode.KRW, FiatCode.JPY]);
      expect(viewModel.canSelectFiat(FiatCode.EUR), isFalse);
    });

    test('통화는 0개로 만들 수 없고, 고른 순서는 화면 순서를 따른다', () {
      final viewModel = create(
        const HomeWidgetSettingsSpec(currencies: HomeWidgetCurrencyMode.multiple, maxCurrencies: 4),
      );
      for (final fiat in [FiatCode.KRW, FiatCode.USD, FiatCode.JPY]) {
        viewModel.toggleFiat(fiat);
      }
      expect(viewModel.settings.fiats, [FiatCode.EUR]);
      viewModel.toggleFiat(FiatCode.EUR);
      expect(viewModel.settings.fiats, [FiatCode.EUR]);
      viewModel.toggleFiat(FiatCode.KRW);
      expect(viewModel.settings.fiats, [FiatCode.KRW, FiatCode.EUR]);
    });

    test('한 통화 위젯은 고르면 바뀐다', () {
      final viewModel = create(const HomeWidgetSettingsSpec(currencies: HomeWidgetCurrencyMode.single));
      expect(viewModel.settings.fiats, [FiatCode.KRW]);
      viewModel.toggleFiat(FiatCode.JPY);
      expect(viewModel.settings.fiats, [FiatCode.JPY]);
    });

    test('앱 기본 통화가 바뀌어도 저장된 선택은 그대로다', () {
      preferences.selectedFiat = FiatCode.EUR;
      final viewModel = create(
        const HomeWidgetSettingsSpec(currencies: HomeWidgetCurrencyMode.multiple, maxCurrencies: 4),
        initial: const HomeWidgetSettings(fiats: [FiatCode.KRW]),
      );
      expect(viewModel.defaultFiat, FiatCode.EUR);
      expect(viewModel.settings.fiats, [FiatCode.KRW]);
    });
  });

  test('기간은 1주로 시작하고 저장값을 불러온다', () {
    const spec = HomeWidgetSettingsSpec(period: true);
    expect(create(spec).settings.period, HomeWidgetPeriod.week);
    expect(
      create(spec, initial: const HomeWidgetSettings(period: HomeWidgetPeriod.month)).period,
      HomeWidgetPeriod.month,
    );
  });

  group('가짜 잔액', () {
    const spec = HomeWidgetSettingsSpec(wallets: true, fakeBalance: true);

    test('켜고 금액이 없으면 저장할 수 없다', () {
      final viewModel = create(spec);
      viewModel.setFakeBalanceActive(true);
      expect(viewModel.canSubmit, isFalse);
      viewModel.setFakeBalance(21000000 * 100000000 + 1);
      expect(viewModel.canSubmit, isFalse);
      viewModel.setFakeBalance(50000);
      expect(viewModel.canSubmit, isTrue);
    });

    test('켜면 기존 앱 설정에 금액을 나눠 저장하고 켠다', () async {
      final viewModel = create(spec);
      viewModel.setFakeBalanceActive(true);
      viewModel.setFakeBalance(50000);
      await viewModel.commitFakeBalance();
      expect(preferences.calls, ['distribute:50000:3', 'toggle:true']);
    });

    test('이미 켜져 있고 금액이 같으면 아무것도 바꾸지 않는다', () async {
      preferences
        ..fakeActive = true
        ..fakeTotal = 7000;
      final viewModel = create(spec);
      expect(viewModel.fakeBalanceActive, isTrue);
      expect(viewModel.fakeBalance, 7000);
      await viewModel.commitFakeBalance();
      expect(preferences.calls, isEmpty);
    });

    test('끄면 기존 앱 설정을 끈다', () async {
      preferences
        ..fakeActive = true
        ..fakeTotal = 7000;
      final viewModel = create(spec);
      viewModel.setFakeBalanceActive(false);
      await viewModel.commitFakeBalance();
      expect(preferences.calls, ['toggle:false']);
    });

    test('가짜 잔액이 없는 위젯은 앱 설정을 건드리지 않는다', () async {
      preferences.fakeActive = true;
      final viewModel = create(const HomeWidgetSettingsSpec(wallets: true));
      viewModel.setFakeBalanceActive(false);
      await viewModel.commitFakeBalance();
      expect(preferences.calls, isEmpty);
    });
  });

  test('설정값은 HomeItem.configuration으로 저장했다가 그대로 읽힌다', () {
    const settings = HomeWidgetSettings(
      walletIds: [1, 3],
      fiats: [FiatCode.USD, FiatCode.EUR],
      period: HomeWidgetPeriod.month,
    );
    expect(HomeWidgetSettings.fromConfiguration(settings.toConfiguration()), settings);
    expect(
      HomeWidgetSettings.fromConfiguration(const {
        'walletIds': [2],
      }).walletIds,
      [2],
    );
    expect(const HomeWidgetSettings().toConfiguration(), isEmpty);
  });

  test('only the periods the widget allows can be chosen, and a saved one outside them falls back', () {
    const fiatTrend = HomeWidgetSettingsSpec(period: true, periods: [HomeWidgetPeriod.week, HomeWidgetPeriod.month]);
    expect(
      create(fiatTrend, initial: const HomeWidgetSettings(period: HomeWidgetPeriod.year)).period,
      HomeWidgetPeriod.week,
    );
    const activity = HomeWidgetSettingsSpec(period: true);
    expect(activity.periods, HomeWidgetPeriod.widgetPeriods);
    expect(
      create(activity, initial: const HomeWidgetSettings(period: HomeWidgetPeriod.year)).period,
      HomeWidgetPeriod.year,
    );
  });

  test('wallet goals start from the saved targets, block a goal over the supply, and save only what changed', () async {
    final saved = <int, int?>{1: 100000000, 2: null, 3: 5000000};
    final writes = <Map<int, int?>>[];
    final viewModel = WidgetConfigureViewModel(
      spec: const HomeWidgetSettingsSpec(wallets: true, goals: true),
      wallets: wallets,
      preferenceProvider: preferences,
      initial: const HomeWidgetSettings(),
      targetOf: (id) => saved[id],
      saveTargets: _batch(saved, writes),
    );
    expect(viewModel.targetOf(1), 100000000);
    viewModel.setTarget(2, 30000000);
    viewModel.setTarget(3, 0);
    viewModel.setTarget(1, 21000000 * 100000000 + 1);
    expect(viewModel.canSubmit, isFalse);
    viewModel.setTarget(1, 100000000);
    expect(viewModel.canSubmit, isTrue);
    await viewModel.commitTargets();
    // 바뀐 지갑만, 한 번에
    expect(writes, [
      {2: 30000000, 3: null},
    ]);
  });

  group('같은 계정(결정 ⑦)', () {
    // 같은 지갑 정보: 핫월렛과 그 보기 전용 지갑처럼 같은 계정
    final twins = [WalletMock.createSingleSigWalletItem(id: 1), WalletMock.createSingleSigWalletItem(id: 2)];

    WidgetConfigureViewModel goals(
      Map<int, int?> saved,
      List<Map<int, int?>> writes, {
      List<WalletItemBase>? list,
      bool Function()? fails,
    }) => WidgetConfigureViewModel(
      spec: const HomeWidgetSettingsSpec(goals: true),
      wallets: list ?? twins,
      preferenceProvider: preferences,
      initial: const HomeWidgetSettings(),
      targetOf: (id) => saved[id],
      saveTargets: _batch(saved, writes, fails: fails),
    );

    test('a second wallet without a goal is blocked while the first has one, and clearing the first frees it', () {
      final viewModel = goals({1: 100000000}, []);
      expect((viewModel.goalBlocked(1), viewModel.goalBlocked(2)), (false, true));
      expect((viewModel.goalExcluded(1), viewModel.goalExcluded(2)), (false, false));
      viewModel.setTarget(1, null);
      expect(viewModel.goalBlocked(2), isFalse);
    });

    test('existing goals on both stay editable; only the smaller one is marked as not counted', () {
      final viewModel = goals({1: 100000000, 2: 200000000}, []);
      expect((viewModel.goalBlocked(1), viewModel.goalBlocked(2)), (false, false));
      expect((viewModel.goalExcluded(1), viewModel.goalExcluded(2)), (true, false));
      viewModel.setTarget(1, 200000000);
      expect((viewModel.goalExcluded(1), viewModel.goalExcluded(2)), (false, false));
    });

    // Fable N1: 예전 데이터에서 칸을 비우고 새 숫자를 쓰는 사람을 막지 않는다
    test('clearing an existing goal to type a new one keeps the field open', () async {
      final writes = <Map<int, int?>>[];
      final viewModel = goals({1: 100000000, 2: 200000000}, writes);
      viewModel.setTarget(1, null);
      expect(viewModel.goalBlocked(1), isFalse);
      viewModel.setTarget(1, 150000000);
      await viewModel.commitTargets();
      expect(writes, [
        {1: 150000000},
      ]);
    });

    test('saving checks again: a new second goal is not written', () async {
      final writes = <Map<int, int?>>[];
      final viewModel = goals({1: 100000000}, writes);
      viewModel.setTarget(2, 50000000);
      await viewModel.commitTargets();
      expect(writes, isEmpty);
    });

    test('moving the goal to the other wallet in the same save is one write', () async {
      final writes = <Map<int, int?>>[];
      final viewModel = goals({1: 100000000}, writes);
      viewModel.setTarget(1, null);
      viewModel.setTarget(2, 50000000);
      await viewModel.commitTargets();
      expect(writes, [
        {1: null, 2: 50000000},
      ]);
    });

    test('two new goals in one save keep only the first wallet', () async {
      final writes = <Map<int, int?>>[];
      final viewModel = goals({}, writes);
      viewModel.setTarget(2, 50000000);
      viewModel.setTarget(1, 70000000);
      expect(await viewModel.commitTargets(), {2});
      expect(writes, [
        {1: 70000000},
      ]);
    });

    // B1-b(2라운드 정리): 저장할 때 지금 저장값으로 정하고, 목표 맵은 한 번에 쓴다. 다 바뀌거나 하나도 안 바뀐다
    group('saving against what is stored now', () {
      // 계정 둘: 1·2번이 한 계정, 3·4번이 다른 계정(고정 공개 테스트 계정)
      final twoAccounts = [
        for (final (id, account) in [(1, 0), (2, 0), (3, 1), (4, 1)])
          SinglesigWalletItem(id: id, name: 'w$id', colorIndex: 0, iconIndex: 0, descriptor: _accounts[account]),
      ];

      test('a goal saved elsewhere while the sheet is open keeps the new second goal out', () async {
        final store = <int, int?>{};
        final writes = <Map<int, int?>>[];
        final viewModel = goals(store, writes);
        viewModel.setTarget(2, 50000000);
        store[1] = 100000000;
        expect(await viewModel.commitTargets(), {2});
        expect(writes, isEmpty);
        expect(store, {1: 100000000});
      });

      test('a failed save changes nothing, and saving again starts from what is stored', () async {
        final store = <int, int?>{2: 100000000};
        final writes = <Map<int, int?>>[];
        var fail = true;
        final viewModel = goals(store, writes, fails: () => fail);
        viewModel.setTarget(2, null);
        viewModel.setTarget(1, 50000000);
        await expectLater(viewModel.commitTargets(), throwsStateError);
        expect(store, {2: 100000000});
        fail = false;
        writes.clear();
        await viewModel.commitTargets();
        expect(writes, [
          {1: 50000000, 2: null},
        ]);
        expect(store, {2: null, 1: 50000000});
      });

      test('deleting goals in two accounts at once changes both or neither', () async {
        // Astra B1-b: 서로 다른 계정 A=1 BTC·B=2 BTC를 함께 지움. 7·8판은 A만 지워진 뒤 되살리기도 실패하면 A를 잃었다
        final store = <int, int?>{1: 100000000, 3: 200000000};
        final writes = <Map<int, int?>>[];
        var fail = true;
        final viewModel = goals(store, writes, list: twoAccounts, fails: () => fail);
        viewModel.setTarget(1, null);
        viewModel.setTarget(3, null);
        await expectLater(viewModel.commitTargets(), throwsStateError);
        expect(store, {1: 100000000, 3: 200000000});
        fail = false;
        await viewModel.commitTargets();
        expect(store, {1: null, 3: null});
      });

      test('moving goals in two accounts is one write', () async {
        final store = <int, int?>{1: 100000000, 3: 200000000};
        final writes = <Map<int, int?>>[];
        final viewModel = goals(store, writes, list: twoAccounts);
        viewModel.setTarget(1, null);
        viewModel.setTarget(2, 50000000);
        viewModel.setTarget(3, null);
        viewModel.setTarget(4, 150000000);
        await viewModel.commitTargets();
        expect(writes, [
          {1: null, 2: 50000000, 3: null, 4: 150000000},
        ]);
      });

      // 실제 저장소 코드(SharedPreferences + updateWalletTargets)
      group('with the real store', () {
        late _RejectingStore device;
        late SharedPrefsRepository repository;

        setUp(() async {
          TestWidgetsFlutterBinding.ensureInitialized();
          final initial = <String, Object>{
            SharedPrefKeys.kWalletTargetSatsMap: jsonEncode({'2': 100000000}),
          };
          SharedPreferences.setMockInitialValues(initial);
          device = _RejectingStore({for (final entry in initial.entries) 'flutter.${entry.key}': entry.value});
          SharedPreferencesStorePlatform.instance = device;
          repository = SharedPrefsRepository();
          await repository.init();
        });

        WidgetConfigureViewModel sheet() => WidgetConfigureViewModel(
          spec: const HomeWidgetSettingsSpec(goals: true),
          wallets: twins,
          preferenceProvider: preferences,
          initial: const HomeWidgetSettings(),
          targetOf: repository.getWalletTargetSats,
          saveTargets: repository.updateWalletTargets,
        );

        test('a rejected goal map write changes no goal', () async {
          final viewModel = sheet();
          viewModel.setTarget(2, null);
          viewModel.setTarget(1, 50000000);
          device.rejectedKey = 'flutter.${SharedPrefKeys.kWalletTargetSatsMap}';
          await expectLater(viewModel.commitTargets(), throwsStateError);
          await repository.sharedPrefs.reload();
          expect((repository.getWalletTargetSats(1), repository.getWalletTargetSats(2)), (null, 100000000));
        });

        test('a rejected off flag is reported, the moved goal stays saved and the sheet reads it again', () async {
          // Astra: 7·8판은 꺼짐 표시 실패를 삼켰다. 이제 오류를 올린다. 목표 맵은 이미 한 번에 저장돼 있다
          final viewModel = sheet();
          viewModel.setTarget(2, null);
          viewModel.setTarget(1, 50000000);
          device.rejectedKey = 'flutter.${SharedPrefKeys.walletTargetDisabled(2)}';
          await expectLater(viewModel.commitTargets(), throwsStateError);
          await repository.sharedPrefs.reload();
          expect((repository.getWalletTargetSats(1), repository.getWalletTargetSats(2)), (50000000, null));
          // 시트는 다시 읽은 저장값과 비교한다: 같은 편집을 다시 저장하면 쓸 것이 없다
          device.rejectedKey = null;
          expect(await viewModel.commitTargets(), isEmpty);
        });

        test('goal saves take turns: a later save decides from what the earlier one stored', () async {
          // 앞 저장의 꺼짐 표시 쓰기를 붙잡아 둔다. 뒤 저장은 앞 저장이 끝난 뒤에야 저장값을 받는다
          device.gate = Completer<void>();
          final first = repository.updateWalletTargets((_) => {1: 50000000});
          Map<int, int>? seenLater;
          final later = repository.updateWalletTargets((current) {
            seenLater = Map.of(current);
            return const {};
          });
          await pumpEventQueue();
          expect(seenLater, isNull);
          device.gate!.complete();
          await Future.wait([first, later]);
          expect(seenLater, {2: 100000000, 1: 50000000});
        });
      });
    });
  });
}
