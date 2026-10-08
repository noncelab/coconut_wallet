import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/services/feature/builtin_features.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';

export 'package:coconut_wallet/services/feature/builtin_features.dart' show FeatureIds, allFeaturesOrder;

class FeatureSearchResult {
  final FeatureItem item;
  final List<String> matchedPath;
  final int score;

  const FeatureSearchResult({required this.item, required this.matchedPath, required this.score});
}

class FeatureRegistry {
  final List<FeatureItem> all;
  final Map<String, FeatureItem> _byId;

  FeatureRegistry(List<FeatureItem> items) : all = List.unmodifiable(items), _byId = {for (final i in items) i.id: i};

  factory FeatureRegistry.builtin() => FeatureRegistry([...builtinFeatures(), ..._ccosFeatures()]);

  static List<FeatureItem> _ccosFeatures() {
    return [
      for (final listing in CcosFeatureRegistrySource.allListings)
        FeatureItem(
          id: '${FeatureIds.appSettings}.ccos.${listing.id}',
          label: () => listing.title,
          keywords: listing.tags,
          parentId: FeatureIds.appSettings,
          source: FeatureSource.ccos,
        ),
    ];
  }

  List<FeatureItem> get topLevel => all.where((item) => item.isTopLevel).toList();

  List<FeatureItem> get shortcutEligible => all.where((item) => item.isTopLevel && item.shortcutEligible).toList();

  FeatureItem? byId(String id) => _byId[id];

  List<FeatureItem> childrenOf(String id) => all.where((item) => item.parentId == id).toList();

  List<FeatureSearchResult> search(String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return const [];

    final results = <FeatureSearchResult>[];
    for (final item in topLevel) {
      final best = _bestMatch(item, normalizedQuery);
      if (best != null) results.add(best);
    }
    final order = {for (var i = 0; i < all.length; i++) all[i].id: i};
    results.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : order[a.item.id]!.compareTo(order[b.item.id]!);
    });
    return results;
  }

  FeatureSearchResult? _bestMatch(FeatureItem topLevelItem, String query) {
    FeatureSearchResult? best;
    void visit(FeatureItem item, List<String> path) {
      final currentPath = [...path, item.label()];
      final score = _itemScore(item, query);
      if (score > 0 && (best == null || score > best!.score)) {
        best = FeatureSearchResult(item: topLevelItem, matchedPath: currentPath, score: score);
      }
      for (final child in childrenOf(item.id)) {
        visit(child, currentPath);
      }
    }

    visit(topLevelItem, const []);
    return best;
  }

  static int _itemScore(FeatureItem item, String query) {
    var best = _textScore(item.label(), query);
    for (final keyword in item.keywords) {
      final score = _textScore(keyword, query);
      if (score > best) best = score;
    }
    return best;
  }

  static int _textScore(String text, String query) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) return 0;
    if (normalized == query) return 3;
    if (normalized.startsWith(query)) return 2;
    if (normalized.contains(query)) return 1;
    return 0;
  }

  static String _normalize(String text) => text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}
