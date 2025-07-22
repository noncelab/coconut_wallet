// 내용 변경시 RealmHomeFeature도 수정 필요
class HomeFeature {
  final String homeFeatureTypeString;
  final String assetPath;
  final bool isEnabled;
  const HomeFeature({
    required this.homeFeatureTypeString,
    required this.assetPath,
    required this.isEnabled,
  });
}

// RealmHomeFeature 수정 불필요
enum HomeFeatureType {
  totalBalance,
  walletList,
  recentTransaction,
  analysis,
}
