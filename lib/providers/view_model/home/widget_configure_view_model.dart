import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:flutter/foundation.dart';

/// 위젯 설정 시트. [initial]이 null이면 새로 추가하는 위젯이다.
class WidgetConfigureViewModel extends ChangeNotifier {
  static const maxFakeBalanceBtc = 21000000;

  final HomeWidgetSettingsSpec spec;
  final List<WalletItemBase> wallets;
  final PreferenceProvider _preferenceProvider;
  final bool isNew;

  late final FiatCode defaultFiat = _preferenceProvider.selectedFiat;
  late final List<FiatCode> fiatOptions = fiatsWithDefaultFirst(defaultFiat);

  final Set<int> _walletIds = {};
  bool _allWallets = true;
  List<FiatCode> _fiats = [];
  HomeWidgetPeriod _period = HomeWidgetPeriod.week;
  HomeSpan? _span;

  late final bool _wasFakeBalanceActive = _preferenceProvider.isFakeBalanceActive;
  late final int? _savedFakeBalance = _preferenceProvider.fakeBalanceTotalAmount;
  late bool _fakeBalanceActive = _wasFakeBalanceActive;
  late int? _fakeBalance = _savedFakeBalance;

  final int? Function(int walletId) _targetOf;
  final Future<void> Function(int walletId, int? targetSats) _saveTarget;
  late final Map<int, int?> _savedTargets = {for (final wallet in wallets) wallet.id: _targetOf(wallet.id)};
  late final Map<int, int?> _targets = Map.of(_savedTargets);

  WidgetConfigureViewModel({
    required this.spec,
    required this.wallets,
    required PreferenceProvider preferenceProvider,
    HomeWidgetSettings? initial,
    HomeSpan? initialSpan,
    int? Function(int walletId)? targetOf,
    Future<void> Function(int walletId, int? targetSats)? saveTarget,
  }) : _preferenceProvider = preferenceProvider,
       _targetOf = targetOf ?? ((_) => null),
       _saveTarget = saveTarget ?? ((_, __) async {}),
       isNew = initial == null {
    final ids = initial?.walletIds?.where((id) => wallets.any((wallet) => wallet.id == id)).toList() ?? const [];
    if (ids.isNotEmpty) {
      _allWallets = false;
      _walletIds.addAll(ids);
    }
    _fiats = switch (spec.currencies) {
      HomeWidgetCurrencyMode.none => const [],
      _ when initial?.fiats != null => initial!.fiats!.take(spec.maxCurrencies).toList(),
      HomeWidgetCurrencyMode.single => [defaultFiat],
      HomeWidgetCurrencyMode.multiple => fiatOptions.take(spec.maxCurrencies).toList(),
    };
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
  bool get fakeBalanceExceedsSupply => (_fakeBalance ?? 0) > maxFakeBalanceBtc * 100000000;

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

  bool targetExceedsSupply(int walletId) => (_targets[walletId] ?? 0) > maxFakeBalanceBtc * 100000000;

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

  /// 바뀐 지갑 목표만 저장한다.
  Future<void> commitTargets() async {
    if (!spec.goals) return;
    for (final wallet in wallets) {
      if (_targets[wallet.id] != _savedTargets[wallet.id]) await _saveTarget(wallet.id, _targets[wallet.id]);
    }
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
