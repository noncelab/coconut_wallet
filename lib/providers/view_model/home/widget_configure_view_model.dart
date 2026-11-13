import 'package:coconut_wallet/constants/consensus_constants.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:flutter/foundation.dart';

/// 위젯 설정 시트. [initial]이 null이면 새로 추가하는 위젯이다.
/// 목표들을 한 번에 바꾸는 저장 함수([SharedPrefsRepository.updateWalletTargets]). 차례가 오면 지금 저장된 맵을 받아
/// 바꿀 지갑과 값(null이면 지움)을 돌려준다.
typedef WalletTargetsUpdate = Future<Map<int, int?>> Function(Map<int, int?> Function(Map<int, int> current) change);

class WidgetConfigureViewModel extends ChangeNotifier {
  final HomeWidgetSettingsSpec spec;
  final List<WalletItemBase> wallets;
  final PreferenceProvider _preferenceProvider;
  final bool isNew;

  late final FiatCode defaultFiat = _preferenceProvider.selectedFiat;
  late final List<FiatCode> fiatOptions = fiatsWithDefaultFirst(defaultFiat);

  final Set<int> _walletIds = {};
  bool _allWallets = true;
  List<FiatCode> _fiats = [];
  bool _showsAllFiats = false;
  List<FiatCode> _collapsedFiats = [];
  HomeWidgetPeriod _period = HomeWidgetPeriod.week;
  HomeSpan? _span;

  late final bool _wasFakeBalanceActive = _preferenceProvider.isFakeBalanceActive;
  late final int? _savedFakeBalance = _preferenceProvider.fakeBalanceTotalAmount;
  late bool _fakeBalanceActive = _wasFakeBalanceActive;
  late int? _fakeBalance = _savedFakeBalance;

  final int? Function(int walletId) _targetOf;
  final WalletTargetsUpdate _saveTargets;

  /// 시트를 연 때(저장에 실패했으면 그 뒤 다시 읽은) 목표. 이번 편집이 무엇을 바꿨는지 이 값과 비교한다.
  late final Map<int, int?> _savedTargets = {for (final wallet in wallets) wallet.id: _targetOf(wallet.id)};
  late final Map<int, int?> _targets = Map.of(_savedTargets);

  WidgetConfigureViewModel({
    required this.spec,
    required this.wallets,
    required PreferenceProvider preferenceProvider,
    HomeWidgetSettings? initial,
    HomeSpan? initialSpan,
    int? Function(int walletId)? targetOf,
    WalletTargetsUpdate? saveTargets,
  }) : _preferenceProvider = preferenceProvider,
       _targetOf = targetOf ?? ((_) => null),
       _saveTargets = saveTargets ?? ((_) async => const {}),
       isNew = initial == null {
    // null은 전체 지갑. 저장된 목록이 비었거나 id가 모두 사라져도 남은 지갑으로 넓히지 않는다.
    final savedIds = initial?.walletIds;
    if (savedIds != null) {
      _allWallets = false;
      _walletIds.addAll(savedIds.where((id) => wallets.any((wallet) => wallet.id == id)));
    }
    _fiats = switch (spec.currencies) {
      HomeWidgetCurrencyMode.none => const [],
      _ when initial?.fiats != null => initial!.fiats!.take(spec.maxCurrencies).toList(),
      HomeWidgetCurrencyMode.single => [defaultFiat],
      HomeWidgetCurrencyMode.multiple => fiatOptions.take(spec.maxCurrencies).toList(),
    };
    _collapsedFiats = List.of(_fiats);
    _span = spec.sizes.isEmpty ? null : (spec.sizes.contains(initialSpan) ? initialSpan : spec.sizes.first);
    final savedPeriod = initial?.period;
    _period = savedPeriod != null && spec.periods.contains(savedPeriod) ? savedPeriod : spec.periods.first;
  }

  bool get allWallets => _allWallets;
  bool isWalletSelected(int walletId) => !_allWallets && _walletIds.contains(walletId);
  bool isFiatSelected(FiatCode fiat) => _fiats.contains(fiat);
  HomeWidgetPeriod get period => _period;
  HomeSpan? get span => _span;

  void selectSpan(HomeSpan span) {
    _span = span;
    notifyListeners();
  }

  bool get fakeBalanceActive => _fakeBalanceActive;
  int? get fakeBalance => _fakeBalance;
  bool get fakeBalanceExceedsSupply => (_fakeBalance ?? 0) > kMaxSupplySats;

