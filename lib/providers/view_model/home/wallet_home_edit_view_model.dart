import 'dart:math';

import 'package:coconut_wallet/model/preference/home_feature.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_home_edit_screen.dart';
import 'package:flutter/material.dart';

class WalletHomeEditViewModel extends ChangeNotifier {
  WalletProvider _walletProvider;
  late final PreferenceProvider _preferenceProvider;
  late bool _isBalanceHidden;
  late bool _isFiatBalanceHidden;
  late bool _isFakeBalanceActive;

  late int minimumSatoshi;
  final int maximumAmount = 21000000;
  final int maxInputLength = 19; // 21,000,000.00000000

  Map<int, dynamic> _fakeBalanceMap = {};
  int? _fakeBalanceTotalAmount;
  FakeBalanceInputError _inputError = FakeBalanceInputError.none;

  // temp datas
  late List<HomeFeature> _tempHomeFeatures;
  late bool _tempIsBalanceHidden;
  late bool _tempIsFiatBalanceHidden;
  late bool _tempIsFakeBalanceActive;
  late int? _tempFakeBalanceTotalAmount;

  WalletHomeEditViewModel(this._walletProvider, this._preferenceProvider) {
    // _walletBalance = _walletProvider
    //     .fetchWalletBalanceMap()
    //     .map((key, balance) => MapEntry(key, AnimatedBalanceData(balance.total, balance.total)));
    minimumSatoshi = _walletProvider.walletItemList.length;
    _isBalanceHidden = _preferenceProvider.isBalanceHidden;
    _isFiatBalanceHidden = _preferenceProvider.isFiatBalanceHidden;
    _isFakeBalanceActive = _preferenceProvider.isFakeBalanceActive;
    _fakeBalanceTotalAmount = _preferenceProvider.fakeBalanceTotalAmount;
    _fakeBalanceMap = _preferenceProvider.getFakeBalanceMap();

    _tempHomeFeatures =
        _preferenceProvider.homeFeatures
            .map(
              (feature) =>
                  HomeFeature(homeFeatureTypeString: feature.homeFeatureTypeString, isEnabled: feature.isEnabled),
            )
            .toList();
    _tempIsBalanceHidden = isBalanceHidden;
    _tempIsFiatBalanceHidden = isFiatBalanceHidden;
    _tempIsFakeBalanceActive = isFakeBalanceActive;
    _tempFakeBalanceTotalAmount = fakeBalanceTotalAmount;
  }

  bool get isBalanceHidden => _isBalanceHidden;
  bool get isFiatBalanceHidden => _isFiatBalanceHidden;
  bool get isFakeBalanceActive => _isFakeBalanceActive;
  int? get fakeBalanceTotalAmount => _fakeBalanceTotalAmount;
  Map<int, dynamic> get fakeBalanceMap => _fakeBalanceMap;
  int get walletItemLength => _walletProvider.walletItemList.length;
  List<HomeFeature> get homeFeatures => _preferenceProvider.homeFeatures;
  FakeBalanceInputError get inputError => _inputError;

  List<HomeFeature> get tempHomeFeatures => _tempHomeFeatures;
  bool get tempIsBalanceHidden => _tempIsBalanceHidden;
  bool get tempIsFiatBalanceHidden => _tempIsFiatBalanceHidden;
  bool get tempIsFakeBalanceActive => _tempIsFakeBalanceActive;
  int? get tempFakeBalanceTotalAmount => _tempFakeBalanceTotalAmount;

  void onWalletProviderUpdated(WalletProvider walletProvider) {
    _walletProvider = walletProvider;
    notifyListeners();
  }

  void onPreferenceProviderUpdated() {
    /// 잔액 숨기기 변동 체크
    if (_isBalanceHidden != _preferenceProvider.isBalanceHidden) {
      setIsBalanceHidden(_preferenceProvider.isBalanceHidden);
    }

    /// 가짜 잔액 총량 변동 체크 (on/off 판별)
    if (_fakeBalanceTotalAmount != _preferenceProvider.fakeBalanceTotalAmount) {
      _setFakeBalanceTotalAmount(_preferenceProvider.fakeBalanceTotalAmount);
      _setFakeBlanceMap(_preferenceProvider.getFakeBalanceMap());
    }

    /// 잔액 숨기기 변동 체크
    if (_isFiatBalanceHidden != _preferenceProvider.isFiatBalanceHidden) {
      setIsFiatBalanceHidden(_preferenceProvider.isFiatBalanceHidden);
    }
    notifyListeners();
  }

  void setIsBalanceHidden(bool value) {
    _preferenceProvider.changeIsBalanceHidden(value);
    _isBalanceHidden = value;
    if (!value) clearFakeBlanceTotalAmount();
    notifyListeners();
  }

  void setTempIsBalanceHidden(bool value) {
    _tempIsBalanceHidden = value;
    if (!value) {
      _tempFakeBalanceTotalAmount = null;
      // _tempIsFakeBalanceActive = false;
    }
    notifyListeners();
  }

