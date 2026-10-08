import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:flutter/foundation.dart';

/// All Features 한 줄
/// 검색으로 찾은 하위 기능이면 [path]에 상위부터 찾은 기능까지 이름이 들어 있다.
class AllFeaturesEntry {
  final FeatureItem item;
  final List<String> path;

  const AllFeaturesEntry(this.item, {this.path = const []});
}

/// All Features 화면
/// 검색어가 없으면 분류별 목록, 있으면 검색 결과를 준다.
class AllFeaturesViewModel extends ChangeNotifier {
  static const recentLimit = 4;

  final FeatureRegistry _registry;
  final bool Function(FeatureItem feature) _isAvailable;
  final void Function(List<String> ids)? _saveRecentIds;

  String _query = '';
  List<String> _recentIds;

  AllFeaturesViewModel({
    required FeatureRegistry registry,
    bool Function(FeatureItem feature)? isAvailable,
    List<String> recentIds = const [],
    void Function(List<String> ids)? saveRecentIds,
  }) : _registry = registry,
       _isAvailable = isAvailable ?? ((_) => true),
       _recentIds = recentIds,
       _saveRecentIds = saveRecentIds;

  /// 최근에 연 기능, 최근 것부터. 하위 기능을 열었으면 상위 기능으로 센다.
  List<FeatureItem> get recent =>
      [
        for (final id in _recentIds)
          if (_registry.byId(id) case final feature? when feature.isTopLevel && _isAvailable(feature)) feature,
      ].take(recentLimit).toList();

  void recordLaunch(FeatureItem feature) {
    final id = feature.parentId ?? feature.id;
    _recentIds = [id, ..._recentIds.where((other) => other != id)].take(recentLimit * 2).toList();
    _saveRecentIds?.call(_recentIds);
    notifyListeners();
  }

  String get query => _query;
  bool get isSearching => _query.trim().isNotEmpty;

  void search(String query) {
    if (_query == query) return;
    _query = query;
    notifyListeners();
  }

  List<FeatureItem> get _features {
    final features = _registry.topLevel.where(_isAvailable).toList();
    final original = {for (var i = 0; i < features.length; i++) features[i].id: i};
    int rank(FeatureItem item) {
      final index = allFeaturesOrder.indexOf(item.id);
      return index < 0 ? allFeaturesOrder.length + original[item.id]! : index;
    }

    return features..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  /// 분류 순서대로, 기능이 있는 분류만
  /// 분류가 없는 기능(오픈스토어)은 맨 뒤 null 분류(추가 기능)로 묶는다.
  List<(FeatureCategory?, List<AllFeaturesEntry>)> get sections {
    final features = _features;
    return [
      for (final category in [...FeatureCategory.values, null])
        if (features.where((item) => item.category == category).toList() case final items when items.isNotEmpty)
          (category, [for (final item in items) AllFeaturesEntry(item)]),
    ];
  }

  List<AllFeaturesEntry> get results => [
    for (final result in _registry.search(_query))
      if (_isAvailable(result.item))
        AllFeaturesEntry(result.item, path: result.matchedPath.length > 1 ? result.matchedPath : const []),
  ];
}