  void selectAllWallets() {
    _allWallets = true;
    _walletIds.clear();
    notifyListeners();
  }

  void toggleWallet(int walletId) {
    if (_walletIds.contains(walletId)) {
      if (_walletIds.length == 1) return;
      _walletIds.remove(walletId);
    } else {
      _walletIds.add(walletId);
    }
    _allWallets = false;
    notifyListeners();
  }

  void toggleFiat(FiatCode fiat) {
    if (spec.currencies == HomeWidgetCurrencyMode.single) {
      _fiats = [fiat];
    } else if (_fiats.contains(fiat)) {
      if (_fiats.length == 1) return;
      _fiats = _fiats.where((selected) => selected != fiat).toList();
    } else {
      if (_fiats.length >= spec.maxCurrencies) return;
      _fiats = fiatOptions.where((option) => option == fiat || _fiats.contains(option)).toList();
    }
    notifyListeners();
  }

  bool get showsAllFiats => _showsAllFiats;

  /// 접힌 상태에서는 접을 때 골라져 있던 통화와 지금 고른 통화만 보여준다. 고른 걸 풀어도 바로 사라지지 않는다.
  List<FiatCode> get visibleFiatOptions =>
      _showsAllFiats
          ? fiatOptions
          : fiatOptions.where((fiat) => _collapsedFiats.contains(fiat) || _fiats.contains(fiat)).toList();

  bool get canToggleAllFiats => _showsAllFiats || visibleFiatOptions.length < fiatOptions.length;

  void toggleShowAllFiats() {
    _showsAllFiats = !_showsAllFiats;
    if (!_showsAllFiats) _collapsedFiats = List.of(_fiats);
    notifyListeners();
  }

  bool canSelectFiat(FiatCode fiat) =>
      spec.currencies != HomeWidgetCurrencyMode.multiple || _fiats.contains(fiat) || _fiats.length < spec.maxCurrencies;

  void selectPeriod(HomeWidgetPeriod period) {
    _period = period;
    notifyListeners();
  }

  void setFakeBalanceActive(bool active) {
    _fakeBalanceActive = active;
    notifyListeners();
  }

  void setFakeBalance(int? sats) {
    _fakeBalance = sats;
    notifyListeners();
  }

  int? targetOf(int walletId) => _targets[walletId];

  bool targetExceedsSupply(int walletId) => (_targets[walletId] ?? 0) > kMaxSupplySats;

  /// 0이나 빈 값은 목표 없음으로 본다.
  void setTarget(int walletId, int? sats) {
    _targets[walletId] = sats == null || sats <= 0 ? null : sats;
    notifyListeners();
  }

  bool get canSubmit {
    if (spec.fakeBalance && _fakeBalanceActive && (_fakeBalance == null || fakeBalanceExceedsSupply)) return false;
    if (spec.goals && wallets.any((wallet) => targetExceedsSupply(wallet.id))) return false;
    return true;
  }

  /// 같은 계정(핫월렛과 그 보기 전용 지갑)의 다른 지갑 가운데 [targets]에서 목표가 가장 큰 지갑과 그 목표.
  /// 목표가 다르면 큰 목표가 합계에 세어진다(결정 ⑦). 목표가 있는 다른 지갑이 없으면 null
  ({WalletItemBase wallet, int target})? _largestOtherGoal(int walletId, Map<int, int?> targets) {
    final wallet = wallets.firstWhere((wallet) => wallet.id == walletId);
    ({WalletItemBase wallet, int target})? largest;
    for (final other in wallets) {
      if (other.id == walletId || other.accountKey != wallet.accountKey) continue;
      final theirs = targets[other.id];
      if (theirs != null && (largest == null || theirs > largest.target)) largest = (wallet: other, target: theirs);
    }
    return largest;
  }

  /// 새 목표를 받지 않는 지갑이면 이미 목표가 있는 같은 계정 지갑의 이름, 아니면 null(결정 ⑦, 카드 4).
  /// 시트를 연 때 목표가 없었고 같은 계정의 다른 지갑에 목표가 있으면 막는다. 이름은 목표가 가장 커서 세어지는 지갑.
  /// 이미 목표가 있던 지갑(예전 데이터)은 지우고 다시 써도 막지 않는다(Fable N1). 이유: "'비상금' 지갑에 이미 목표가 있어요"
  String? goalOwnerName(int walletId) =>
      _savedTargets[walletId] == null ? _largestOtherGoal(walletId, _targets)?.wallet.name : null;

  bool goalBlocked(int walletId) => goalOwnerName(walletId) != null;

