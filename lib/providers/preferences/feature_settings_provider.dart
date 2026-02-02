import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/model/preference/home_feature.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_home_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:tuple/tuple.dart';

class FeatureSettingsProvider extends ChangeNotifier {
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();
  List<HomeFeature> _features = [];

  // 분석 위젯 관련 설정
  late int _analysisPeriod;
  late Tuple2<DateTime?, DateTime?> _analysisPeriodRange;
  late AnalysisTransactionType _selectedAnalysisTransactionType;

  FeatureSettingsProvider() {
    // 생성 시 동기적으로 초기화
    _loadFeaturesSync();
    _loadAnalysisSettingsSync();
  }

  List<HomeFeature> get features => _features;

  // 분석 위젯 설정 getters
  int get analysisPeriod => _analysisPeriod;
  Tuple2<DateTime?, DateTime?> get analysisPeriodRange => _analysisPeriodRange;
  AnalysisTransactionType get selectedAnalysisTransactionType => _selectedAnalysisTransactionType;

  void _loadFeaturesSync() {
    final encoded = _sharedPrefs.getString(SharedPrefKeys.kHomeFeatures);
    if (encoded.isEmpty) {
      _features = [];
      return;
    }
    try {
      final List<dynamic> decoded = jsonDecode(encoded);
      _features = decoded.map((e) => HomeFeature.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      // JSON 파싱 실패 시 빈 리스트로 초기화
      _features = [];
    }
  }

  /// 특정 기능이 활성화되어 있는지 확인
  bool isEnabled(HomeFeatureType type) {
    return _features
        .firstWhere(
          (f) => f.homeFeatureTypeString == type.name,
          orElse: () => HomeFeature(homeFeatureTypeString: type.name, isEnabled: false),
        )
        .isEnabled;
  }

  /// 저장소에서 Feature 리스트 로드
  Future<void> loadFeatures() async {
    final encoded = _sharedPrefs.getString(SharedPrefKeys.kHomeFeatures);
    if (encoded.isEmpty) {
      _features = [];
      return;
    }
    final List<dynamic> decoded = jsonDecode(encoded);
    _features = decoded.map((e) => HomeFeature.fromJson(e as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  /// Feature 리스트 저장
  Future<void> setFeatures(List<HomeFeature> features) async {
    _features = List.from(features);
    await _sharedPrefs.setString(SharedPrefKeys.kHomeFeatures, jsonEncode(features.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  /// 저장된 값과 기본값을 비교하여 동기화
  /// 새로운 기능이 추가되거나 제거된 기능이 있을 때 호출
  Future<void> synchronizeWithDefaults({List<WalletListItemBase>? walletList}) async {
    final initialFeatures = [
      HomeFeature(homeFeatureTypeString: HomeFeatureType.recentTransaction.name, isEnabled: true),
      HomeFeature(homeFeatureTypeString: HomeFeatureType.analysis.name, isEnabled: true),
    ];

    if (_features.isEmpty) {
      _features.addAll(List.from(initialFeatures));
      await _saveFeatures();
      notifyListeners();
      return;
    }

    // 저장된 값과 기본값이 동일한지 확인
    final isSame = const DeepCollectionEquality.unordered().equals(
      _features.map((e) => e.homeFeatureTypeString).toList(),
      initialFeatures.map((e) => e.homeFeatureTypeString).toList(),
    );

    if (isSame) return;

    // 기능은 추후 추가/제거 등 달라질 여지가 있기 때문에 내용을 비교해서 추가/제거 합니다.
    final updatedFeatures = <HomeFeature>[];
    for (final defaultFeature in initialFeatures) {
      final existing = _features.firstWhereOrNull(
        (e) => e.homeFeatureTypeString == defaultFeature.homeFeatureTypeString,
      );
      // 기존 설정이 있으면 그대로 유지, 없으면 기본값 사용
      updatedFeatures.add(existing ?? defaultFeature);
    }

    // 기본값에 없는 기능은 제거
    _features.removeWhere((e) => !initialFeatures.any((k) => k.homeFeatureTypeString == e.homeFeatureTypeString));

    // 업데이트된 기능 추가
    _features.addAll(
      updatedFeatures.where((e) => !_features.any((h) => h.homeFeatureTypeString == e.homeFeatureTypeString)),
    );

    await _saveFeatures();
    notifyListeners();
  }

  /// 내부 저장 메서드
  Future<void> _saveFeatures() async {
    await _sharedPrefs.setString(SharedPrefKeys.kHomeFeatures, jsonEncode(_features.map((e) => e.toJson()).toList()));
  }

  /// 분석 설정 로드 (생성자에서 사용)
  void _loadAnalysisSettingsSync() {
    _analysisPeriod = _getAnalysisPeriodSync();
    _analysisPeriodRange = _getAnalysisPeriodRangeSync();
    _selectedAnalysisTransactionType = _getAnalysisTransactionTypeSync();
  }

  /// 분석 기간 로드
  int _getAnalysisPeriodSync() {
    final period = _sharedPrefs.getIntOrNull(SharedPrefKeys.kAnalysisPeriod);
    return period ?? 30; // 기본 기간 30일
  }

  /// 분석 기간 범위 로드
  Tuple2<DateTime?, DateTime?> _getAnalysisPeriodRangeSync() {
    final start = _sharedPrefs.getString(SharedPrefKeys.kAnalysisPeriodStart);
    final end = _sharedPrefs.getString(SharedPrefKeys.kAnalysisPeriodEnd);
    return Tuple2(start.isEmpty ? null : DateTime.parse(start), end.isEmpty ? null : DateTime.parse(end));
  }

  /// 분석 거래 유형 로드
  AnalysisTransactionType _getAnalysisTransactionTypeSync() {
    final encoded = _sharedPrefs.getString(SharedPrefKeys.kSelectedTransactionTypeIndices);
    if (encoded.isEmpty) return AnalysisTransactionType.all; // [전체 = all]이 기본
    return AnalysisTransactionType.values.firstWhere(
      (type) => type.name == encoded,
      orElse: () => AnalysisTransactionType.all,
    );
  }

  /// 분석 기간 설정
  int getAnalysisPeriod() {
    return _getAnalysisPeriodSync();
  }

  Future<void> setAnalysisPeriod(int days) async {
    _analysisPeriod = days;
    await _sharedPrefs.setInt(SharedPrefKeys.kAnalysisPeriod, days);
    notifyListeners();
  }

  /// 분석 기간 범위 설정
  Tuple2<DateTime?, DateTime?> getAnalysisPeriodRange() {
    return _getAnalysisPeriodRangeSync();
  }

  Future<void> setAnalysisPeriodRange(DateTime start, DateTime end) async {
    _analysisPeriodRange = Tuple2(start, end);
    await _sharedPrefs.setString(SharedPrefKeys.kAnalysisPeriodStart, start.toIso8601String());
    await _sharedPrefs.setString(SharedPrefKeys.kAnalysisPeriodEnd, end.toIso8601String());
    notifyListeners();
  }

  /// 분석 거래 유형 설정
  AnalysisTransactionType getAnalysisTransactionType() {
    return _getAnalysisTransactionTypeSync();
  }

  Future<void> setAnalysisTransactionType(AnalysisTransactionType transactionType) async {
    _selectedAnalysisTransactionType = transactionType;
    await _sharedPrefs.setString(SharedPrefKeys.kSelectedTransactionTypeIndices, transactionType.name);
    notifyListeners();
  }
}