  void setIsFiatBalanceHidden(bool value) {
    _preferenceProvider.changeIsFiatBalanceHidden(value);
    _isFiatBalanceHidden = value;
    notifyListeners();
  }

  void setTempIsFiatBalanceHidden(bool value) {
    _tempIsFiatBalanceHidden = value;
    notifyListeners();
  }

  void clearFakeBlanceTotalAmount() {
    _preferenceProvider.clearFakeBalanceTotalAmount();
    _preferenceProvider.toggleFakeBalanceActivation(false);
    _isFakeBalanceActive = false;
    notifyListeners();
  }

  void setIsFakeBalanceActive(bool value) {
    _preferenceProvider.toggleFakeBalanceActivation(value);
    _isFakeBalanceActive = value;
    notifyListeners();
  }

  void setTempFakeBalanceActive(bool value) {
    _tempIsFakeBalanceActive = value;
    notifyListeners();
  }

  void _setFakeBalanceTotalAmount(int? value) {
    _fakeBalanceTotalAmount = value;
    notifyListeners();
  }

  void setTempFakeBalanceTotalAmount(int? value) {
    _tempFakeBalanceTotalAmount = value;
    notifyListeners();
  }

  void _setFakeBlanceMap(Map<int, dynamic> value) {
    _fakeBalanceMap = value;
    notifyListeners();
  }

  void setInputError(FakeBalanceInputError error) {
    _inputError = error;
    notifyListeners();
  }

  void toggleTempHomeFeatureEnabled(String homeFeatureTypeString) {
    final index = _tempHomeFeatures.indexWhere((element) => element.homeFeatureTypeString == homeFeatureTypeString);
    if (index != -1) {
      final feature = _tempHomeFeatures[index];
      _tempHomeFeatures[index] = HomeFeature(
        homeFeatureTypeString: feature.homeFeatureTypeString,
        isEnabled: !feature.isEnabled,
      );
      notifyListeners();
    }
  }

  int? getFakeTotalBalance() {
    return _fakeBalanceTotalAmount;
  }

  Future<void> onComplete() async {
    setIsBalanceHidden(_tempIsBalanceHidden);
    setIsFiatBalanceHidden(_tempIsFiatBalanceHidden);
    _setHomeFeatureEnabled();
    await _setFakeBalance();
  }

  Future<void> _setHomeFeatureEnabled() async {
    await _preferenceProvider.setHomeFeautres(_tempHomeFeatures);
  }

  Future<void> _setFakeBalance() async {
    final wallets = _walletProvider.walletItemList;
    if (!_tempIsFakeBalanceActive) {
      await _preferenceProvider.toggleFakeBalanceActivation(false);

      return;
    }

    if (_tempFakeBalanceTotalAmount == null || wallets.isEmpty) return;

    if (_tempFakeBalanceTotalAmount == 0) {
      await _preferenceProvider.setFakeBalanceTotalAmount(0);

      final Map<int, dynamic> fakeBalanceMap = {};
      for (int i = 0; i < wallets.length; i++) {
        final walletId = wallets[i].id;

        fakeBalanceMap[walletId] = 0;
        debugPrint('[Wallet $i]Fake Balance: ${fakeBalanceMap[i]} BTC');
      }
      await _preferenceProvider.setFakeBalanceMap(fakeBalanceMap);
      await _preferenceProvider.toggleFakeBalanceActivation(_tempIsFakeBalanceActive);
      return;
    }

    final walletCount = wallets.length;
    final int fakeSats = _tempFakeBalanceTotalAmount!;

    if (fakeSats < walletCount) return; // 최소 1사토시씩 못 주면 리턴

    final random = Random();
    // 1. 각 지갑에 최소 1사토시 할당
    // 2. 남은 사토시를 랜덤 가중치로 분배
    final List<int> weights = List.generate(walletCount, (_) => random.nextInt(100) + 1); // 1~100
    final int weightSum = weights.reduce((a, b) => a + b);
    final int remainingSats = (fakeSats - walletCount);
    final List<int> splits = [];

    for (int i = 0; i < walletCount; i++) {
      final int share = (remainingSats * weights[i] / weightSum).floor();
      splits.add(1 + share); // 최소 1 사토시 보장
    }

    // 보정: 분할의 총합이 totalSats보다 작을 수 있으므로 마지막 지갑에 부족분 추가
    final int diff = fakeSats - splits.reduce((a, b) => a + b);
    splits[splits.length - 1] += diff;

    final Map<int, dynamic> fakeBalanceMap = {};

    if (_preferenceProvider.isFakeBalanceActive != _tempIsFakeBalanceActive) {
      await _preferenceProvider.toggleFakeBalanceActivation(_tempIsFakeBalanceActive);
    }

    await _preferenceProvider.setFakeBalanceTotalAmount(fakeSats);

    for (int i = 0; i < splits.length; i++) {
      final walletId = wallets[i].id;
      final fakeBalance = splits[i];
      fakeBalanceMap[walletId] = fakeBalance;
      debugPrint('[Wallet $i]Fake Balance:::::: ${splits[i]} Sats');
    }

    await _preferenceProvider.setFakeBalanceMap(fakeBalanceMap);
  }
}