  /// 이 지갑의 목표가 합계에 들어가지 않는 지갑: 목표가 있는데 같은 계정에 더 큰 목표가 있다(예전 데이터, 큰 목표로 센다).
  /// 이유: "같은 계정에 더 큰 목표가 있어 이 목표는 합계에 넣지 않아요"(막힌 것과 다른 말, Astra)
  bool goalExcluded(int walletId) {
    final mine = _targets[walletId];
    final largest = _largestOtherGoal(walletId, _targets)?.target;
    return mine != null && largest != null && largest > mine;
  }

  /// 바뀐 지갑 목표를 한 번에 저장하고, 계정 규칙 때문에 저장하지 않은 지갑 id와 그 계정에서 목표가 세어지는 지갑 이름을
  /// 돌려준다(B1-b, 카드 4).
  /// - 저장소가 차례를 주면(다른 목표 저장과 겹치지 않게) 그때의 최신 저장값으로 정한다. 이번 시트에서 바꾼 지갑만 쓰고,
  ///   안 바꾼 지갑은 그 저장값을 그대로 둔다(시트를 연 사이 다른 곳에서 저장한 목표도 계정 규칙에 넣는다).
  /// - 목표가 없던 지갑의 새 목표는 같은 계정에 남는 목표가 없을 때만, 지갑 id 순서로 계정마다 하나 받는다.
  /// - 목표 맵은 한 번에 쓴다: 다 바뀌거나 하나도 안 바뀐다. 꺼짐 표시는 그 뒤에 쓰고, 실패하면 오류를 그대로 올린다.
  /// - 저장했든 못 했든 시트는 다시 읽은 저장값으로 다음 저장을 맞춘다.
  Future<Map<int, String>> commitTargets() async {
    if (!spec.goals) return const {};
    final skipped = <int, String>{};
    try {
      await _saveTargets((stored) {
        skipped.clear();
        final current = {for (final wallet in wallets) wallet.id: stored[wallet.id]};
        final edited = [
          for (final wallet in [...wallets]..sort((a, b) => a.id.compareTo(b.id)))
            if (_targets[wallet.id] != _savedTargets[wallet.id]) wallet,
        ];
        final wanted = {...current, for (final wallet in edited) wallet.id: _targets[wallet.id]};
        final claimed = {
          for (final wallet in wallets)
            if (wanted[wallet.id] != null && current[wallet.id] != null) wallet.accountKey,
        };
        for (final wallet in edited) {
          if (wanted[wallet.id] != null && current[wallet.id] == null && !claimed.add(wallet.accountKey)) {
            wanted[wallet.id] = null;
            // 이 계정은 목표가 남는 지갑이 이미 있다(claimed). 그 가운데 큰 목표가 세어진다
            skipped[wallet.id] = _largestOtherGoal(wallet.id, wanted)!.wallet.name;
          }
        }
        return {
          for (final wallet in edited)
            if (wanted[wallet.id] != current[wallet.id]) wallet.id: wanted[wallet.id],
        };
      });
    } finally {
      for (final wallet in wallets) {
        _savedTargets[wallet.id] = _targetOf(wallet.id);
      }
      notifyListeners();
    }
    return skipped;
  }

  HomeWidgetSettings get settings => HomeWidgetSettings(
    walletIds:
        spec.wallets && !_allWallets
            ? [
              for (final wallet in wallets)
                if (_walletIds.contains(wallet.id)) wallet.id,
            ]
            : null,
    fiats: spec.currencies == HomeWidgetCurrencyMode.none ? null : _fiats,
    period: spec.period ? _period : null,
    span: _span,
  );

  /// 가짜 잔액은 위젯마다 따로 두지 않고 기존 앱 설정 하나를 바꾼다.
  Future<void> commitFakeBalance() async {
    if (!spec.fakeBalance) return;
    if (!_fakeBalanceActive) {
      if (_wasFakeBalanceActive) await _preferenceProvider.toggleFakeBalanceActivation(false);
      return;
    }
    if (_wasFakeBalanceActive && _fakeBalance == _savedFakeBalance) return;
    final sats = _fakeBalance!;
    if (wallets.isEmpty) {
      await _preferenceProvider.setFakeBalanceTotalAmount(sats);
    } else {
      await _preferenceProvider.distributeFakeBalance(
        wallets,
        isFakeBalanceActive: true,
        fakeBalanceTotalSats: sats.toDouble(),
      );
    }
    await _preferenceProvider.toggleFakeBalanceActivation(true);
  }
}
